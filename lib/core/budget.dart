/// Mesin anggaran murni — tanpa dependensi drift/Flutter, sehingga
/// unit-testable dan dipakai ProgressService maupun UI Anggaran.
///
/// Konvensi periode: [start, end) eksklusif di ujung atas.
library;

import 'dart:convert';

/// Batas alokasi harian / mingguan / total bulanan, dalam rupiah.
const String kKeyDailyLimit = 'budget_daily_limit';
const String kKeyWeeklyLimit = 'budget_weekly_limit';
const String kKeyMonthlyTotal = 'budget_monthly_total';

/// Key filter kategori per scope batas (lihat [LimitScope.categoriesKey]).
/// Nilai: JSON array id kategori; kosong = semua kategori dihitung.
const String kKeyDailyCategories = 'budget_daily_categories';
const String kKeyWeeklyCategories = 'budget_weekly_categories';
const String kKeyMonthlyCategories = 'budget_monthly_categories';

/// Sentinel id kategori untuk "tanpa kategori" (category_id NULL di DB).
/// Id kategori asli selalu > 0, jadi -1 tidak mungkin bentrok.
const int kUncategorizedId = -1;

/// Satu scope batas global: harian, mingguan, atau total bulanan.
///
/// Batas dan filter kategori disimpan terpisah: batas (rupiah) di satu
/// key app_settings, filter kategori di key lain. Keduanya independen —
/// batas bisa ada tanpa filter, atau filter ada tanpa batas.
enum LimitScope { daily, weekly, monthly }

extension LimitScopeInfo on LimitScope {
  /// Key app_settings untuk nilai batas (rupiah).
  String get limitKey => switch (this) {
        LimitScope.daily => kKeyDailyLimit,
        LimitScope.weekly => kKeyWeeklyLimit,
        LimitScope.monthly => kKeyMonthlyTotal,
      };

  /// Key app_settings untuk filter kategori (JSON array id).
  String get categoriesKey => switch (this) {
        LimitScope.daily => kKeyDailyCategories,
        LimitScope.weekly => kKeyWeeklyCategories,
        LimitScope.monthly => kKeyMonthlyCategories,
      };

  /// Label garis batas di [BudgetSnapshot] — dipakai maskot, alert, dan
  /// notifikasi lewat konstanta ini, bukan string terpisah.
  String get label => switch (this) {
        LimitScope.daily => 'Batas harian',
        LimitScope.weekly => 'Batas mingguan',
        LimitScope.monthly => 'Total bulan ini',
      };

  /// Label pendek untuk pesan notifikasi.
  String get shortLabel => switch (this) {
        LimitScope.daily => 'Harian',
        LimitScope.weekly => 'Mingguan',
        LimitScope.monthly => 'Bulanan',
      };

  /// Judul dialog pengaturan batas.
  String get settingTitle => switch (this) {
        LimitScope.daily => 'Atur Batas Harian',
        LimitScope.weekly => 'Atur Batas Mingguan',
        LimitScope.monthly => 'Atur Batas Total Bulanan',
      };
}

/// Baca daftar id kategori tersimpan untuk satu scope batas.
/// null = semua kategori (filter belum diset atau isinya tak terbaca).
Set<int>? parseLimitCategories(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (decoded is! List) return null;
  final ids = decoded.whereType<num>().map((n) => n.toInt()).toSet();
  // Array kosong = tidak ada pilihan = kembali ke default semua kategori.
  return ids.isEmpty ? null : ids;
}

/// Simpan daftar id kategori sebagai JSON array (urut ascending).
String encodeLimitCategories(Set<int> ids) {
  final sorted = ids.toList()..sort();
  return jsonEncode(sorted);
}

/// Buang id kategori yang sudah tidak ada (kategori dihapus) dari filter
/// scope. Hasil kosong → null (semua kategori): batas yang tidak menghitung
/// apa pun lebih membingungkan daripada kembali ke default.
Set<int>? pruneLimitCategories(Set<int>? ids, Set<int> existingCategoryIds) {
  if (ids == null) return null;
  final kept = ids
      .where((id) => id == kUncategorizedId || existingCategoryIds.contains(id))
      .toSet();
  return kept.isEmpty ? null : kept;
}

/// Ringkasan filter scope untuk badge: 'Semua kategori' atau '2 kategori'.
String limitScopeSummary(Set<int>? ids) {
  if (ids == null) return 'Semua kategori';
  final n = ids.length;
  return n == 1 ? '1 kategori' : '$n kategori';
}

/// Catatan cakupan batas: nama kategori yang ikut dihitung, urut sesuai
/// [categoryNames]. null saat semua kategori dihitung (tidak ada filter).
String? limitScopeNote(Set<int>? ids, Map<int, String> categoryNames) {
  if (ids == null) return null;
  final parts = <String>[
    for (final entry in categoryNames.entries)
      if (ids.contains(entry.key)) entry.value,
    if (ids.contains(kUncategorizedId)) 'Tanpa kategori',
  ];
  return parts.isEmpty ? null : parts.join(', ');
}

