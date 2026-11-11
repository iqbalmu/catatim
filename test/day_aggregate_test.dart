import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bukuduit/models.dart';
import 'package:bukuduit/storage/database.dart';
import 'package:bukuduit/storage/repository.dart';

/// Regresi agregasi-per-hari (audit O-03): sebelumnya baris mentah 370 hari
/// ditarik ke UI isolate dan dikelompokkan di Dart; kini GROUP BY di SQLite.
/// Test ini mengunci: bucket hari UTC (format penyimpanan epoch-ms),
/// batas [since] inklusif, pengecualian transfer, dan arah transaksi.
void main() {
  late AppDatabase db;
  late LedgerRepository repo;

  Future<void> addTx(
    DateTime occurredAt, {
    Direction direction = Direction.outgoing,
    int amount = 1000,
    TxKind kind = TxKind.payment,
  }) =>
      db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              uuid: DateTime.now().microsecondsSinceEpoch.toString(),
              bankId: 'bca',
              kind: kind,
              direction: direction,
              amount: amount,
              occurredAt: occurredAt,
              source: TxSource.manual,
            ),
          );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LedgerRepository(db);
  });
  tearDown(() async => db.close());

  test('txCountByDaySince: bucket per hari LOKAL, sejak inklusif', () async {
    final since = DateTime(2026, 11, 10);
    await addTx(DateTime(2026, 11, 10, 23, 30)); // hari sejak (batas)
    await addTx(DateTime(2026, 11, 11, 1)); // hari beda
    await addTx(DateTime(2026, 11, 11, 5), direction: Direction.incoming);
    await addTx(DateTime(2026, 11, 9, 12)); // sebelum since → dikecualikan

    final counts = await repo.txCountByDaySince(since);
    expect(counts[DateTime(2026, 11, 10)], 1);
    expect(counts[DateTime(2026, 11, 11)], 2);
    expect(counts.containsKey(DateTime(2026, 11, 9)), isFalse);
  });

  test('outSpendByDaySince: hanya keluar murni, transfer tak ikut', () async {
    final since = DateTime(2026, 11, 1);
    await addTx(DateTime(2026, 11, 2, 3),
        direction: Direction.outgoing, amount: 5000);
    await addTx(DateTime(2026, 11, 2, 4),
        direction: Direction.outgoing, amount: 3000);
    await addTx(DateTime(2026, 11, 2, 5),
        direction: Direction.incoming, amount: 9000);
    await addTx(DateTime(2026, 11, 2, 6),
        direction: Direction.outgoing, amount: 7000, kind: TxKind.transfer);

    final sums = await repo.outSpendByDaySince(since);
    expect(sums[DateTime(2026, 11, 2)], 8000);
  });

  test('watchOutSumByDaySince: re-emit saat tabel berubah', () async {
    final since = DateTime(2026, 11, 1);
    final emissions = <Map<DateTime, int>>[];
    final sub = repo
        .watchOutSumByDaySince(since)
        .listen(emissions.add);
    await addTx(DateTime(2026, 11, 3), direction: Direction.outgoing, amount: 1500);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(emissions, isNotEmpty);
    final last = emissions.last;
    expect(last[DateTime(2026, 11, 3)], 1500);
    await sub.cancel();
  });
}
