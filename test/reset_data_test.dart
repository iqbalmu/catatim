import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';

import 'package:catatim/capture/capture_channel.dart';
import 'package:catatim/capture/pipeline.dart';
import 'package:catatim/core/budget.dart';
import 'package:catatim/game/progress.dart';
import 'package:catatim/models.dart';
import 'package:catatim/rules/engine.dart';
import 'package:catatim/rules/rule_set.dart';
import 'package:catatim/storage/database.dart';
import 'package:catatim/storage/repository.dart';
import 'package:catatim/theme/quest.dart';
import 'package:catatim/ui/rencana_batas.dart';
import 'package:catatim/ui/settings_screen.dart';

void main() {
  group('Reset / Kosongkan Data', () {
    test('LedgerRepository.resetAllData() mengosongkan transaksi, draf, bon, anggaran, dan reset akun/kategori bawaan', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LedgerRepository(db);

      // Pastikan kategori & akun terisi
      final cats = await repo.getCategories();
      expect(cats, isNotEmpty);
      final accounts = await repo.getAccounts();
      expect(accounts, isNotEmpty);

      // Tambah transaksi uji
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          uuid: 'test-1',
          bankId: 'manual',
          amount: 50000,
          direction: Direction.outgoing,
          kind: TxKind.payment,
          source: TxSource.manual,
          occurredAt: DateTime.now(),
          counterparty: const Value('Warung Nasi'),
          accountId: Value(accounts.first.id),
          categoryId: Value(cats.first.id),
        ),
      );

      // Tambah bon uji
      await repo.addBon(
        person: 'Budi',
        amount: 25000,
        direction: BonDirection.borrowed,
        occurredAt: DateTime.now(),
      );

      // Verifikasi ada transaksi & bon
      expect(await db.select(db.transactions).get(), isNotEmpty);
      expect(await db.select(db.bons).get(), isNotEmpty);

      // Jalankan resetAllData
      await repo.resetAllData();

      // Verifikasi transaksi, bon, draf, anggaran kosong
      expect(await db.select(db.transactions).get(), isEmpty);
      expect(await db.select(db.bons).get(), isEmpty);
      expect(await db.select(db.drafts).get(), isEmpty);
      expect(await db.select(db.budgets).get(), isEmpty);

      // Verifikasi akun bawaan dan kategori bawaan di-reset bersih dengan saldo 0
      final resetAccounts = await repo.getAccounts();
      expect(resetAccounts.length, equals(defaultAccounts.length));
      for (final a in resetAccounts) {
        expect(a.openingBalance, equals(0));
      }

      final resetCats = await repo.getCategories();
      expect(resetCats.length, equals(defaultCategoryNames.length));

      // Verifikasi setting demo_seed_disabled
      expect(await repo.getSetting('demo_seed_disabled'), equals('1'));

      await db.close();
    });

    testWidgets('SettingsScreen: Konfirmasi dialog reset data aplikasi', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LedgerRepository(db);
      final ruleSet = RuleSet.fromJson({
        'version': 1,
        'banks': [],
      });
      final pipeline = CapturePipeline(
        channel: const CaptureChannel(),
        engine: RuleEngine(ruleSet),
        repository: repo,
      );
      final progress = ProgressService(repository: repo);

      // Tambahkan transaksi
      final cats = await repo.getCategories();
      final accounts = await repo.getAccounts();
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          uuid: 'test-2',
          bankId: 'manual',
          amount: 75000,
          direction: Direction.outgoing,
          kind: TxKind.payment,
          source: TxSource.manual,
          occurredAt: DateTime.now(),
          counterparty: const Value('Toko Kopi'),
          accountId: Value(accounts.first.id),
          categoryId: Value(cats.first.id),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          home: Scaffold(
            body: SettingsScreen(
              repository: repo,
              pipeline: pipeline,
              ruleSet: ruleSet,
              progress: progress,
            ),
          ),
        ),
      );
      // SettingsScreen menampilkan Pochy beranimasi (loop) — pump manual.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Scroll ke bawah hingga menemukan 'Kosongkan Data Aplikasi'
      final tileFinder = find.text('Kosongkan Data Aplikasi');
      await tester.scrollUntilVisible(tileFinder, 300);
      await tester.ensureVisible(tileFinder);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tileFinder, findsOneWidget);

      // Tap Kosongkan Data Aplikasi
      await tester.tap(tileFinder);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Dialog konfirmasi muncul
      expect(find.text('Kosongkan Seluruh Data?'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Kosongkan Data'), findsOneWidget);

      // Batal terlebih dahulu
      await tester.tap(find.text('Batal'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Kosongkan Seluruh Data?'), findsNothing);
      expect(await db.select(db.transactions).get(), isNotEmpty);

      // Buka lagi dialog lalu konfirmasi Kosongkan Data
      await tester.tap(tileFinder);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Kosongkan Data'));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }

      // Verifikasi snackbar muncul dan data kosong
      expect(find.text('Beres! Semua data udah dibersihkan.'), findsOneWidget);
      expect(await db.select(db.transactions).get(), isEmpty);

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      await db.close();
    });

    testWidgets('RencanaBatas: batas bulanan otomatis reaktif menjadi Belum diatur setelah resetAllData', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LedgerRepository(db);

      // Set batas bulanan awal
      await repo.setSetting(kKeyMonthlyTotal, '1500000');

      // Seed satu transaksi keluar bulan ini: tanpa data, snapshot
      // kosong dan kartu batas menampilkan "Belum diatur" sejak awal.
      final cats = await repo.getCategories();
      final accounts = await repo.getAccounts();
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          uuid: 'rencana-reset-1',
          bankId: 'manual',
          amount: 150000,
          direction: Direction.outgoing,
          kind: TxKind.payment,
          source: TxSource.manual,
          occurredAt: DateTime.now(),
          counterparty: const Value('Warung Nasi'),
          accountId: Value(accounts.first.id),
          categoryId: Value(cats.first.id),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          home: Scaffold(
            body: RencanaBatas(
              repository: repo,
            ),
          ),
        ),
      );
      // RencanaBatas memakai skeleton shimmer beranimasi (loop) — pump
      // manual + runAsync: stream Drift emit di real-async, tidak jalan
      // di fake-time pumpAndSettle.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Memastikan batas 1.500.000 tampil
      expect(find.textContaining('1.500.000'), findsWidgets);

      // Jalankan resetAllData
      await repo.resetAllData();
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Memastikan batas 1.500.000 sudah hilang dan berubah menjadi Belum diatur
      expect(find.textContaining('1.500.000'), findsNothing);
      expect(find.text('Belum diatur'), findsWidgets);

      await db.close();
    });
  });
}
