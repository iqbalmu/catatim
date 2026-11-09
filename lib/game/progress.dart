import 'package:flutter/material.dart';

import '../core/budget.dart';
import '../core/money.dart';
import '../game/mascot.dart';
import '../storage/database.dart';
import '../storage/repository.dart';

/// Streak disiplin yang layak dirayakan.
const Set<int> kStreakMilestones = {3, 7, 14, 21, 30, 60, 100};

/// Lencana pencapaian disiplin pengeluaran
class SaverBadge {
  const SaverBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;
}

/// Status Level & XP Gamifikasi Keuangan
class SaverStats {
  const SaverStats({
    required this.level,
    required this.title,
    required this.currentXp,
    required this.nextLevelXp,
    required this.progress,
    required this.badges,
  });

  final int level;
  final String title;
  final int currentXp;
  final int nextLevelXp;
  final double progress; // 0.0 sampai 1.0
  final List<SaverBadge> badges;
}

/// Disiplin satu hari: pakai harian vs jatah harian saat itu.
class DailyDiscipline {
  const DailyDiscipline({
    required this.day,
    required this.used,
    required this.within,
    this.future = false,
  });

  /// Tengah malam lokal hari tersebut.
  final DateTime day;

  /// Belanja murni + sisihan hari itu.
  final int used;

  /// True bila [used] tidak melewati jatah harian.
  final bool within;

  /// True untuk tanggal depan bulan berjalan (belum terjadi).
  final bool future;
}

/// Ringkasan kondisi yang tampil di hero card.
class ProgressSummary {
  const ProgressSummary({
    required this.streakDays,
    required this.streakPaused,
    required this.recordedToday,
    required this.mood,
    required this.moodLine,
    required this.snapshot,
    this.dayOut = 0,
    required this.monthIn,
    required this.monthOut,
    required this.dailyPace,
    required this.activeDays,
    required this.disciplineMonth,
    required this.saverStats,
  });

  final int streakDays;

  /// True bila tanpa limit apa pun (jatah harian null): streak dijeda,
  /// [streakDays] 0 sampai pengguna mengatur batas.
  final bool streakPaused;

  final bool recordedToday;
  final MascotMood mood;
  final String moodLine;

  final BudgetSnapshot snapshot;
  final int dayOut;
  final int monthIn;
  final int monthOut;

  /// Pace harian dari batas yang tersedia; null safeToSpend = tanpa batas.
  final DailyPace? dailyPace;

  /// Hari-hari (tengah malam lokal) 30 hari terakhir yang punya ≥1
  /// transaksi — bahan strip Jejak Duit.
  final Set<DateTime> activeDays;

  /// Disiplin bulan berjalan (tanggal 1 → hari ini); kosong bila tanpa
  /// batas (streak dijeda).
  final List<DailyDiscipline> disciplineMonth;

  /// Gamifikasi level & XP khusus disiplin pengeluaran
  final SaverStats saverStats;
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
    try {
      final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayEnd = DateTime(now.year, now.month, now.day + 1);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);
    // Bulan lalu, rentang hari yang sama (adil untuk tengah bulan).
    final lastMonthStart = DateTime(now.year, now.month - 1);
    final lastMonthEnd = lastMonthStart.add(dayEnd.difference(monthStart));

    // Jendela evaluasi streak: ≤ 370 hari ke belakang.
    final streakSince = today.subtract(const Duration(days: 369));
    final counts = await _repo.txCountByDaySince(streakSince);
    final recordedToday = (counts[today] ?? 0) > 0;

    // Hari disiplin: berjalan mundur dari hari ini (atau kemarin, bila
    // hari ini belum dicatat — hari yang belum berjalan bukan putus).
    // Hari lolos bila belanja murni ≤ jatah harian; Rp0 lolos; over
    // berhenti; transfer biasa tidak dihitung; berhenti di tanggal
    // transaksi pertama (hari kosong sebelumnya bukan streak).
    var streak = 0;
    var streakPaused = false;

