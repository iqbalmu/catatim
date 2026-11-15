import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:catatim/models.dart';
import 'package:catatim/storage/database.dart';
import 'package:catatim/storage/repository.dart';
import 'package:catatim/theme/quest.dart';
import 'package:catatim/ui/transaction_sheet.dart';

void main() {
  Future<TxWithCategory> seedCapturedTx(AppDatabase db) async {
    final id = await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            uuid: newUuid(),
            bankId: 'blu',
            kind: TxKind.payment,
            direction: Direction.outgoing,
            amount: 35000,
            occurredAt: DateTime(2026, 10, 11, 10),
            source: TxSource.auto,
            rawTitle: const Value('blu by BCA'),
            rawBody: const Value(
              'Pembayaran QRIS Rp35.000 ke INDOMARET berhasil',
            ),
          ),
        );
    final tx = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(id))).getSingle();
    return TxWithCategory(tx: tx);
  }

  Future<TxWithCategory> seedManualTx(AppDatabase db) async {
    final id = await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            uuid: newUuid(),
            bankId: 'manual',
            kind: TxKind.payment,
            direction: Direction.outgoing,
            amount: 20000,
            occurredAt: DateTime(2026, 10, 12, 10),
            source: TxSource.manual,
          ),
        );
    final tx = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(id))).getSingle();
    return TxWithCategory(tx: tx);
  }

  Widget harness(TxWithCategory item, LedgerRepository repo) => MaterialApp(
    theme: QuestSchemes.light(),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () =>
                TransactionSheet.show(context, repo, existing: item),
            child: const Text('buka'),
          ),
        ),
      ),
    ),
  );

  testWidgets('transaksi hasil capture punya pintasan lihat notifikasi asal', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LedgerRepository(db);
    final item = await seedCapturedTx(db);

    await tester.pumpWidget(harness(item, repo));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    // Lonceng pintasan tampil di header langkah detail…
    expect(find.byTooltip('Lihat notifikasi asal'), findsOneWidget);
    expect(find.text('Notifikasi Asal'), findsNothing);

    // …dan membuka sheet berisi teks mentah notifikasi.
    await tester.tap(find.byTooltip('Lihat notifikasi asal'));
    await tester.pumpAndSettle();
    expect(find.text('Notifikasi Asal'), findsOneWidget);
    expect(find.textContaining('INDOMARET'), findsOneWidget);
    expect(find.text('blu by BCA'), findsOneWidget);
    expect(find.text('Salin Teks'), findsOneWidget);
  });

  testWidgets('transaksi manual tidak menampilkan pintasan notifikasi', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LedgerRepository(db);
    final item = await seedManualTx(db);

    await tester.pumpWidget(harness(item, repo));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Lihat notifikasi asal'), findsNothing);
  });
}
