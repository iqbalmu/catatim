import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bukuduit/game/mascot.dart';
import 'package:bukuduit/game/progress.dart';
import 'package:bukuduit/models.dart';
import 'package:bukuduit/storage/database.dart';
import 'package:bukuduit/storage/repository.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;
  late ProgressService progress;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LedgerRepository(db);
    progress = ProgressService(repository: repo);
  });

  tearDown(() async => db.close());

  Future<void> addTxAt(DateTime when) async {
    await repo.addManual(
      amount: 1000,
      direction: Direction.outgoing,
      kind: TxKind.payment,
      occurredAt: when,
    );
  }

  DateTime todayAt(int hour) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour);
  }

  group('streak & mood', () {
    test('tanpa transaksi: streak 0, mood sleepy', () async {
      await progress.refresh();
      final p = progress.latest!;
      expect(p.streakDays, 0);
      expect(p.recordedToday, isFalse);
      expect(p.mood, MascotMood.sleepy);
    });

    test('dicatat hari ini: streak ≥1, mood happy', () async {
      await addTxAt(todayAt(9));
      await progress.refresh();
      final p = progress.latest!;
      expect(p.recordedToday, isTrue);
      expect(p.streakDays, greaterThanOrEqualTo(1));
      expect(p.mood, MascotMood.happy);
    });

    test('kemarin dicatat, hari ini belum: streak tetap, mood idle', () async {
      await addTxAt(todayAt(9).subtract(const Duration(days: 1)));
      await progress.refresh();
      final p = progress.latest!;
      expect(p.recordedToday, isFalse);
      expect(p.streakDays, 1);
      expect(p.mood, MascotMood.idle);
    });

    test('hari ini dicatat setelah kemarin: streak lanjut', () async {
      await addTxAt(todayAt(9).subtract(const Duration(days: 1)));
      await addTxAt(todayAt(8));
      await progress.refresh();
      expect(progress.latest!.streakDays, 2);
    });

    test('gap sehari memutus streak', () async {
      await addTxAt(todayAt(9).subtract(const Duration(days: 3)));
      await addTxAt(todayAt(9).subtract(const Duration(days: 2)));
      await progress.refresh();
      // Kemarin & hari ini kosong → streak 0.
      expect(progress.latest!.streakDays, 0);
      expect(progress.latest!.mood, MascotMood.sleepy);
    });
  });

  group('XP & level', () {
    test('award menambah XP sesuai event', () async {
      await addTxAt(todayAt(9));
      await progress.refresh();
      await progress.award(XpEvent.manualAdd);
      expect(progress.latest!.xp, 2);
      await progress.award(XpEvent.capture);
      expect(progress.latest!.xp, 3);
    });

    test('level dasar benar', () async {
      await progress.refresh();
      expect(progress.latest!.level.name, 'Jajan');
      expect(progress.latest!.level.index, 0);
    });

    test('lintas ambang → level naik + perayaan tertunda', () async {
      await repo.setSetting('xp_total', '49');
      await addTxAt(todayAt(9));
      await progress.refresh();
      await progress.award(XpEvent.capture); // 49 + 1 = 50 → Hemat

      expect(progress.latest!.xp, 50);
      expect(progress.latest!.level.name, 'Hemat');
      expect(progress.latest!.mood, MascotMood.celebrate);
      expect(progress.pendingLevelUp, 'Hemat');

      // Dikonsumsi UI → tidak dirayakan dua kali.
      expect(progress.consumePendingLevelUp(), 'Hemat');
      expect(progress.consumePendingLevelUp(), isNull);
    });

    test('milestone streak tertunda saat hari pertama dicatat', () async {
      // Kemarin = hari ke-3 streak; hari ini belum dicatat.
      await addTxAt(todayAt(9).subtract(const Duration(days: 1)));
      await addTxAt(todayAt(9).subtract(const Duration(days: 2)));
      await addTxAt(todayAt(9).subtract(const Duration(days: 3)));
      await progress.refresh();
      expect(progress.consumePendingMilestone(), isNull);

      await addTxAt(todayAt(8));
      await progress.refresh();
      await progress.award(XpEvent.capture);
      expect(progress.latest!.streakDays, 4);
      expect(progress.pendingMilestone, isNull); // 4 bukan milestone

      // Sampai milestone 7 (3 hari lalu + hari ini hanya 4; gunakan 7 hari):
      for (var i = 4; i <= 7; i++) {
        await addTxAt(todayAt(8).subtract(Duration(days: i - 1)));
      }
      // Sekarang streak = 7 hari (kemarin-turun hingga 7 hari lalu) + hari ini.
      await progress.refresh();
      expect(progress.latest!.streakDays, greaterThanOrEqualTo(7));
    });
  });
}
