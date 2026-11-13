/// Mesin anggaran murni — tanpa dependensi drift/Flutter, sehingga
/// unit-testable dan dipakai ProgressService maupun UI Anggaran.
///
/// Konvensi periode: [start, end) eksklusif di ujung atas.
library;

/// Batas alokasi harian / mingguan / total bulanan, dalam rupiah.
const String kKeyDailyLimit = 'budget_daily_limit';
const String kKeyWeeklyLimit = 'budget_weekly_limit';
const String kKeyMonthlyTotal = 'budget_monthly_total';

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
  });

  final String label;
  final int used;
  final int? limit;

  /// True untuk garis alokasi kategori (bukan batas global).
  final bool isCategory;

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
  if (dailyLimit != null && dailyLimit > 0) {
    safe = dailyLimit - dayOut;
  } else if (weeklyLimit != null && weeklyLimit > 0) {
    // Senin = awal minggu; sisa hari termasuk hari ini, minimal 1.
    final daysLeftWeek = 7 - now.weekday + 1;
    safe = (weeklyLimit - weekOut) ~/ daysLeftWeek;
  } else if (monthlyTotal != null && monthlyTotal > 0) {
    final daysLeftMonth = daysInMonth - dayOfMonth + 1;
    safe = (monthlyTotal - monthOut) ~/ daysLeftMonth;
  }

  return DailyPace(
    safeToSpend: safe,
    dayOfMonth: dayOfMonth,
    daysInMonth: daysInMonth,
    idealUsedPercent: (dayOfMonth / daysInMonth * 100).round(),
  );
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
  if (dailyLimit != null && dailyLimit > 0) return dailyLimit;
  if (weeklyLimit != null && weeklyLimit > 0) return weeklyLimit ~/ 7;
  if (monthlyTotal != null && monthlyTotal > 0) {
    final monthStart = DateTime(now.year, now.month);
    final daysInMonth =
        DateTime(now.year, now.month + 1).difference(monthStart).inDays;
    return monthlyTotal ~/ daysInMonth;
  }
  return null;
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
