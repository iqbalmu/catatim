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

  group('streak disiplin', () {
    Future<void> setDaily(int limit) =>
        repo.setSetting(kKeyDailyLimit, '$limit');

    Future<void> transferAt(DateTime when, int amount) => repo.addManual(
          amount: amount,
          direction: Direction.outgoing,
          kind: TxKind.transfer,
          occurredAt: when,
        );

    test('3 hari dalam jatah → streak 3', () async {
      await setDaily(5000);
      await addTxAt(todayAt(9), amount: 1000);
      await addTxAt(todayAt(9).subtract(const Duration(days: 1)), amount: 2000);
      await addTxAt(todayAt(9).subtract(const Duration(days: 2)), amount: 3000);
      await progress.refresh();
      final p = progress.latest!;
      expect(p.streakDays, 3);
      expect(p.streakPaused, isFalse);
    });

    test('kemarin over → streak 0', () async {
      await setDaily(5000);
      await addTxAt(todayAt(9).subtract(const Duration(days: 1)), amount: 6000);
      await addTxAt(todayAt(9).subtract(const Duration(days: 2)), amount: 1000);
      await progress.refresh();
      expect(progress.latest!.streakDays, 0);
      expect(progress.latest!.streakPaused, isFalse);
    });

    test('hari Rp0 lolos', () async {
      await setDaily(5000);
      await addTxAt(todayAt(9), amount: 1000);
      // Kemarin kosong (Rp0) → lolos, streak jalan terus.
      await addTxAt(todayAt(9).subtract(const Duration(days: 2)), amount: 1000);
      await progress.refresh();
      expect(progress.latest!.streakDays, 3);
    });

    test('hari ini over → 0 sekarang', () async {
      await setDaily(5000);
      await addTxAt(todayAt(9).subtract(const Duration(days: 1)), amount: 1000);
      await addTxAt(todayAt(9), amount: 6000);
      await progress.refresh();
      expect(progress.latest!.streakDays, 0);
    });

    test('tanpa limit: streak 0 + streakPaused true', () async {
      await addTxAt(todayAt(9), amount: 1000);
      await progress.refresh();
      final p = progress.latest!;
      expect(p.streakDays, 0);
      expect(p.streakPaused, isTrue);
      expect(p.moodLine, contains('batas'));
    });
    test('limit ada tapi tanpa transaksi: streak 0, tidak pause', () async {
      await setDaily(5000);
      await progress.refresh();
      final p = progress.latest!;
      expect(p.streakDays, 0);
      expect(p.streakPaused, isFalse);
    });

    test('surut berhenti di transaksi pertama (bukan 365)', () async {
      await setDaily(5000);
      await addTxAt(todayAt(9).subtract(const Duration(days: 10)), amount: 1000);
      await addTxAt(todayAt(9), amount: 1000);
      await progress.refresh();
      // Hari ini + 9 hari Rp0 + hari transaksi pertama = 11, bukan 370.
      expect(progress.latest!.streakDays, 11);
    });

    test('transfer biasa bukan belanja (opsi A)', () async {
      await setDaily(5000);
      await addTxAt(todayAt(9).subtract(const Duration(days: 1)), amount: 1000);
      await addTxAt(todayAt(9), amount: 1000);
      // Transfer antar-akun biasa diabaikan streak.
      await transferAt(todayAt(10), 20000);
      await progress.refresh();
      expect(progress.latest!.streakDays, 2);
    });

    test('tanpa transaksi & tanpa limit: streak 0, pause, mood sleepy',
        () async {
      await progress.refresh();
      final p = progress.latest!;
      expect(p.streakDays, 0);
      expect(p.streakPaused, isTrue);
      expect(p.recordedToday, isFalse);
      expect(p.mood, MascotMood.sleepy);
    });

    test('milestone streak 7 dirayakan saat hari ini dalam jatah', () async {
      await setDaily(5000);
      // Streak 6 hari: 6..1 hari lalu. Hari ini belum dicatat.
      for (var i = 6; i >= 1; i--) {
        await addTxAt(todayAt(8).subtract(Duration(days: i)), amount: 1000);
      }
      await progress.refresh();
      expect(progress.latest!.streakDays, 6);
      expect(await progress.consumePendingMilestone(), isNull);

      // Hari ini dalam jatah → streak 7 = milestone.
      await addTxAt(todayAt(8), amount: 1000);
      await progress.onTransactionRecorded();
      expect(progress.latest!.streakDays, 7);
      expect(progress.pendingMilestone, 7);
      expect(await progress.consumePendingMilestone(), 7);
      expect(progress.pendingMilestone, isNull);
    });
    test('milestone tidak diulang setelah restart', () async {
      await setDaily(5000);
      // 6 hari lalu → hari ini belum dicatat: streak 6.
      for (var i = 6; i >= 1; i--) {
        await addTxAt(todayAt(8).subtract(Duration(days: i)), amount: 1000);
      }
      await progress.refresh();
      expect(progress.latest!.streakDays, 6);
      expect(await progress.consumePendingMilestone(), isNull);

      // Hari ini dalam jatah → streak 7 = milestone, rayakan sekali.
      await addTxAt(todayAt(8), amount: 1000);
      await progress.onTransactionRecorded();
      expect(progress.latest!.streakDays, 7);
      expect(progress.pendingMilestone, 7);
      expect(await progress.consumePendingMilestone(), 7);

      // Restart: service baru, repo sama. Refresh tidak mengulang.
      final restarted = ProgressService(repository: repo);
      await restarted.refresh();
      expect(restarted.latest!.streakDays, 7);
      expect(restarted.pendingMilestone, isNull);

      // Evaluate segar setelah restart TIDAK boleh mengulang 7 yang sama.
      final restartedFresh = ProgressService(repository: repo);
      await restartedFresh.onTransactionRecorded();
      expect(restartedFresh.pendingMilestone, isNull);

      // Streak 8 bukan milestone → tetap null.
      await addTxAt(todayAt(8).subtract(const Duration(days: 7)), amount: 1000);
      final atEight = ProgressService(repository: repo);
      await atEight.refresh();
      expect(atEight.latest!.streakDays, 8);
      await atEight.onTransactionRecorded();
      expect(atEight.pendingMilestone, isNull);
      expect(await atEight.consumePendingMilestone(), isNull);

      // Run baru: lengkapi ke 14 hari → milestone 14 tetap dirayakan.
      for (var i = 8; i <= 13; i++) {
        await addTxAt(todayAt(8).subtract(Duration(days: i)), amount: 1000);
      }
      final atFourteen = ProgressService(repository: repo);
      await atFourteen.onTransactionRecorded();
      expect(atFourteen.latest!.streakDays, 14);
      expect(atFourteen.pendingMilestone, 14);
      expect(await atFourteen.consumePendingMilestone(), 14);
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

  group('dailyPace dalam ringkasan', () {
    test('ringkasan membawa sisa aman harian', () async {
      await repo.setSetting(kKeyDailyLimit, '5000');
      await addTxAt(todayAt(9), amount: 1250);
      await progress.refresh();
      final p = progress.latest!;
      expect(p.dailyPace, isNotNull);
      expect(p.dailyPace!.safeToSpend, 3750);
    });

    test('tanpa batas apa pun: safeToSpend null', () async {
      await addTxAt(todayAt(9));
      await progress.refresh();
      expect(progress.latest!.dailyPace?.safeToSpend, isNull);
    });
    test('pace memakai belanja murni, transfer biasa diabaikan', () async {
      await repo.setSetting(kKeyDailyLimit, '50000');
      await repo.addManual(
        amount: 40000,
        direction: Direction.outgoing,
        kind: TxKind.payment,
        occurredAt: todayAt(9),
      );
      await progress.refresh();
      // 50rb - 40rb = 10rb.
      expect(progress.latest!.dailyPace!.safeToSpend, 10000);
      expect(progress.latest!.monthOut, 40000);
      final dayLine = progress.latest!.snapshot.lines
          .firstWhere((l) => l.label == 'Batas harian');
      expect(dayLine.used, 40000);
      // Transfer biasa bukan belanja: pace tak berubah.
      await repo.addManual(
        amount: 5000000,
        direction: Direction.outgoing,
        kind: TxKind.transfer,
        occurredAt: todayAt(11),
      );
      await progress.refresh();
      expect(progress.latest!.dailyPace!.safeToSpend, 10000);
      expect(progress.latest!.monthOut, 40000);
    });
  });

  group('activeDays jejak duit', () {
    test('30 hari terakhir yang ada transaksi', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await addTxAt(todayAt(9));
      await addTxAt(todayAt(9).subtract(const Duration(days: 3)));
      await addTxAt(todayAt(9).subtract(const Duration(days: 40)));
      await progress.refresh();
      final days = progress.latest!.activeDays;
      expect(days, contains(today));
      expect(days, contains(today.subtract(const Duration(days: 3))));
      expect(days, isNot(contains(today.subtract(const Duration(days: 40)))));
    });

    test('tanpa transaksi: himpunan kosong', () async {
      await progress.refresh();
      expect(progress.latest!.activeDays, isEmpty);
    });
  });
}
