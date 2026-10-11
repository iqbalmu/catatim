import 'package:flutter/foundation.dart';

import '../core/budget.dart';
import '../core/money.dart';
import '../game/mascot.dart';
import '../models.dart';
import '../storage/database.dart';
import '../storage/repository.dart';

/// Streak mencatat yang layak dirayakan.
const Set<int> kStreakMilestones = {3, 7, 14, 21, 30, 60, 100};

/// Ringkasan kondisi yang tampil di hero card.
class ProgressSummary {
  const ProgressSummary({
    required this.streakDays,
    required this.recordedToday,
    required this.mood,
    required this.moodLine,
    required this.snapshot,
    required this.monthIn,
    required this.monthOut,
    required this.dailyPace,
  });

  final int streakDays;
  final bool recordedToday;
  final MascotMood mood;
  final String moodLine;
  final BudgetSnapshot snapshot;
  final int monthIn;
  final int monthOut;

  /// Pace harian dari batas yang tersedia; null safeToSpend = tanpa batas.
  final DailyPace? dailyPace;
}

/// Otak di balik Duit: menerjemahkan kondisi anggaran + tren bulanan
/// menjadi mood maskot, dan mendeteksi kapan batas terlampaui secara
/// realtime (dipanggil tiap transaksi tercatat).
///
/// Sumber kebenaran streak = data transaksi itu sendiri (dihitung ulang,
/// tidak pernah drift); batas anggaran tersimpan di tabel budgets dan
/// settings.
class ProgressService extends ChangeNotifier {
  ProgressService({required LedgerRepository repository}) : _repo = repository;

  final LedgerRepository _repo;

  ProgressSummary? latest;

  /// Peringatan yang belum ditampilkan UI (garis batas naik level).
  String? pendingAlert;

  /// Pesan pemulihan (garis yang tadinya over kembali dalam batas).
  String? pendingRecovery;

  /// Milestone streak yang belum dirayakan UI.
  int? pendingMilestone;

  bool _celebrating = false;

