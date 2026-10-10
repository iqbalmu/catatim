import 'package:flutter/foundation.dart';

import '../game/mascot.dart';
import '../storage/repository.dart';

/// Event yang memberi XP.
enum XpEvent { capture, manualAdd, reclassify }

const List<String> kLevelNames = ['Jajan', 'Hemat', 'Nabung', 'Aman', 'Sultan'];

/// Batas XP untuk masuk level ke-i (index sama dengan kLevelNames).
const List<int> kLevelThresholds = [0, 50, 150, 350, 700];

/// Streak yang layak dirayakan.
const Set<int> kStreakMilestones = {3, 7, 14, 21, 30, 60, 100};

const String _kXp = 'xp_total';
const String _kLevelSeen = 'level_seen';

class LevelInfo {
  const LevelInfo({
    required this.index,
    required this.name,
    required this.xpIntoLevel,
    required this.xpLevelSpan,
  });

  final int index;
  final String name;
  final int xpIntoLevel;
  final int xpLevelSpan;

  double get progressFraction =>
      xpLevelSpan <= 0 ? 1 : (xpIntoLevel / xpLevelSpan).clamp(0, 1);
}

class GameProgress {
  const GameProgress({
    required this.xp,
    required this.streakDays,
    required this.recordedToday,
    required this.mood,
    required this.level,
    required this.moodLine,
  });

  final int xp;
  final int streakDays;
  final bool recordedToday;
  final MascotMood mood;
  final LevelInfo level;
  final String moodLine;
}

/// Otak di balik Bukuduit Quest: XP, streak, level, dan mood maskot.
///
/// Sumber kebenaran streak = data transaksi itu sendiri (dihitung ulang,
/// tidak pernah drift); XP tersimpan di tabel settings.
class ProgressService extends ChangeNotifier {
  ProgressService({required LedgerRepository repository}) : _repo = repository;

  final LedgerRepository _repo;

  GameProgress? latest;

  /// Level naik yang belum dirayakan UI (nama level).
  String? pendingLevelUp;

  /// Milestone streak yang belum dirayakan UI.
  int? pendingMilestone;

  bool _celebrating = false;

  Future<void> refresh() async {
    final xp = int.tryParse(await _repo.getSetting(_kXp) ?? '') ?? 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
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

    final mood = _celebrating
        ? MascotMood.celebrate
        : recordedToday
        ? MascotMood.happy
        : streak > 0
        ? MascotMood.idle
        : MascotMood.sleepy;

    latest = GameProgress(
      xp: xp,
      streakDays: streak,
      recordedToday: recordedToday,
      mood: mood,
      level: _levelFor(xp),
      moodLine: _moodLine(mood, streak),
    );
    notifyListeners();
  }

  /// Beri XP untuk satu event, perbarui mood, dan tandai perayaan yang
  /// layak (level up / milestone streak).
  Future<void> award(XpEvent event) async {
    final xpBefore = int.tryParse(await _repo.getSetting(_kXp) ?? '') ?? 0;
    final newXp = xpBefore + _xpFor(event);
    await _repo.setSetting(_kXp, '$newXp');

    final recordedTodayBefore = latest?.recordedToday ?? false;
    await refresh();

    final levelBefore = _levelFor(xpBefore);
    final levelAfter = _levelFor(newXp);
    final seen = int.tryParse(await _repo.getSetting(_kLevelSeen) ?? '') ?? 0;

    if (levelAfter.index > levelBefore.index && levelAfter.index > seen) {
      await _repo.setSetting(_kLevelSeen, '${levelAfter.index}');
      pendingLevelUp = levelAfter.name;
      _celebrating = true;
      await refresh();
    } else if (!recordedTodayBefore &&
        (latest?.recordedToday ?? false) &&
        kStreakMilestones.contains(latest!.streakDays)) {
      pendingMilestone = latest!.streakDays;
    }
    notifyListeners();
  }

  /// Ambil (dan kosongkan) perayaan level up yang tertunda.
  String? consumePendingLevelUp() {
    final value = pendingLevelUp;
    if (value != null) {
      pendingLevelUp = null;
      _celebrating = false;
      // Kembalikan mood normal tanpa memicu notifikasi berulang.
      refresh();
    }
    return value;
  }

  /// Ambil (dan kosongkan) milestone streak yang tertunda.
  int? consumePendingMilestone() {
    final value = pendingMilestone;
    pendingMilestone = null;
    return value;
  }

  LevelInfo _levelFor(int xp) {
    var index = 0;
    for (var i = 0; i < kLevelThresholds.length; i++) {
      if (xp >= kLevelThresholds[i]) index = i;
    }
    final into = xp - kLevelThresholds[index];
    final span = index + 1 < kLevelThresholds.length
        ? kLevelThresholds[index + 1] - kLevelThresholds[index]
        : 0;
    return LevelInfo(
      index: index,
      name: kLevelNames[index],
      xpIntoLevel: into,
      xpLevelSpan: span,
    );
  }

  int _xpFor(XpEvent event) => switch (event) {
    XpEvent.capture => 1,
    XpEvent.manualAdd => 2,
    XpEvent.reclassify => 1,
  };

  String _moodLine(MascotMood mood, int streak) => switch (mood) {
    MascotMood.happy =>
      'Duit senang — kamu sudah catat hari ini! 🔥$streak hari beruntun',
    MascotMood.idle =>
      'Duit menunggu — catat transaksimu hari ini biar streak aman',
    MascotMood.sleepy => 'Duit mengantuk… sudah lama tidak ada catatan baru',
    MascotMood.celebrate => 'Duit berpesta! Level naik! 🎉',
  };
}