/// Posisi satu garis batas terhadap pemakaian.
enum BudgetLevel { ok, warning, over }

/// Arah perubahan dibanding periode pembanding.
enum TrendDirection { better, worse, flat }

/// Satu baris batas: label + terpakai + plafon (null = tanpa batas).
class LimitLine {
  const LimitLine({
    required this.label,
    required this.used,
    this.limit,
    this.isCategory = false,
    this.scopeNote,
  });

  final String label;
  final int used;
  final int? limit;

  /// True untuk garis alokasi kategori (bukan batas global).
  final bool isCategory;

  /// Catatan cakupan kategori batas ini — contoh 'Makanan, Transportasi'.
  /// null = semua kategori dihitung.
  final String? scopeNote;

  /// warning mulai 75% terpakai; over saat menyentuh plafon.
  BudgetLevel get level {
    final limit = this.limit;
    if (limit == null || limit <= 0) return BudgetLevel.ok;
    if (used >= limit) return BudgetLevel.over;
    if (used >= limit * 0.75) return BudgetLevel.warning;
    return BudgetLevel.ok;
  }

  /// 0..1 (dipotong ke 1) untuk progress bar; tanpa batas = 0.
  double get fraction {
    final limit = this.limit;
    if (limit == null || limit <= 0) return 0;
    return (used / limit).clamp(0, 1);
  }

  /// Persen terpakai, dibulatkan; tanpa batas = 0.
  int get usedPercent {
    final limit = this.limit;
    if (limit == null || limit <= 0) return 0;
    return (used * 100 ~/ limit);
  }
}

/// Ringkasan kondisi anggaran satu momen + arah tren bulanan.
class BudgetSnapshot {
  const BudgetSnapshot({
    required this.lines,
    required this.monthIn,
    required this.monthOut,
    required this.lastMonthIn,
    required this.lastMonthOut,
    required this.hasData,
  });

  /// Batas harian, mingguan, total bulanan, lalu tiap alokasi kategori.
  final List<LimitLine> lines;

  final int monthIn;
  final int monthOut;

  /// Pembanding: bulan lalu pada rentang hari yang sama (fair mid-month).
  final int lastMonthIn;
  final int lastMonthOut;

  /// Ada minimal satu transaksi bulan berjalan.
  final bool hasData;

  /// Keluaran bulan ini vs periode sama bulan lalu.
  TrendDirection get outTrend => _trend(monthOut, lastMonthOut);

  /// Masukan bulan ini vs periode sama bulan lalu (naik = membaik).
  TrendDirection get inTrend => _trend(lastMonthIn, monthIn);

  static TrendDirection _trend(int current, int previous) {
    // Toleransi ±5% dianggap datar agar tidak berisik.
    if (previous <= 0) {
      return current <= 0 ? TrendDirection.flat : TrendDirection.worse;
    }
    if (current <= previous * 0.95) return TrendDirection.better;
    if (current >= previous * 1.05) return TrendDirection.worse;
    return TrendDirection.flat;
  }

  BudgetLevel get worstLevel {
    var worst = BudgetLevel.ok;
    for (final line in lines) {
      if (line.level == BudgetLevel.over) return BudgetLevel.over;
      if (line.level == BudgetLevel.warning) worst = BudgetLevel.warning;
    }
    return worst;
  }

  /// Garis dengan label persis; null bila tidak ada. Dipakai
  /// BudgetAlertService mencocokkan batas global tanpa string
  /// tersebar.
  LimitLine? lineByLabel(String label) {
    for (final line in lines) {
      if (line.label == label) return line;
    }
    return null;
  }

  /// Garis yang terlampaui (terburuk dulu).
  List<LimitLine> get overLines =>
      lines.where((l) => l.level == BudgetLevel.over).toList()
        ..sort(_byUsageDesc);

  /// Garis dalam zona waspada (75-100%), belum terlampaui.
  List<LimitLine> get warningLines =>
      lines.where((l) => l.level == BudgetLevel.warning).toList()
        ..sort(_byUsageDesc);

  /// Garis paling kritis (over → warning → ok), untuk pesan utama Duit.
  LimitLine? get criticalLine {
    final over = overLines;
    if (over.isNotEmpty) return over.first;
    final warn = warningLines;
    if (warn.isNotEmpty) return warn.first;
    return null;
  }

  static int _byUsageDesc(LimitLine a, LimitLine b) =>
      b.fraction.compareTo(a.fraction);
}

/// Hitung arah ringkas untuk chip "membaik/memburuk" di UI.
String trendLabel(TrendDirection trend, {required bool incoming}) =>
    switch (trend) {
      TrendDirection.better => incoming ? 'masuk naik' : 'keluar turun',
      TrendDirection.worse => incoming ? 'masuk turun' : 'keluar naik',
      TrendDirection.flat => incoming ? 'masuk stabil' : 'keluar stabil',
    };

/// Pace harian: berapa yang boleh dihabis hari ini agar kondisi tetap
/// aman sampai akhir periode.
class DailyPace {
  const DailyPace({
    required this.safeToSpend,
    required this.dayOfMonth,
    required this.daysInMonth,
    required this.idealUsedPercent,
  });

