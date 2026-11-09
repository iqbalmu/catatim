import 'package:bukuduit/core/money.dart';
import 'package:bukuduit/game/progress.dart';
import 'package:bukuduit/models.dart';
import 'package:bukuduit/storage/database.dart';
import 'package:bukuduit/storage/repository.dart';
import 'package:bukuduit/ui/transaction_tile.dart';
import 'package:bukuduit/ui/transaksi_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TransaksiScreen: merender flattened list dengan header hari & transaksi individual', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LedgerRepository(db);
    final progress = ProgressService(repository: repo);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 10, 0);
    final yesterday = today.subtract(const Duration(days: 1));

    final acc = await repo.addAccount('BCA', AccountKind.bank);
    final categories = await repo.getCategories();
    final catMakan = categories.firstWhere((c) => c.name == 'Makanan');
    final catGaji = categories.firstWhere((c) => c.name == 'Gaji');

    // Hari 1: 2 transaksi
    await repo.addManual(
      accountId: acc.id,
      categoryId: catGaji.id,
      amount: 4000000,
      direction: Direction.incoming,
      occurredAt: today,
      kind: TxKind.other,
      counterparty: 'Transfer Masuk Klien',
    );
    await repo.addManual(
      accountId: acc.id,
      categoryId: catMakan.id,
      amount: 50000,
      direction: Direction.outgoing,
      occurredAt: today,
      kind: TxKind.payment,
      counterparty: 'Makan Siang',
    );

    // Hari 2: 1 transaksi
    await repo.addManual(
      accountId: acc.id,
      categoryId: catMakan.id,
      amount: 35000,
      direction: Direction.outgoing,
      occurredAt: yesterday,
      kind: TxKind.payment,
      counterparty: 'Kopi Pagi',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransaksiScreen(
            repository: repo,
            progress: progress,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verifikasi keberadaan TransactionDayHeader individual
    expect(find.byType(TransactionDayHeader), findsNWidgets(2));

    // Verifikasi keberadaan TransactionTile individual
    expect(find.byType(TransactionTile), findsNWidgets(3));

    // Verifikasi teks transaksi
    expect(find.text('Transfer Masuk Klien'), findsOneWidget);
    expect(find.text('Makan Siang'), findsOneWidget);
    expect(find.text('Kopi Pagi'), findsOneWidget);

    // Verifikasi ringkasan pemasukan & pengeluaran bulanan (nominal pemasukan ada di header & tile)
    expect(find.text('+${Money.format(4000000)}'), findsNWidgets(2));
    expect(find.text('-${Money.format(85000)}'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  });
}
