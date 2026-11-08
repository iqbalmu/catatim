import 'package:bukuduit/models.dart';
import 'package:bukuduit/storage/database.dart';
import 'package:bukuduit/storage/repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LedgerRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Database Indexes Optimization', () {
    test('semua indeks komposit terpasang pada tabel transactions', () async {
      final rows = await db.customSelect(
        "PRAGMA index_list('transactions')",
      ).get();
      final indexNames = rows.map((r) => r.read<String>('name')).toSet();

      expect(indexNames, contains('idx_transactions_occurred_at'));
      expect(indexNames, contains('idx_transactions_account_occurred'));
      expect(indexNames, contains('idx_transactions_balance_covering'));
      expect(indexNames, contains('idx_transactions_dir_occurred'));
      expect(indexNames, contains('idx_transactions_cat_occurred'));
    });

    test('query planner SQLite menggunakan indeks yang sesuai', () async {
      // 1. Filter akun + order occurred_at
      final qpAccount = await db.customSelect(
        'EXPLAIN QUERY PLAN '
        'SELECT * FROM transactions WHERE account_id = 1 ORDER BY occurred_at DESC',
      ).get();
      final detailAccount = qpAccount.map((r) => r.read<String>('detail')).join(' ');
      expect(detailAccount, contains('idx_transactions_account_occurred'));

      // 2. Covering index untuk saldo akun (account_id, direction, amount)
      final qpBalance = await db.customSelect(
        'EXPLAIN QUERY PLAN '
        'SELECT account_id, SUM(amount) FROM transactions '
        "WHERE account_id = 1 AND direction = 'incoming'",
      ).get();
      final detailBalance = qpBalance.map((r) => r.read<String>('detail')).join(' ');
      expect(detailBalance, contains('idx_transactions_balance_covering'));
      expect(detailBalance, contains('COVERING INDEX'));

      // 3. Filter arah + order occurred_at
      final qpDir = await db.customSelect(
        'EXPLAIN QUERY PLAN '
        "SELECT * FROM transactions WHERE direction = 'outgoing' ORDER BY occurred_at DESC",
      ).get();
      final detailDir = qpDir.map((r) => r.read<String>('detail')).join(' ');
      expect(detailDir, contains('idx_transactions_dir_occurred'));

      // 4. Filter kategori + order occurred_at
      final qpCat = await db.customSelect(
        'EXPLAIN QUERY PLAN '
        'SELECT * FROM transactions WHERE category_id = 1 ORDER BY occurred_at DESC',
      ).get();
      final detailCat = qpCat.map((r) => r.read<String>('detail')).join(' ');
      expect(detailCat, contains('idx_transactions_cat_occurred'));
    });
  });

  group('SQL Aggregation - watchMonthlyCashflow', () {
    test('menghitung cashflow masuk, keluar, dan selisih bersih dengan benar', () async {
      final now = DateTime(2026, 11, 15, 10, 0);
      final start = DateTime(2026, 11, 1);
      final end = DateTime(2026, 12, 1);

      final acc1 = await repo.addAccount('BCA', AccountKind.bank);
      final acc2 = await repo.addAccount('Dompet', AccountKind.cash);
      final categories = await repo.getCategories();
      final catMakan = categories.firstWhere((c) => c.name == 'Makanan');
      final catGaji = categories.firstWhere((c) => c.name == 'Gaji');

      // 1. Pemasukan murni
      await repo.addManual(
        accountId: acc1.id,
        categoryId: catGaji.id,
        amount: 5000000,
        direction: Direction.incoming,
        occurredAt: now,
        kind: TxKind.other,
      );

      // 2. Pengeluaran murni
      await repo.addManual(
        accountId: acc1.id,
        categoryId: catMakan.id,
        amount: 150000,
        direction: Direction.outgoing,
        occurredAt: now,
        kind: TxKind.payment,
      );

      // 3. Pengeluaran di acc2
      await repo.addManual(
        accountId: acc2.id,
        categoryId: catMakan.id,
        amount: 50000,
        direction: Direction.outgoing,
        occurredAt: now,
        kind: TxKind.payment,
      );

      // 4. Transfer internal (harus diabaikan dari cashflow riil)
      await repo.addManualTransfer(
        fromAccountId: acc1.id,
        toAccountId: acc2.id,
        amount: 1000000,
        occurredAt: now,
      );

      // Cashflow gabungan seluruh akun
      final overall = await repo.watchMonthlyCashflow(start, end).first;
      expect(overall.totalIn, 5000000);
      expect(overall.totalOut, 200000); // 150.000 + 50.000 (transfer 1.000.000 diabaikan)
      expect(overall.net, 4800000);

      // Cashflow khusus akun acc1 (BCA)
      final bcaCashflow = await repo.watchMonthlyCashflow(start, end, accountId: acc1.id).first;
      expect(bcaCashflow.totalIn, 5000000);
      expect(bcaCashflow.totalOut, 150000);
      expect(bcaCashflow.net, 4850000);

      // Cashflow khusus akun acc2 (Dompet)
      final cashCashflow = await repo.watchMonthlyCashflow(start, end, accountId: acc2.id).first;
      expect(cashCashflow.totalIn, 0);
      expect(cashCashflow.totalOut, 50000);
      expect(cashCashflow.net, -50000);
    });

    test('mengembalikan 0 saat tidak ada transaksi dalam periode', () async {
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 2, 1);

      final cashflow = await repo.watchMonthlyCashflow(start, end).first;
      expect(cashflow.totalIn, 0);
      expect(cashflow.totalOut, 0);
      expect(cashflow.net, 0);
    });
  });
}