  /// Sisa aman hari ini; null = tanpa batas apa pun. Negatif = over.
  final int? safeToSpend;

  /// Tanggal 1-based dan panjang bulan berjalan.
  final int dayOfMonth;
  final int daysInMonth;

  /// Persen terpakai ideal sampai hari ini: round(day/daysInMonth*100).
  final int idealUsedPercent;
}

/// Hitung pace harian. Prioritas batas: harian → mingguan → bulanan;
/// limit `<= 0` diperlakukan tanpa batas (konsisten [LimitLine.level]).
/// Sisa periode dibagi rata ke sisa hari (rupiah penuh, dibulatkan ke
/// bawah); nilai bisa negatif — penanda OVER ada di UI.
DailyPace dailyPace({
  required DateTime now,
  required int dayOut,
  required int weekOut,
  required int monthOut,
  int? dailyLimit,
  int? weeklyLimit,
  int? monthlyTotal,
}) {
  final monthStart = DateTime(now.year, now.month);
  final daysInMonth =
      DateTime(now.year, now.month + 1).difference(monthStart).inDays;
  final dayOfMonth = now.day;

  int? safe;
  final scope = effectiveDailyScope(
    dailyLimit: dailyLimit,
    weeklyLimit: weeklyLimit,
    monthlyTotal: monthlyTotal,
  );
  switch (scope) {
    case LimitScope.daily:
      safe = dailyLimit! - dayOut;
    case LimitScope.weekly:
      // Senin = awal minggu; sisa hari termasuk hari ini, minimal 1.
      final daysLeftWeek = 7 - now.weekday + 1;
      safe = (weeklyLimit! - weekOut) ~/ daysLeftWeek;
    case LimitScope.monthly:
      final daysLeftMonth = daysInMonth - dayOfMonth + 1;
      safe = (monthlyTotal! - monthOut) ~/ daysLeftMonth;
    case null:
      safe = null;
  }

  return DailyPace(
    safeToSpend: safe,
    dayOfMonth: dayOfMonth,
    daysInMonth: daysInMonth,
    idealUsedPercent: (dayOfMonth / daysInMonth * 100).round(),
  );
}

/// Scope batas yang menentukan "jatah harian" ketika batas harian tidak
/// diset: harian → mingguan → bulanan. Prioritas ini sama dengan
/// [dailyBar] dan [dailyPace] — dipakai untuk memilih filter kategori yang
/// mengukur disiplin harian.
LimitScope? effectiveDailyScope({
  required int? dailyLimit,
  required int? weeklyLimit,
  required int? monthlyTotal,
}) {
  if (dailyLimit != null && dailyLimit > 0) return LimitScope.daily;
  if (weeklyLimit != null && weeklyLimit > 0) return LimitScope.weekly;
  if (monthlyTotal != null && monthlyTotal > 0) return LimitScope.monthly;
  return null;
}

/// Jatah harian: plafon kasar per hari dari batas yang ada. Prioritas
/// batas: harian → mingguan (`~/ 7`) → bulanan (`~/ hariBulanIni`);
/// limit `<= 0` dilewati (konsisten [LimitLine.level]); null bila
/// tanpa limit apa pun.
int? dailyBar({
  required DateTime now,
  int? dailyLimit,
  int? weeklyLimit,
  int? monthlyTotal,
}) {
  final scope = effectiveDailyScope(
    dailyLimit: dailyLimit,
    weeklyLimit: weeklyLimit,
    monthlyTotal: monthlyTotal,
  );
  return switch (scope) {
    LimitScope.daily => dailyLimit,
    LimitScope.weekly => (weeklyLimit ?? 0) ~/ 7,
    LimitScope.monthly => monthlyTotal == null
        ? null
        : monthlyTotal ~/
            DateTime(now.year, now.month + 1)
                .difference(DateTime(now.year, now.month))
                .inDays,
    null => null,
  };
}

/// Garis global (bukan alokasi kategori) yang layak ditampilkan di hero:
/// garis global berbatas yang paling kritis (over → warning → ok);
/// null bila memang belum ada anggaran apa pun. Batas nol/negatif =
/// tanpa batas (konsisten [LimitLine.level]).
LimitLine? heroBudgetLine(BudgetSnapshot snap) {
  final global = snap.lines
      .where((l) => !l.isCategory && (l.limit ?? 0) > 0)
      .toList();
  if (global.isEmpty) return null;
  global.sort((a, b) {
    final byLevel = b.level.index.compareTo(a.level.index);
    if (byLevel != 0) return byLevel;
    return b.fraction.compareTo(a.fraction);
  });
  return global.first;
}

/// Label delta persen periode berjalan vs pembanding: '▲ 12%', '▼ 3%',
/// '±0%'; null bila pembanding nol (tidak bisa dibandingkan).
String? deltaLabel(int current, int previous) {
  if (previous <= 0) return null;
  final pct = ((current - previous) * 100 / previous).round();
  if (pct == 0) return '±0%';
  return '${pct > 0 ? '▲' : '▼'} ${pct.abs()}%';
}
