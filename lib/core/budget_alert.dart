/// Mesin peringatan batas pengeluaran — murni Dart, tanpa drift/Flutter
/// (ADR-003). Dipakai BudgetAlertService; keputusan kirim/tahan ada
/// di sini, native hanya menampilkan (ADR-012).
///
/// Konvensi periode mengikuti core/budget.dart: minggu mulai Senin,
/// waktu lokal device.
library;

import 'budget.dart';
import 'money.dart';

/// Key periode dedup: ganti periode berarti state lama tidak lagi
/// cocok → garis yang masih di atas ambang menembak lagi sekali.
String budgetAlertPeriodKey(LimitScope scope, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  // Minggu dihitung dari Senin (konsisten ProgressService.refresh);
  // tanggal Senin betul walau jatuh di bulan/tahun sebelumnya.
  final monday = today.subtract(Duration(days: today.weekday - 1));
  String stamp(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  return switch (scope) {
    LimitScope.daily => 'd${stamp(today)}',
    LimitScope.weekly => 'w${stamp(monday)}',
    LimitScope.monthly => 'm${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}',
  };
}

/// Satu garis batas yang baru menyentuh ambang saat evaluasi ini.
class BudgetAlertHit {
  const BudgetAlertHit({
    required this.scope,
    required this.used,
    required this.limit,
    required this.percent,
    required this.over,
    this.note,
  });

  final LimitScope scope;
  final int used;
  final int limit;

  /// Persen terpakai (floor, konsisten LimitLine.usedPercent).
  final int percent;

  /// True bila sudah melewati batas (bukan sekadar menyentuh ambang).
  final bool over;

  /// Catatan cakupan kategori — contoh 'Makanan, Transportasi'.
  /// null = semua kategori dihitung.
  final String? note;

  int get remaining => (limit - used).clamp(0, limit);
}

/// Hasil evaluasi: garis yang perlu dinotifikasi + state baru untuk
/// disimpan (hanya berubah bila ada yang menembak).
class BudgetAlertPlan {
  const BudgetAlertPlan({required this.hits, required this.newState});

  /// Terurut daily → weekly → monthly; maksimal satu hit per scope.
  final List<BudgetAlertHit> hits;

  /// Map lengkap untuk disimpan (state lama + pembaruan menembak).
  final Map<String, String> newState;
}

/// Key state untuk satu scope+jenis menembak di app_settings.
String _stateKey(LimitScope scope, {required bool over}) =>
    '${scope.name}#${over ? 'over' : 'warn'}';

/// Putuskan garis mana yang layak menembak sekarang.
///
/// [lines]: pemakaian per scope; null nilai atau limit ≤ 0 berarti
/// tanpa batas untuk scope itu — selalu dilewati. [state]: periodKey
/// yang sudah pernah dinotifikasi per key ([_stateKey]); menembak
/// bila periodKey berbeda (belum kirim periode ini). Over mengalahkan
/// warn dalam satu evaluasi agar satu scope maksimal satu hit.
BudgetAlertPlan planBudgetAlerts({
  required Map<LimitScope, ({int used, int? limit, String? note})?> lines,
  required int thresholdPercent,
  required Map<String, String> state,
  required DateTime now,
}) {
  final hits = <BudgetAlertHit>[];
  final next = Map<String, String>.of(state);

  for (final scope in LimitScope.values) {
    final line = lines[scope];
    if (line == null) continue;
    final limit = line.limit;
    if (limit == null || limit <= 0) continue;
    final used = line.used;
    final period = budgetAlertPeriodKey(scope, now);
    final over = used >= limit;
    final shouldFire = over || (used * 100 ~/ limit) >= thresholdPercent;
    final key = _stateKey(scope, over: over);
    if (!shouldFire || next[key] == period) continue;
    hits.add(BudgetAlertHit(
      scope: scope,
      used: used,
      limit: limit,
      percent: used * 100 ~/ limit,
      over: over,
      note: line.note,
    ));
    next[key] = period;
  }

  return BudgetAlertPlan(hits: hits, newState: next);
}

/// Teks notifikasi gabungan; null bila tidak ada hit. Satu event satu
/// notifikasi — daftar garis digabung berbaris agar tidak berisik.
({String title, String body})? budgetAlertMessage(
  List<BudgetAlertHit> hits, {
  required int thresholdPercent,
}) {
  if (hits.isEmpty) return null;
  final first = hits.first;
  final label = first.scope.shortLabel;
  final String title;
  if (hits.length > 1) {
    title = first.over
        ? 'Batas pengeluaran terlampaui'
        : 'Batas pengeluaran menyentuh $thresholdPercent%';
  } else if (first.over) {
    title = 'Batas $label terlampaui';
  } else {
    title = 'Batas $label: $thresholdPercent% terpakai';
  }
  final body = [
    for (final h in hits)
      '${h.scope.shortLabel}: ${Money.formatAbs(h.used)} dari '
          '${Money.formatAbs(h.limit)} — sisa ${Money.formatAbs(h.remaining)}'
          '${h.over ? ' (lewat)' : ''}'
          '${h.note != null ? ' · ${h.note}' : ''}',
  ].join('\n');
  return (title: title, body: body);
}
