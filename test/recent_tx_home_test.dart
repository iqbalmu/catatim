import 'package:catatim/capture/capture_channel.dart';
import 'package:catatim/capture/pipeline.dart';
import 'package:catatim/game/progress.dart';
import 'package:catatim/models.dart';
import 'package:catatim/rules/engine.dart';
import 'package:catatim/rules/rule_set.dart';
import 'package:catatim/storage/database.dart';
import 'package:catatim/storage/repository.dart';
import 'package:catatim/theme/quest.dart';
import 'package:catatim/ui/home_screen.dart';
import 'package:catatim/ui/transaction_tile.dart';
import 'package:catatim/ui/transaksi_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Beranda menampilkan Transaksi Terbaru dan navigasi Lihat Semua ke tab Transaksi',
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

      // Tambahkan 2 transaksi contoh
      final accounts = await repo.getAccounts();
      final catId = (await repo.getCategories()).first.id;
      final accId = accounts.first.id;

      await repo.addManual(
        amount: 50000,
        direction: Direction.outgoing,
        kind: TxKind.payment,
        counterparty: 'Kopi Kenangan',
        accountId: accId,
        categoryId: catId,
        occurredAt: DateTime.now(),
      );

      await repo.addManual(
        amount: 25000,
        direction: Direction.outgoing,
        kind: TxKind.payment,
        counterparty: 'Indomaret',
        accountId: accId,
        categoryId: catId,
        occurredAt: DateTime.now(),
      );

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

      // 1. Verifikasi judul Transaksi Terbaru tampil di Beranda
      expect(find.text('Transaksi Terbaru'), findsOneWidget);
      expect(find.text('Lihat Semua'), findsOneWidget);

      // 2. Verifikasi transaksi tampil sebagai TransactionTile di Beranda
      expect(find.text('Kopi Kenangan'), findsOneWidget);
      expect(find.text('Indomaret'), findsOneWidget);
      expect(find.byType(TransactionTile), findsNWidgets(2));

      // 3. Tap 'Lihat Semua' berpindah ke tab Transaksi
      await tester.tap(find.text('Lihat Semua'));
      await tester.pumpAndSettle();

      expect(find.byType(TransaksiScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await db.close();
    },
  );
}
