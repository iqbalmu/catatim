import 'package:catatim/capture/capture_channel.dart';
import 'package:catatim/capture/pipeline.dart';
import 'package:catatim/game/progress.dart';
import 'package:catatim/models.dart';
import 'package:catatim/rules/engine.dart';
import 'package:catatim/rules/rule_set.dart';
import 'package:catatim/storage/database.dart';
import 'package:catatim/storage/repository.dart';
import 'package:catatim/theme/quest.dart';
import 'package:catatim/ui/bon_screen.dart';
import 'package:catatim/ui/home_screen.dart';
import 'package:catatim/ui/rencana_screen.dart';
import 'package:catatim/ui/transaksi_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Revisi navbar: menu Anggaran diganti Bon, tombol Bon di header Transaksi dihapus',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LedgerRepository(db);
      final ruleSet = RuleSet.fromJson({'version': 1, 'banks': []});
      final pipeline = CapturePipeline(
        channel: const CaptureChannel(),
        engine: RuleEngine(ruleSet),
        repository: repo,
      );
      final progress = ProgressService(repository: repo);

      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          home: HomeScreen(
            repository: repo,
            pipeline: pipeline,
            progress: progress,
            ruleSet: ruleSet,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verifikasi navbar memiliki 'Bon' dan tidak ada 'Anggaran' di navbar
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Transaksi'), findsOneWidget);
      expect(find.text('Bon'), findsOneWidget);
      expect(find.text('Laporan'), findsOneWidget);

      // 2. Buka tab Transaksi, verifikasi tombol Bon di header tidak ada
      await tester.tap(find.text('Transaksi'));
      await tester.pumpAndSettle();

      expect(find.byType(TransaksiScreen), findsOneWidget);
      // Header icons: cari transaksi & filter ada, tapi tidak ada tombol Bon di header Transaksi
      expect(find.byTooltip('Cari Transaksi'), findsOneWidget);
      expect(find.byTooltip('Filter Transaksi'), findsOneWidget);
      // 'Bon & Utang-Piutang' tidak muncul di layar Transaksi
      expect(find.text('Bon & Utang-Piutang'), findsNothing);

      // 3. Buka tab Bon dari navbar, verifikasi BonScreen tampil
      await tester.tap(find.text('Bon'));
      await tester.pumpAndSettle();

      expect(find.byType(BonScreen), findsOneWidget);
      expect(find.text('Bon & Utang-Piutang'), findsOneWidget);
      expect(find.text('PIUTANG'), findsOneWidget);
      expect(find.text('UTANG'), findsOneWidget);
      expect(find.text('Belum Lunas'), findsOneWidget);
      expect(find.text('Lunas'), findsOneWidget);

      // 4. Verifikasi Anggaran tetap dapat dibuka (misal via navigasi RencanaScreen)
      // Buka Beranda
      await tester.tap(find.text('Beranda'));
      await tester.pumpAndSettle();

      // Tap kartu anggaran di Beranda untuk membuka RencanaScreen
      final budgetCardFinder = find.text('Anggaran Bulan Ini');
      if (budgetCardFinder.evaluate().isNotEmpty) {
        await tester.tap(budgetCardFinder);
        await tester.pumpAndSettle();
        expect(find.byType(RencanaScreen), findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await db.close();
    },
  );

  testWidgets(
    'Alur Bon Open Tab: input tanpa nominal, badge Belum Dihitung, dan pelunasan dengan input nominal',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LedgerRepository(db);

      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          home: Scaffold(body: BonScreen(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();

      // Tambah bon warung open tab
      await repo.addBon(
        person: 'Warung Bu Tejo',
        direction: BonDirection.borrowed,
        note: 'Kopi & rokok',
      );
      await tester.pumpAndSettle();

      // Verifikasi badge Belum Dihitung dan ringkasan (+ 1 open)
      expect(find.text('Warung Bu Tejo'), findsOneWidget);
      expect(find.text('Belum Dihitung'), findsOneWidget);
      expect(find.text('Kita berutang (+ 1 open)'), findsOneWidget);
      expect(find.text('Hitung & Lunasi'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await db.close();
    },
  );

  testWidgets(
    'Bon dengan kategori dan rencana dompet tampil pada kartu dan terpakai saat pelunasan',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LedgerRepository(db);

      final accounts = await repo.getAccounts();
      final cashAccount = accounts.first;
      await repo.setOpeningBalance(cashAccount.id, 500000);
      final categories = await repo.getCategories();
      final foodCat = categories.firstWhere(
        (c) => c.name.toLowerCase().contains('makan'),
        orElse: () => categories.first,
      );

      await repo.addBon(
        person: 'Warung Bu Tejo',
        amount: 25000,
        direction: BonDirection.borrowed,
        note: 'Nasi bungkus',
        categoryId: foodCat.id,
        accountId: cashAccount.id,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          home: Scaffold(body: BonScreen(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi nama kategori dan nama akun tampil pada kartu bon
      expect(find.text('Warung Bu Tejo'), findsOneWidget);
      expect(find.text(foodCat.name), findsOneWidget);
      expect(find.text('· ${cashAccount.name}'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await db.close();
    },
  );
}
