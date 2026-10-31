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
  }) => RawCapture(
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

  test('arah berlawanan dengan nominal sama membuat draf terpisah', () async {
    await repo.addDraftFromCapture(raw: capture(), draft: draft());
    await repo.addDraftFromCapture(
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
    expect(await db.select(db.drafts).get(), hasLength(2));
  });

  test(
    'notifikasi tak terparse masuk capture log dengan parsed=false',
    () async {
      await repo.recordUnparsedCapture(capture());
      final logs = await db.select(db.captureLogs).get();
      expect(logs, hasLength(1));
      expect(logs.first.parsed, isFalse);
      expect(logs.first.transactionId, isNull);
    },
  );

  test('log tak terparse yang identik tidak dicatat dua kali', () async {
    final raw = capture();
    await repo.recordUnparsedCapture(raw);
    await repo.recordUnparsedCapture(
      capture(postedAt: raw.postedAt.add(const Duration(seconds: 5))),
    );
    expect(await db.select(db.captureLogs).get(), hasLength(1));
  });

  group('baca ulang notifikasi tak terbaca', () {
    ParsedDraft bluDraft() => ParsedDraft(
      bankId: 'blu',
      bankName: 'blu by BCA',
      ruleName: 'transfer masuk',
      kind: TxKind.transfer,
      direction: Direction.incoming,
      amount: 2000000,
    );

    test('berhasil menjadi draf + log ditandai terbaca', () async {
      await repo.recordUnparsedCapture(capture());
      final count = await repo.reparseWith(
        (raw) => bluDraft(),
        connectedBankIds: {'blu'},
      );
      expect(count, 1);
      expect(await db.select(db.drafts).get(), hasLength(1));
      expect(await db.select(db.transactions).get(), isEmpty);
      expect(await repo.unparsedCaptures(), isEmpty);
    });

    test('bank yang tak terhubung tidak dibaca ulang', () async {
      await repo.recordUnparsedCapture(capture());
      final count = await repo.reparseWith(
        (raw) => bluDraft(),
        connectedBankIds: const {},
      );
      expect(count, 0);
      expect(await db.select(db.drafts).get(), isEmpty);
      expect(await repo.unparsedCaptures(), hasLength(1));
    });
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

  test('draf otomatis mendapat kategori bawaan sesuai jenis', () async {
    await repo.addDraftFromCapture(raw: capture(), draft: draft()); // transfer
    final drafts = await repo.watchDrafts().first;
    final cats = await repo.getCategories();
    final transfer = cats.firstWhere((c) => c.name == 'Transfer');
    expect(drafts.single.categoryId, transfer.id);
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
    expect(
      lines.first,
      'tanggal,arah,nominal,jenis,kategori,bank,pihak,sumber',
    );
    expect(lines, hasLength(2));
    expect(lines.last, contains('"Kopi ""Kenangan"", RT"'));
  });

  test('watchRecentWithCategory mengurutkan terbaru dulu', () async {
    await repo.addManual(
      amount: 1000,
      direction: Direction.incoming,
      kind: TxKind.transfer,
      occurredAt: DateTime(2026, 10, 9, 8),
    );
    await repo.addManual(
      amount: 2000,
      direction: Direction.incoming,
      kind: TxKind.transfer,
      occurredAt: DateTime(2026, 10, 10, 8),
    );
    final txs = await repo.watchRecentWithCategory().first;
    expect(txs.first.tx.amount, 2000);
  });

  test('filter akun hanya menampilkan transaksi akun itu', () async {
    final blu = await repo.ensureBankAccount(
      bankId: 'blu',
      name: 'blu by BCA',
      kind: AccountKind.bank,
    );
    await repo.addDraftFromCapture(raw: capture(), draft: draft());
    final d = (await repo.watchDrafts().first).single;
    expect(d.accountId, blu.id);
    await repo.confirmDraft(
      d,
      amount: d.amount,
      direction: d.direction,
      kind: d.kind,
    );
    await repo.addManual(
      amount: 5000,
      direction: Direction.outgoing,
      kind: TxKind.payment,
    );
    final filtered = await repo
        .watchRecentWithCategory(accountId: blu.id)
        .first;
    expect(filtered, hasLength(1));
    expect(filtered.single.tx.amount, 2000000);
    final all = await repo.watchRecentWithCategory().first;
    expect(all, hasLength(2));
  });

  test('tambah akun baru dan duplikat ditolak', () async {
    final gopay = await repo.addAccount('GoPay', AccountKind.ewallet);
    expect(gopay.name, 'GoPay');
    expect(gopay.kind, AccountKind.ewallet);
    expect(
      () => repo.addAccount('GoPay', AccountKind.ewallet),
      throwsException,
    );
  });

  test('bon: tambah, lunasi, hapus; belum lunas diurut dulu', () async {
    final idA = await repo.addBon(
      person: 'Andi',
      amount: 100000,
      direction: BonDirection.lent,
      note: 'kopi',
    );
    await repo.addBon(
      person: 'Siti',
      amount: 50000,
      direction: BonDirection.borrowed,
    );
    var bons = await repo.watchBons().first;
    expect(bons.map((b) => b.person), containsAll(['Andi', 'Siti']));

    await repo.updateBon(
      idA,
      BonsCompanion(settledAt: Value(DateTime(2026, 10, 11))),
    );
    bons = await repo.watchBons().first;
    expect(bons.first.person, 'Siti'); // belum lunas diurut dulu
    expect(bons.last.settledAt, isNotNull);

    await repo.deleteBon(bons.first.id);
    bons = await repo.watchBons().first;
    expect(bons, hasLength(1));
  });

  test('ubah nama akun dan duplikat ditolak', () async {
    final gopay = await repo.addAccount('GoPay', AccountKind.ewallet);
    await repo.updateAccount(gopay.id, 'Gopay Baru');
    final accounts = await repo.getAccounts();
    expect(accounts.firstWhere((a) => a.id == gopay.id).name, 'Gopay Baru');
    expect(() => repo.updateAccount(gopay.id, 'blu by BCA'), throwsException);
  });

  test('hapus akun membuat transaksinya tanpa akun', () async {
    final blu = await repo.ensureBankAccount(
      bankId: 'blu',
      name: 'blu by BCA',
      kind: AccountKind.bank,
    );
    await repo.addDraftFromCapture(raw: capture(), draft: draft());
    final d = (await repo.watchDrafts().first).single;
    await repo.confirmDraft(
      d,
      amount: d.amount,
      direction: d.direction,
      kind: d.kind,
    );
    var rows = await repo.watchRecentWithCategory(accountId: blu.id).first;
    expect(rows, hasLength(1));

    await repo.deleteAccount(blu.id);
    rows = await repo.watchRecentWithCategory(accountId: blu.id).first;
    expect(rows, isEmpty);
    final all = await repo.watchRecentWithCategory().first;
    expect(all.single.tx.accountId, isNull);
  });

  test('alokasi: scope akun terpisah & upsert per scope', () async {
    final accounts = await repo.getAccounts();
    final blu = accounts.firstWhere((a) => a.name == 'blu by BCA');
    final cats = await repo.watchCategories().first;
    final makanan = cats.firstWhere((c) => c.name == 'Makanan');

    await repo.setBudget(makanan.id, 1000000);
    await repo.setBudget(makanan.id, 2000000); // upsert scope global
    await repo.setBudget(makanan.id, 500000, accountId: blu.id);

    var budgets = await repo.watchBudgets().first;
    expect(budgets.where((b) => b.categoryId == makanan.id), hasLength(2));
    expect(
      budgets.firstWhere((b) => b.accountId == null).monthlyLimit,
      2000000,
    );
    expect(
      budgets.firstWhere((b) => b.accountId == blu.id).monthlyLimit,
      500000,
    );

    // Pemakaian per pasangan (kategori, akun).
    final now = DateTime.now();
    await repo.addManual(
      amount: 100000,
      direction: Direction.outgoing,
      kind: TxKind.payment,
      categoryId: makanan.id,
      accountId: blu.id,
      occurredAt: DateTime(now.year, now.month, now.day, 10),
    );
    final pairs = await repo.outPairsBetween(
      DateTime(now.year, now.month),
      DateTime(now.year, now.month + 1),
    );
    expect(pairs[(category: makanan.id, account: blu.id)], 100000);

    await repo.removeBudget(makanan.id, accountId: blu.id);
    budgets = await repo.watchBudgets().first;
    expect(budgets.where((b) => b.categoryId == makanan.id), hasLength(1));
  });

  test('saldo akun = saldo awal + masuk − keluar', () async {
    final accounts = await repo.getAccounts();
    final blu = accounts.firstWhere((a) => a.name == 'blu by BCA');
    await repo.setOpeningBalance(blu.id, 1000000);
    final now = DateTime.now();
    await repo.addManual(
      amount: 300000,
      direction: Direction.incoming,
      kind: TxKind.transfer,
      accountId: blu.id,
      occurredAt: DateTime(now.year, now.month, now.day, 10),
    );
    await repo.addManual(
      amount: 200000,
      direction: Direction.outgoing,
      kind: TxKind.payment,
      accountId: blu.id,
      occurredAt: DateTime(now.year, now.month, now.day, 11),
    );
    final balances = await repo.watchAccountBalances().first;
    expect(balances[blu.id], 1100000);
  });

  test(
    'hapus kategori: transaksi pindah ke fallback, alokasi ikut hilang',
    () async {
      final cats = await repo.watchCategories().first;
      final makanan = cats.firstWhere((c) => c.name == 'Makanan');
      final lainnya = cats.firstWhere((c) => c.name == 'Lainnya');
      await repo.setBudget(makanan.id, 100000);
      final now = DateTime.now();
      await repo.addManual(
        amount: 25000,
        direction: Direction.outgoing,
        kind: TxKind.payment,
        categoryId: makanan.id,
        occurredAt: DateTime(now.year, now.month, now.day, 10),
      );

      await repo.deleteCategory(makanan.id, fallbackId: lainnya.id);

      final rows = await repo.watchRecentWithCategory().first;
      expect(rows.single.category?.name, 'Lainnya');
      final budgets = await repo.watchBudgets().first;
      expect(budgets.where((b) => b.categoryId == makanan.id), isEmpty);
      final catsAfter = await repo.watchCategories().first;
      expect(catsAfter.map((c) => c.name), isNot(contains('Makanan')));
    },
  );

  group('outSumByDaySince', () {
    Future<void> addOutAt(DateTime when, int amount) => repo.addManual(
      amount: amount,
      direction: Direction.outgoing,
      kind: TxKind.payment,
      occurredAt: when,
    );

    test('jumlah keluar per hari lokal, inklusif batas sejak', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await addOutAt(today.add(const Duration(hours: 9)), 5000);
      await addOutAt(today.subtract(const Duration(days: 1)), 7000);
      await addOutAt(today.subtract(const Duration(days: 6)), 9000);
      await addOutAt(today.subtract(const Duration(days: 31)), 11000);

      final sums = await repo
          .watchOutSumByDaySince(today.subtract(const Duration(days: 29)))
          .first;
      expect(sums[today], 5000);
      expect(sums[today.subtract(const Duration(days: 1))], 7000);
      expect(sums[today.subtract(const Duration(days: 6))], 9000);
      expect(
        sums.containsKey(today.subtract(const Duration(days: 31))),
        isFalse,
      );
    });

    test('hanya masuk tidak terhitung', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await repo.addManual(
        amount: 25000,
        direction: Direction.incoming,
        kind: TxKind.transfer,
        occurredAt: today.add(const Duration(hours: 8)),
      );
      final sums = await repo.watchOutSumByDaySince(today).first;
      expect(sums, isEmpty);
    });
  });

  group('belanja murni', () {
    test('transfer biasa bukan belanja', () async {
      await repo.addManual(
        amount: 5000000,
        direction: Direction.outgoing,
        kind: TxKind.transfer,
        occurredAt: DateTime(2026, 10, 10, 9),
      );
      final day = DateTime(2026, 10, 10);
      final next = day.add(const Duration(days: 1));
      expect(await repo.sumSpendBetween(day, next), 0);

      await repo.addManual(
        amount: 40000,
        direction: Direction.outgoing,
        kind: TxKind.payment,
        occurredAt: DateTime(2026, 10, 10, 10),
      );
      expect(await repo.sumSpendBetween(day, next), 40000);
    });

    test('outSpendPairsBetween hanya belanja murni', () async {
      final accounts = await repo.getAccounts();
      final blu = accounts.firstWhere((a) => a.name == 'blu by BCA');
      final cats = await repo.watchCategories().first;
      final makanan = cats.firstWhere((c) => c.name == 'Makanan');
      final now = DateTime.now();
      final start = DateTime(now.year, now.month);
      final end = DateTime(now.year, now.month + 1);
      await repo.addManual(
        amount: 100000,
        direction: Direction.outgoing,
        kind: TxKind.payment,
        categoryId: makanan.id,
        accountId: blu.id,
        occurredAt: DateTime(now.year, now.month, now.day, 10),
      );
      await repo.addManual(
        amount: 50000,
        direction: Direction.outgoing,
        kind: TxKind.transfer,
        categoryId: makanan.id,
        accountId: blu.id,
        occurredAt: DateTime(now.year, now.month, now.day, 11),
      );
      final pairs = await repo.outSpendPairsBetween(start, end);
      expect(pairs[(category: makanan.id, account: blu.id)], 100000);
    });

    test('outSpendByDaySince: kunci tengah-malam lokal, inklusif', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      await repo.addManual(
        amount: 5000,
        direction: Direction.outgoing,
        kind: TxKind.payment,
        occurredAt: today.add(const Duration(hours: 9)),
      );
      await repo.addManual(
        amount: 7000,
        direction: Direction.outgoing,
        kind: TxKind.payment,
        occurredAt: yesterday.add(const Duration(hours: 10)),
      );
      await repo.addManual(
        amount: 9000,
        direction: Direction.outgoing,
        kind: TxKind.transfer,
        occurredAt: today.add(const Duration(hours: 11)),
      );
      final map = await repo.outSpendByDaySince(yesterday);
      expect(map[today], 5000);
      expect(map[yesterday], 7000);
      expect(map, hasLength(2));
    });
  });

  group('model hubungkan bank: draf capture', () {
    test('notifikasi bank terhubung menjadi draf, bukan transaksi', () async {
      final id = await repo.addDraftFromCapture(raw: capture(), draft: draft());
      expect(id, isNotNull);

      expect(await db.select(db.transactions).get(), isEmpty);
      final drafts = await db.select(db.drafts).get();
      expect(drafts, hasLength(1));
      expect(drafts.first.bankId, 'blu');
      expect(drafts.first.amount, 2000000);
      expect(drafts.first.occurredAt, capture().postedAt);
      expect(drafts.first.rawBody, isNotNull);
    });

    test('notifikasi sama dalam jendela dedup tidak membuat draf kedua', () async {
      final raw = capture();
      expect(await repo.addDraftFromCapture(raw: raw, draft: draft()), isNotNull);
      expect(
        await repo.addDraftFromCapture(
          raw: capture(postedAt: raw.postedAt.add(const Duration(seconds: 30))),
          draft: draft(),
        ),
        isNull,
      );
      expect(await db.select(db.drafts).get(), hasLength(1));
    });

    test('dup yang digugurkan dedup tercatat terlihat (ignored_dup)', () async {
      final raw = capture();
      await repo.addDraftFromCapture(raw: raw, draft: draft());
      expect(
        await repo.addDraftFromCapture(
          raw: capture(postedAt: raw.postedAt.add(const Duration(seconds: 30))),
          draft: draft(),
        ),
        isNull,
      );
      final ignored = await repo.watchIgnoredDuplicates().first;
      expect(ignored, hasLength(1));
      expect(ignored.single.parsed, isTrue);
      // Pengiriman ulang identik tidak menambah baris log.
      expect(
        await repo.addDraftFromCapture(
          raw: capture(postedAt: raw.postedAt.add(const Duration(seconds: 60))),
          draft: draft(),
        ),
        isNull,
      );
      expect(await repo.watchIgnoredDuplicates().first, hasLength(1));
    });

    test('log bisa dihapus per baris', () async {
      await repo.recordUnparsedCapture(capture());
      final log = (await db.select(db.captureLogs).get()).single;
      await repo.deleteCaptureLog(log.id);
      expect(await db.select(db.captureLogs).get(), isEmpty);
    });

    test('prune menghapus log terbaca tua; yang belum terbaca utuh', () async {
      final old = DateTime.now().subtract(const Duration(days: 40));
      // Dua log tua: satu sudah terbaca (parsed), satu belum.
      await repo.recordUnparsedCapture(capture(body: 'sudah', postedAt: old));
      await repo.recordUnparsedCapture(capture(body: 'belum', postedAt: old));
      final logs = await db.select(db.captureLogs).get();
      final read = logs.firstWhere((l) => l.body == 'sudah');
      await (db.update(db.captureLogs)..where((c) => c.id.equals(read.id)))
          .write(const CaptureLogsCompanion(parsed: Value(true)));
      // Log segar belum terbaca — harus tetap ada.
      await repo.recordUnparsedCapture(capture(body: 'segar'));

      final removed = await repo.pruneCaptureLogs();
      expect(removed, 1);
      final left = await db.select(db.captureLogs).get();
      expect(left.map((l) => l.body).toSet(), {'belum', 'segar'});
    });

    test('draf juga ter-dedup terhadap transaksi yang sudah dikonfirmasi', () async {
      final raw = capture();
      await repo.addDraftFromCapture(raw: raw, draft: draft());
      final d = (await db.select(db.drafts).get()).single;
      await repo.confirmDraft(
        d,
        amount: d.amount,
        direction: d.direction,
        kind: d.kind,
      );
      expect(
        await repo.addDraftFromCapture(
          raw: capture(postedAt: raw.postedAt.add(const Duration(minutes: 1))),
          draft: draft(),
        ),
        isNull,
      );
      expect(await db.select(db.drafts).get(), isEmpty);
    });

    test('konfirmasi draf: transaksi source notifikasi + draf terhapus', () async {
      await repo.addDraftFromCapture(raw: capture(), draft: draft());
      final d = (await db.select(db.drafts).get()).single;

      final txId = await repo.confirmDraft(
        d,
        amount: 1500000, // user mengoreksi nominal
        direction: d.direction,
        kind: d.kind,
        counterparty: 'Budi S.',
      );

      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(1));
      expect(txs.first.id, txId);
      expect(txs.first.source, TxSource.notification);
      expect(txs.first.bankId, 'blu');
      expect(txs.first.amount, 1500000);
      expect(txs.first.counterparty, 'Budi S.');
      expect(txs.first.rawBody, d.rawBody);
      expect(txs.first.occurredAt, d.occurredAt);
      expect(await db.select(db.drafts).get(), isEmpty);
    });

    test('buang draf menghapusnya tanpa membuat transaksi', () async {
      await repo.addDraftFromCapture(raw: capture(), draft: draft());
      final d = (await db.select(db.drafts).get()).single;
      await repo.discardDraft(d.id);
      expect(await db.select(db.drafts).get(), isEmpty);
      expect(await db.select(db.transactions).get(), isEmpty);
    });

    test('watchDrafts berurutan terbaru dulu', () async {
      await repo.addDraftFromCapture(raw: capture(), draft: draft());
      await repo.addDraftFromCapture(
        raw: capture(postedAt: DateTime(2026, 10, 10, 10)),
        draft: draft(amount: 99000),
      );
      final drafts = await repo.watchDrafts().first;
      expect(drafts.first.amount, 99000);
    });
  });

  group('model hubungkan bank: koneksi', () {
    test('set & watch koneksi bank', () async {
      expect(await repo.connectedBankIds(), isEmpty);
      await repo.setBankConnected('blu', true);
      expect(await repo.connectedBankIds(), {'blu'});
      expect(await repo.watchConnectedBanks().first, {'blu'});

      await repo.setBankConnected('nagari', true);
      await repo.setBankConnected('blu', false);
      expect(await repo.connectedBankIds(), {'nagari'});
    });

    test('ensureBankAccount membuat akun sekali per bankId', () async {
      final a = await repo.ensureBankAccount(
        bankId: 'blu',
        name: 'blu by BCA',
        kind: AccountKind.bank,
      );
      final b = await repo.ensureBankAccount(
        bankId: 'blu',
        name: 'blu by BCA',
        kind: AccountKind.bank,
      );
      expect(a.id, b.id);
      expect(b.bankId, 'blu');
      expect(b.name, 'blu by BCA');
    });

    test('ensureBankAccount mengadopsi akun manual senama tanpa duplikat', () async {
      // Akun manual 'Dompet Lama' belum tertaut ke bank mana pun.
      final manual = await repo.addAccount('Dompet Lama', AccountKind.bank);
      expect(manual.bankId, isNull);
      // Menghubungkan bank dengan nama sama memakai akun itu, bukan duplikat.
      final adopted = await repo.ensureBankAccount(
        bankId: 'gopay',
        name: 'Dompet Lama',
        kind: AccountKind.bank,
      );
      expect(adopted.id, manual.id);
      expect(adopted.bankId, 'gopay');
      final again = await repo.ensureBankAccount(
        bankId: 'gopay',
        name: 'Dompet Lama',
        kind: AccountKind.bank,
      );
      expect(again.id, manual.id);
    });

    test('draf bank terhubung otomatis terikat akun yang tertaut', () async {
      // DB lama: akun 'blu by BCA' ada tanpa bank_id; migrasi menautkannya.
      final linked = await repo.ensureBankAccount(
        bankId: 'blu',
        name: 'blu by BCA',
        kind: AccountKind.bank,
      );
      await repo.addDraftFromCapture(raw: capture(), draft: draft());
      final d = (await db.select(db.drafts).get()).single;
      expect(d.accountId, linked.id);
    });
  });
}
