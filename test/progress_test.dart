import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bukuduit/core/budget.dart';
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

  Future<void> addTxAt(DateTime when, {int amount = 1000}) async {
    await repo.addManual(
      amount: amount,
      direction: Direction.outgoing,
      kind: TxKind.payment,
      occurredAt: when,
    );
  }

  DateTime todayAt(int hour) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour);
  }

  group('streak & mood dasar', () {
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

    test('milestone streak 7 dirayakan saat dicatat pertama hari ini',
        () async {
      // Streak 6 hari: 6..1 hari lalu. Hari ini belum dicatat.
      for (var i = 6; i >= 1; i--) {
        await addTxAt(todayAt(8).subtract(Duration(days: i)));
      }
      await progress.refresh();
      expect(progress.consumePendingMilestone(), isNull);

      // Catatan pertama hari ini → streak 7 = milestone.
      await addTxAt(todayAt(8));
      await progress.onTransactionRecorded();
      expect(progress.latest!.streakDays, 7);
      expect(progress.pendingMilestone, 7);
      expect(progress.consumePendingMilestone(), 7);
      expect(progress.pendingMilestone, isNull);
    });
  });

  group('anggaran & mood Duit', () {
    test('tanpa anggaran: semua garis tanpa batas, level ok', () async {
      await addTxAt(todayAt(9));
      await progress.refresh();
      final snap = progress.latest!.snapshot;
      expect(snap.lines, isNotEmpty);
      for (final line in snap.lines) {
        expect(line.limit, isNull);
        expect(line.level, BudgetLevel.ok);
      }
      expect(progress.latest!.mood, MascotMood.happy);
    });

    test('over batas harian → mood worried + alert realtime', () async {
      await repo.setSetting(kKeyDailyLimit, '1500');
      await addTxAt(todayAt(9), amount: 2000);
      await progress.refresh();
      expect(progress.latest!.snapshot.worstLevel, BudgetLevel.over);
      expect(progress.latest!.mood, MascotMood.worried);

      // Realtime: baseline dalam batas (batas dinaikkan), lalu transaksi
      // baru yang melampaui batas memunculkan alert.
      await repo.setSetting(kKeyDailyLimit, '5000'); // 2000/5000 → ok
      final fresh = ProgressService(repository: repo);
      await fresh.refresh();
      expect(fresh.latest!.snapshot.criticalLine, isNull);

      await addTxAt(todayAt(10), amount: 4000); // 6000/5000 → over
      await fresh.onTransactionRecorded();
      expect(fresh.pendingAlert, contains('Batas harian'));
      expect(fresh.latest!.mood, MascotMood.worried);
    });

    test('over → kembali dalam batas → pesan pemulihan + celebrate', () async {
      await repo.setSetting(kKeyDailyLimit, '2000');
      await addTxAt(todayAt(9), amount: 2000);
      await progress.refresh();
      expect(progress.latest!.mood, MascotMood.worried);

      await repo.setSetting(kKeyDailyLimit, '5000');
      await progress.onTransactionRecorded();
      expect(progress.latest!.mood, MascotMood.celebrate);
      expect(
        await progress.consumePendingRecovery(),
        contains('Batas harian'),
      );
      expect(await progress.consumePendingRecovery(), isNull);
    });

    test('alokasi kategori terlampaui menjadi garis kritis', () async {
      final categories = await repo.watchCategories().first;
      final makanan = categories.firstWhere((c) => c.name == 'Makanan');
      await repo.setBudget(makanan.id, 1000);
      await repo.addManual(
        amount: 1500,
        direction: Direction.outgoing,
        kind: TxKind.payment,
        categoryId: makanan.id,
        occurredAt: todayAt(9),
      );
      await progress.refresh();
      final critical = progress.latest!.snapshot.criticalLine!;
      expect(critical.label, 'Makanan');
      expect(critical.level, BudgetLevel.over);
      expect(progress.latest!.mood, MascotMood.worried);
    });

    test('warning 75% → mood idle dengan pesan waspada', () async {
      await repo.setSetting(kKeyDailyLimit, '2000');
      await addTxAt(todayAt(9), amount: 1800); // 90%
      await progress.refresh();
      expect(progress.latest!.snapshot.worstLevel, BudgetLevel.warning);
      expect(progress.latest!.mood, MascotMood.idle);
      expect(progress.latest!.moodLine, contains('waspada'));
    });

    test('alokasi ber-scope akun hanya menghitung akun itu', () async {
      final cats = await repo.watchCategories().first;
      final makanan = cats.firstWhere((c) => c.name == 'Makanan');
      final accounts = await repo.getAccounts();
      final blu = accounts.firstWhere((a) => a.name == 'blu by BCA');
      await repo.setBudget(makanan.id, 1000, accountId: blu.id);
      await repo.addManual(
        amount: 2000,
        direction: Direction.outgoing,
        kind: TxKind.payment,
        categoryId: makanan.id,
        accountId: blu.id,
        occurredAt: todayAt(9),
      );
      // Keluaran di luar scope (tanpa akun) tidak menggerus alokasi.
      await repo.addManual(
        amount: 5000,
        direction: Direction.outgoing,
        kind: TxKind.payment,
        categoryId: makanan.id,
        occurredAt: todayAt(10),
      );

      await progress.refresh();
      final line = progress.latest!.snapshot.lines
          .firstWhere((l) => l.label.contains('Makanan'));
      expect(line.label, 'Makanan · blu by BCA');
      expect(line.used, 2000);
      expect(line.level, BudgetLevel.over);
    });
  });
}