    // Keluar (pace + garis global) = belanja murni; transfer biasa tidak
    // masuk ke mana pun (opsi A).
    final dayOut = await _repo.sumSpendBetween(today, dayEnd);
    final weekOut = await _repo.sumSpendBetween(weekStart, dayEnd);
    final monthOut = await _repo.sumSpendBetween(monthStart, monthEnd);
    final monthIn = await _repo.sumIncomeBetween(monthStart, monthEnd);
    final lastMonthOut = await _repo.sumSpendBetween(
      lastMonthStart,
      lastMonthEnd,
    );
    final lastMonthIn = await _repo.sumIncomeBetween(
      lastMonthStart,
      lastMonthEnd,
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
    final bar = dailyBar(
      now: now,
      dailyLimit: dailyLimit,
      weeklyLimit: weekLimit,
      monthlyTotal: monthTotalLimit,
    );
    streakPaused = bar == null;
    final spendByDay = await _repo.outSpendByDaySince(streakSince);
    final disciplineMonth = <DailyDiscipline>[];
    if (!streakPaused) {
      DateTime? firstDay;
      for (final day in counts.keys) {
        if (firstDay == null || day.isBefore(firstDay)) firstDay = day;
      }
      // Tanpa transaksi apa pun belum ada bukti disiplin: streak 0
      // (bukan jendela penuh — menghindari milestone palsu).
      if (firstDay != null) {
        var cursor = recordedToday
            ? today
            : today.subtract(const Duration(days: 1));
        while (!cursor.isBefore(streakSince)) {
          if (cursor.isBefore(firstDay)) break;
          final used = spendByDay[cursor] ?? 0;
          if (used > bar) break;
          streak++;
          cursor = cursor.subtract(const Duration(days: 1));
        }
      }
    }
    if (!streakPaused) {
      for (var day = monthStart;
          day.isBefore(monthEnd);
          day = day.add(const Duration(days: 1))) {
        final future = day.isAfter(today);
        final used = future ? 0 : (spendByDay[day] ?? 0);
        disciplineMonth.add(
          DailyDiscipline(
              day: day, used: used, within: used <= bar, future: future),
        );
      }
    }

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
    final activeDays = <DateTime>{
      for (var i = 0; i < 30; i++)
        if ((counts[today.subtract(Duration(days: i))] ?? 0) > 0)
          today.subtract(Duration(days: i)),
    };
    final pace = dailyPace(
      now: now,
      dayOut: dayOut,
      weekOut: weekOut,
      monthOut: monthOut,
      dailyLimit: dailyLimit,
      weeklyLimit: weekLimit,
      monthlyTotal: monthTotalLimit,
    );

    // Gamifikasi: Hitung XP & Level Saver (Khusus Disiplin Spending)
    final keptDays = disciplineMonth.where((d) => !d.future && d.within).length;
    final totalXp = (keptDays * 50) + (streak * 50) + (activeDays.length * 10);
    
    final int level;
    final String levelTitle;
    final int levelFloorXp;
    final int nextLevelXp;
    if (totalXp < 200) {
      level = 1;
      levelTitle = 'Hemat Pemula';
      levelFloorXp = 0;
      nextLevelXp = 200;
    } else if (totalXp < 500) {
      level = 2;
      levelTitle = 'Penjaga Dompet';
      levelFloorXp = 200;
      nextLevelXp = 500;
    } else if (totalXp < 1000) {
      level = 3;
      levelTitle = 'Ahli Anggaran';
      levelFloorXp = 500;
      nextLevelXp = 1000;
    } else if (totalXp < 2000) {
      level = 4;
      levelTitle = 'Master Keuangan';
      levelFloorXp = 1000;
      nextLevelXp = 2000;
    } else {
      level = 5;
      levelTitle = 'Sultan Hemat';
      levelFloorXp = 2000;
      nextLevelXp = 5000;
    }

    final levelProgress = ((totalXp - levelFloorXp) / (nextLevelXp - levelFloorXp)).clamp(0.0, 1.0);

    final badges = [
      SaverBadge(
        id: 'shield_7d',
        title: 'Perisai Hemat',
        description: '7 hari belanja dalam batas',
        icon: Icons.shield_rounded,
        unlocked: streak >= 7,
      ),
      SaverBadge(
        id: 'streak_30d',
        title: 'Api 30 Hari',
        description: '30 hari berturut-turut dalam batas',
        icon: Icons.local_fire_department_rounded,
        unlocked: streak >= 30,
      ),
      SaverBadge(
        id: 'target_safe',
        title: 'Target Terjaga',
        description: 'Pengeluaran bulan ini aman dalam batas',
        icon: Icons.track_changes_rounded,
        unlocked: snapshot.hasData && snapshot.worstLevel != BudgetLevel.over,
      ),
      SaverBadge(
        id: 'active_logger',
        title: 'Pencatat Tangkas',
        description: 'Sudah mencatat pengeluaran di 10 hari berbeda',
        icon: Icons.edit_note_rounded,
        unlocked: activeDays.length >= 10,
      ),
    ];

    final saverStats = SaverStats(
      level: level,
      title: levelTitle,
      currentXp: totalXp,
      nextLevelXp: nextLevelXp,
      progress: levelProgress,
      badges: badges,
    );

    latest = ProgressSummary(
      streakDays: streak,
      streakPaused: streakPaused,
      recordedToday: recordedToday,
      mood: _moodFor(snapshot, recordedToday, streak, wasCelebrating),
      moodLine: _moodLineFor(snapshot, recordedToday, streak, streakPaused),
      snapshot: snapshot,
      dayOut: dayOut,
      monthIn: monthIn,
      monthOut: monthOut,
      dailyPace: pace,
      activeDays: activeDays,
      disciplineMonth: disciplineMonth,
      saverStats: saverStats,
    );
    notifyListeners();
    } catch (_) {
      // Database mungkin sedang ditutup atau stream queries dibatalkan.
    }
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

