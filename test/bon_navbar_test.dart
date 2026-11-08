import 'package:bukuduit/capture/capture_channel.dart';
import 'package:bukuduit/capture/pipeline.dart';
import 'package:bukuduit/game/progress.dart';
import 'package:bukuduit/rules/engine.dart';
import 'package:bukuduit/rules/rule_set.dart';
import 'package:bukuduit/storage/database.dart';
import 'package:bukuduit/storage/repository.dart';
import 'package:bukuduit/theme/quest.dart';
import 'package:bukuduit/ui/bon_screen.dart';
import 'package:bukuduit/ui/home_screen.dart';
import 'package:bukuduit/ui/rencana_screen.dart';
import 'package:bukuduit/ui/transaksi_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Revisi navbar: menu Anggaran diganti Bon, tombol Bon di header Transaksi dihapus',
    (tester) async {
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
}
