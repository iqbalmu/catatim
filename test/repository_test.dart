import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bukuduit/models.dart';
import 'package:bukuduit/storage/database.dart';
import 'package:bukuduit/storage/repository.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LedgerRepository(db);
  });

  tearDown(() async => db.close());

  RawCapture capture({
    String packageName = 'id.bm.blu',
    String title = 'blu',
    String body = 'Kamu menerima transfer masuk Rp2.000.000 dari BUDI',
    DateTime? postedAt,
  }) =>
      RawCapture(
        packageName: packageName,
        title: title,
        body: body,
        postedAt: postedAt ?? DateTime(2026, 10, 10, 9),
      );

  ParsedDraft draft({int amount = 2000000}) => ParsedDraft(
        bankId: 'blu',
        bankName: 'blu by BCA',
        ruleName: 'transfer masuk',
        kind: TxKind.transfer,
        direction: Direction.incoming,
        amount: amount,
        counterparty: 'BUDI',
      );

  test('notifikasi sama dalam jendela dedup hanya menghasilkan 1 transaksi',
      () async {
    final raw = capture();
    await repo.recordFromCapture(raw: raw, draft: draft());
    await repo.recordFromCapture(
      raw: capture(postedAt: raw.postedAt.add(const Duration(seconds: 30))),
      draft: draft(),
    );

    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1));

    final logs = await db.select(db.captureLogs).get();
    expect(logs, hasLength(2));
    expect(logs.every((l) => l.parsed), isTrue);
    expect(logs.every((l) => l.transactionId == txs.first.id), isTrue);
  });

  test('notifikasi nominal berbeda menghasilkan transaksi terpisah', () async {
    await repo.recordFromCapture(raw: capture(), draft: draft());
    await repo.recordFromCapture(
      raw: capture(postedAt: DateTime(2026, 10, 10, 10)),
      draft: draft(amount: 99000),
    );
    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(2));
  });

  test('arah berbeda dengan nominal sama tidak ter-dedup', () async {
    await repo.recordFromCapture(
      raw: capture(),
      draft: draft(),
    );
    await repo.recordFromCapture(
      raw: capture(postedAt: DateTime(2026, 10, 10, 10)),
      draft: ParsedDraft(
        bankId: 'blu',
        bankName: 'blu by BCA',
        ruleName: 'transfer keluar',
        kind: TxKind.transfer,
        direction: Direction.outgoing,
        amount: 2000000,
      ),
    );
    expect(await db.select(db.transactions).get(), hasLength(2));
  });

  test('notifikasi tak terparse masuk capture log dengan parsed=false',
      () async {
    await repo.recordUnparsedCapture(capture());
    final logs = await db.select(db.captureLogs).get();
    expect(logs, hasLength(1));
    expect(logs.first.parsed, isFalse);
    expect(logs.first.transactionId, isNull);
  });

  test('input manual tersimpan dengan source manual', () async {
    await repo.addManual(
      amount: 150000,
      direction: Direction.outgoing,
      kind: TxKind.payment,
      counterparty: '  Kopi Kenangan  ',
    );
    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1));
    expect(txs.first.source, TxSource.manual);
    expect(txs.first.bankId, 'manual');
    expect(txs.first.counterparty, 'Kopi Kenangan');
  });

  test('capture otomatis mendapat kategori bawaan sesuai jenis', () async {
    await repo.recordFromCapture(raw: capture(), draft: draft()); // transfer
    final rows = await repo.watchRecentWithCategory().first;
    expect(rows.single.category?.name, 'Transfer');
  });

  test('settings simpan & ambil', () async {
    expect(await repo.getSetting('kunci'), isNull);
    await repo.setSetting('kunci', '1');
    expect(await repo.getSetting('kunci'), '1');
    await repo.setSetting('kunci', '0');
    expect(await repo.getSetting('kunci'), '0');
  });

  test('update & hapus transaksi', () async {
    await repo.addManual(
      amount: 1000,
      direction: Direction.outgoing,
      kind: TxKind.payment,
    );
    var rows = await repo.watchRecentWithCategory().first;
    expect(rows, hasLength(1));

    await repo.updateTransaction(
      rows.single.tx.id,
      const TransactionsCompanion(amount: Value(2000)),
    );
    rows = await repo.watchRecentWithCategory().first;
    expect(rows.single.tx.amount, 2000);

    await repo.deleteTransaction(rows.single.tx.id);
    expect(await repo.watchRecentWithCategory().first, isEmpty);
  });

  test('csv: header + satu baris data', () async {
    await repo.addManual(
      amount: 150000,
      direction: Direction.outgoing,
      kind: TxKind.payment,
      counterparty: 'Kopi "Kenangan", RT',
    );
    final csv = await repo.buildCsv();
    final lines = csv.trim().split('\n');
    expect(lines.first, 'tanggal,arah,nominal,jenis,kategori,bank,pihak,sumber');
    expect(lines, hasLength(2));
    expect(lines.last, contains('"Kopi ""Kenangan"", RT"'));
  });

  test('watchRecentWithCategory mengurutkan terbaru dulu', () async {
    await repo.recordFromCapture(
      raw: capture(postedAt: DateTime(2026, 10, 9, 8)),
      draft: draft(amount: 1000),
    );
    await repo.recordFromCapture(
      raw: capture(postedAt: DateTime(2026, 10, 10, 8)),
      draft: draft(amount: 2000),
    );
    final txs = await repo.watchRecentWithCategory().first;
    expect(txs.first.tx.amount, 2000);
  });
}