    // Milestone streak: dirayakan sekali per run saat hari ini pertama kali
    // mengangkat streak ke angka milestone. Run yang sudah dirayakan
    // tersimpan di setting `milestone_seen_{n}` agar restart tidak mengulang;
    // milestone berikutnya tetap dirayakan.
    final streak = latest!.streakDays;
    if (!recordedTodayBefore &&
        latest!.recordedToday &&
        kStreakMilestones.contains(streak) &&
        streak != streakBefore &&
        await _repo.getSetting('milestone_seen_$streak') == null) {
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

  Future<int?> consumePendingMilestone() async {
    final value = pendingMilestone;
    pendingMilestone = null;
    if (value != null) {
      await _repo.setSetting('milestone_seen_$value', '1');
    }
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

  String _moodLineFor(
    BudgetSnapshot snap,
    bool recordedToday,
    int streak,
    bool streakPaused,
  ) {
    final critical = snap.criticalLine;
    if (critical != null && critical.level == BudgetLevel.over) {
      return 'Yah, ${critical.label} lewat batas (${critical.usedPercent}%) — '
          'tarik napas, rapikan pelan-pelan ya';
    }
    if (critical != null) {
      return '${critical.label} sudah ${critical.usedPercent}% terpakai — '
          'masih sempat dijaga kok';
    }
    if (streakPaused) {
      return 'Atur batas harian dulu yuk, biar semangatmu nyala lagi';
    }
    if (!snap.hasData) {
      return 'Bulan ini masih sepi — ayo catat transaksi pertamamu';
    }
    if (snap.outTrend == TrendDirection.worse) {
      return 'Keluaran naik dibanding bulan lalu — yuk kita rapikan '
          'pelan-pelan';
    }
    if (recordedToday) {
      final praise = snap.outTrend == TrendDirection.better
          ? 'Hebat! Anggaran aman, keluaran turun — '
          : 'Keren! Masih dalam batas — ';
      return '$praise$streak hari berturut-turut';
    }
    return 'Tenang, semua masih dalam batas — jaga jatah harianmu ya';
  }
}