  /// Hitung ulang seluruh kondisi dari data (dipanggil saat app mulai,
  /// setelah transaksi tercatat, dan saat UI perlu sinkron).
  Future<void> refresh() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayEnd = DateTime(now.year, now.month, now.day + 1);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);
    // Bulan lalu, rentang hari yang sama (adil untuk tengah bulan).
    final lastMonthStart = DateTime(now.year, now.month - 1);
    final lastMonthEnd = lastMonthStart.add(dayEnd.difference(monthStart));

    final counts = await _repo.txCountByDaySince(
      today.subtract(const Duration(days: 70)),
    );
    final recordedToday = (counts[today] ?? 0) > 0;

    // Streak: berjalan mundur dari hari ini (atau kemarin, bila hari ini
    // belum dicatat — belum mencatat hari ini bukan putus).
    var cursor = recordedToday
        ? today
        : today.subtract(const Duration(days: 1));
    var streak = 0;
    while ((counts[cursor] ?? 0) > 0) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final dayOut = await _repo.sumBetween(today, dayEnd, Direction.outgoing);
    final weekOut = await _repo.sumBetween(
      weekStart,
      dayEnd,
      Direction.outgoing,
    );
    final monthOut = await _repo.sumBetween(
      monthStart,
      monthEnd,
      Direction.outgoing,
    );
    final monthIn = await _repo.sumBetween(
      monthStart,
      monthEnd,
      Direction.incoming,
    );
    final lastMonthOut = await _repo.sumBetween(
      lastMonthStart,
      lastMonthEnd,
      Direction.outgoing,
    );
    final lastMonthIn = await _repo.sumBetween(
      lastMonthStart,
      lastMonthEnd,
      Direction.incoming,
    );
    final catAccountUsed = await _repo.outPairsBetween(monthStart, monthEnd);
    final budgets = await _repo.watchBudgets().first;
    final categories = await _repo.watchCategories().first;
    final accounts = await _repo.watchAccounts().first;
    final dailyLimit = int.tryParse(
      await _repo.getSetting(kKeyDailyLimit) ?? '',
    );
    final weekLimit = int.tryParse(
      await _repo.getSetting(kKeyWeeklyLimit) ?? '',
    );
    final monthTotalLimit = int.tryParse(
      await _repo.getSetting(kKeyMonthlyTotal) ?? '',
    );

    final categoryNames = {for (final c in categories) c.id: c.name};
    final accountNames = {for (final a in accounts) a.id: a.name};
    // Pemakaian satu alokasi: seluruh akun (scope global) atau akun
    // tertentu bila alokasi di-scope.
    int usedFor(Budget b) => catAccountUsed.entries
        .where((e) =>
            e.key.category == b.categoryId &&
            (b.accountId == null || e.key.account == b.accountId))
        .fold(0, (total, e) => total + e.value);
    final lines = <LimitLine>[
      LimitLine(label: 'Batas harian', used: dayOut, limit: dailyLimit),
      LimitLine(label: 'Batas mingguan', used: weekOut, limit: weekLimit),
      LimitLine(
        label: 'Total bulan ini',
        used: monthOut,
        limit: monthTotalLimit,
      ),
      for (final b in budgets)
        LimitLine(
          label: (categoryNames[b.categoryId] ?? 'Kategori') +
              (b.accountId == null
                  ? ''
                  : ' · ${accountNames[b.accountId] ?? 'akun'}'),
          used: usedFor(b),
          limit: b.monthlyLimit,
          isCategory: true,
        ),
    ];
    final snapshot = BudgetSnapshot(
      lines: lines,
      monthIn: monthIn,
      monthOut: monthOut,
      lastMonthIn: lastMonthIn,
      lastMonthOut: lastMonthOut,
      hasData: monthOut > 0 || monthIn > 0,
    );

    final wasCelebrating = _celebrating;
    final pace = dailyPace(
      now: now,
      dayOut: dayOut,
      weekOut: weekOut,
      monthOut: monthOut,
      dailyLimit: dailyLimit,
      weeklyLimit: weekLimit,
      monthlyTotal: monthTotalLimit,
    );
    latest = ProgressSummary(
      streakDays: streak,
      recordedToday: recordedToday,
      mood: _moodFor(snapshot, recordedToday, streak, wasCelebrating),
      moodLine: _moodLineFor(snapshot, recordedToday, streak),
      snapshot: snapshot,
      monthIn: monthIn,
      monthOut: monthOut,
      dailyPace: pace,
    );
    notifyListeners();
  }

  /// Realtime: dipanggil setiap transaksi tercatat (capture maupun manual).
  /// Mendeteksi garis batas yang naik level (ok→warning→over) atau pulih.
  Future<void> onTransactionRecorded() => _evaluate();

  Future<void> _evaluate() async {
    final before = latest?.snapshot;
    final recordedTodayBefore = latest?.recordedToday ?? false;
    final streakBefore = latest?.streakDays ?? 0;
    await refresh();

    final after = latest!.snapshot;
    if (before != null) {
      final prevLevels = {
        for (final line in before.lines) line.label: line.level,
      };
      String? alert;
      String? recovery;
      for (final line in after.lines) {
        final prev = prevLevels[line.label];
        final now = line.level;
        if (prev == BudgetLevel.over && now != BudgetLevel.over) {
          recovery ??= '${line.label} kembali dalam batas — Duit lega!';
        } else if (now.index > (prev ?? BudgetLevel.ok).index) {
          alert ??= now == BudgetLevel.over
              ? '${line.label} terlampaui — Duit khawatir '
                    '(${Money.format(line.used)})'
              : '${line.label} ${line.usedPercent}% terpakai — Duit '
                    'mulai waspada';
        }
      }
      pendingAlert ??= alert;
      pendingRecovery ??= recovery;
      if (recovery != null) {
        _celebrating = true;
        await refresh();
      }
    }

    // Milestone streak: dirayakan sekali saat hari ini pertama kali
    // mengangkat streak ke angka milestone.
    final streak = latest!.streakDays;
    if (!recordedTodayBefore &&
        latest!.recordedToday &&
        kStreakMilestones.contains(streak) &&
        streak != streakBefore) {
      pendingMilestone = streak;
    }
    notifyListeners();
  }

  String? consumePendingAlert() {
    final value = pendingAlert;
    pendingAlert = null;
    if (value != null) notifyListeners();
    return value;
  }

  Future<String?> consumePendingRecovery() async {
    final value = pendingRecovery;
    pendingRecovery = null;
    if (value != null) {
      _celebrating = false;
      await refresh();
    }
    return value;
  }

  int? consumePendingMilestone() {
    final value = pendingMilestone;
    pendingMilestone = null;
    return value;
  }

  MascotMood _moodFor(
    BudgetSnapshot snap,
    bool recordedToday,
    int streak,
    bool celebrating,
  ) {
    if (celebrating) return MascotMood.celebrate;
    if (!recordedToday && streak == 0) return MascotMood.sleepy;
    if (!snap.hasData) return MascotMood.idle;
    return switch (snap.worstLevel) {
      BudgetLevel.over => MascotMood.worried,
      BudgetLevel.warning => MascotMood.idle,
      BudgetLevel.ok => recordedToday ? MascotMood.happy : MascotMood.idle,
    };
  }

  String _moodLineFor(BudgetSnapshot snap, bool recordedToday, int streak) {
    if (!snap.hasData) {
      return 'Duit mengantuk… belum ada catatan bulan ini';
    }
    final critical = snap.criticalLine;
    if (critical != null && critical.level == BudgetLevel.over) {
      return 'Duit khawatir — ${critical.label} terlampaui '
          '(${critical.usedPercent}%)';
    }
    if (critical != null) {
      return 'Duit waspada — ${critical.label} ${critical.usedPercent}% '
          'terpakai';
    }
    if (snap.outTrend == TrendDirection.worse) {
      return 'Duit memperhatikan — keluaran naik dibanding bulan lalu';
    }
    if (recordedToday) {
      final praise = snap.outTrend == TrendDirection.better
          ? 'Duit bangga — dalam anggaran dan keluaran turun! '
          : 'Duit senang — masih dalam batas anggaran! ';
      return '$praise🔥$streak hari catat';
    }
    return 'Duit tenang — dalam batas; catat transaksimu hari ini';
  }
}
