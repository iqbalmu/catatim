import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bukuduit/models.dart';
import 'package:bukuduit/rules/rule_set.dart';
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

  test(
    'periode [start, end): transaksi tepat di ujung atas milik periode berikutnya',
    () async {
      // Audit B-02 — ujung atas eksklusif; dulu BETWEEN inklusif membuat
      // transaksi tengah malam persis terhitung di dua bulan.
      await repo.addManual(
        amount: 1000,
        direction: Direction.outgoing,
        kind: TxKind.payment,
        occurredAt: DateTime(2026, 10, 31, 23, 59, 59, 999),
      );
      await repo.addManual(
        amount: 2000,
        direction: Direction.outgoing,
        kind: TxKind.payment,
        occurredAt: DateTime(2026, 11, 1), // tepat 00:00:00.000
      );
      final okt = await repo
          .watchBetweenWithCategory(
            DateTime(2026, 10, 1),
            DateTime(2026, 11, 1),
          )
          .first;
      final nov = await repo
          .watchBetweenWithCategory(
            DateTime(2026, 11, 1),
            DateTime(2026, 12, 1),
          )
          .first;
      expect(okt, hasLength(1));
      expect(nov, hasLength(1));
      expect(nov.first.tx.amount, 2000);
    },
  );

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

    test(
      'notifikasi sama dalam jendela dedup tidak membuat draf kedua',
      () async {
        final raw = capture();
        expect(
          await repo.addDraftFromCapture(raw: raw, draft: draft()),
          isNotNull,
        );
        expect(
          await repo.addDraftFromCapture(
            raw: capture(
              postedAt: raw.postedAt.add(const Duration(seconds: 30)),
            ),
            draft: draft(),
          ),
          isNull,
        );
        expect(await db.select(db.drafts).get(), hasLength(1));
      },
    );

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

    test(
      'draf juga ter-dedup terhadap transaksi yang sudah dikonfirmasi',
      () async {
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
            raw: capture(
              postedAt: raw.postedAt.add(const Duration(minutes: 1)),
            ),
            draft: draft(),
          ),
          isNull,
        );
        expect(await db.select(db.drafts).get(), isEmpty);
      },
    );

    test(
      'konfirmasi draf: transaksi source notifikasi + draf terhapus',
      () async {
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
      },
    );

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

    test(
      'ensureBankAccount mengadopsi akun manual senama tanpa duplikat',
      () async {
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
      },
    );

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

  group('mode belajar: bank custom', () {
    test('CRUD koneksi app custom tersimpan & terpantau', () async {
      await repo.setCustomBankConnected('com.strike.app', 'Strike', true);
      await repo.setCustomBankConnected('id.gojek.app', 'Gojek', true);
      var list = await repo.customBanks();
      expect(list.map((c) => c.package), ['com.strike.app', 'id.gojek.app']);
      expect(list.first.label, 'Strike');

      // Putus satu — sisanya utuh, urutan dipertahankan.
      await repo.setCustomBankConnected('com.strike.app', '', false);
      list = await repo.customBanks();
      expect(list, hasLength(1));
      expect(list.single.package, 'id.gojek.app');

      // Re-hubung tak menduplikat.
      await repo.setCustomBankConnected('id.gojek.app', 'Gojek', true);
      expect(await repo.customBanks(), hasLength(1));
    });

    test('draf mentah: dedup isi identik, beda isi tak menelan', () async {
      final at = DateTime(2026, 10, 10, 9);
      final a = RawCapture(
        packageName: 'com.strike.app',
        title: 'Strike',
        body: 'Isi sama',
        postedAt: at,
      );
      final first = await repo.addRawDraftFromCapture(
        raw: a,
        bankId: 'app:com.strike.app',
        bankName: 'Strike',
        amount: 0,
        direction: Direction.incoming,
      );
      final dup = await repo.addRawDraftFromCapture(
        raw: RawCapture(
          packageName: a.packageName,
          title: a.title,
          body: a.body,
          postedAt: at.add(const Duration(seconds: 60)),
        ),
        bankId: 'app:com.strike.app',
        bankName: 'Strike',
        amount: 0,
        direction: Direction.incoming,
      );
      final other = await repo.addRawDraftFromCapture(
        raw: RawCapture(
          packageName: a.packageName,
          title: a.title,
          body: 'Isi berbeda',
          postedAt: at.add(const Duration(seconds: 90)),
        ),
        bankId: 'app:com.strike.app',
        bankName: 'Strike',
        amount: 0,
        direction: Direction.incoming,
      );
      expect(first, isNotNull);
      expect(dup, isNull); // identik → digugurkan
      expect(other, isNotNull); // beda isi → tetap
      expect(await db.select(db.drafts).get(), hasLength(2));
    });
  });

  group('custom templates persistence', () {
    test('CRUD custom templates via repository', () async {
      expect(await repo.customTemplates(), isEmpty);

      final t1 = CustomTemplate(
        id: 't1',
        bankId: 'nagari',
        template: const TemplateRule(
          name: 'Nagari QRIS Khusus',
          kind: TxKind.payment,
          direction: Direction.outgoing,
          matchAll: ['qris', 'nagari'],
        ),
      );

      await repo.saveCustomTemplate(t1);
      var templates = await repo.customTemplates();
      expect(templates, hasLength(1));
      expect(templates.single.template.name, 'Nagari QRIS Khusus');
      expect(templates.single.bankId, 'nagari');

      // Update existing
      final t1Updated = t1.copyWith(
        template: const TemplateRule(
          name: 'Nagari QRIS Update',
          kind: TxKind.payment,
          direction: Direction.outgoing,
          matchAll: ['qris', 'nagari'],
        ),
      );
      await repo.saveCustomTemplate(t1Updated);
      templates = await repo.customTemplates();
      expect(templates, hasLength(1));
      expect(templates.single.template.name, 'Nagari QRIS Update');

      // Delete
      await repo.deleteCustomTemplate('t1');
      expect(await repo.customTemplates(), isEmpty);
    });
  });

  group('preferredCategoryId & merchant memory', () {
    test('mengingat kategori terakhir berdasarkan counterparty (case-insensitive)', () async {
      final catKopi = await repo.addCategory('Kopi & Nongkrong');
      final catMakan = await repo.addCategory('Makanan & Minuman');

      // Belum ada histori → fallback ke default kind
      final initialPref = await repo.preferredCategoryId(
        counterparty: 'Kopi Kenangan',
        kind: TxKind.payment,
      );
      final defaultPaymentCat = await db.select(db.categories)
          .get()
          .then((l) => l.firstWhere((c) => c.name == 'Belanja').id);
      expect(initialPref, defaultPaymentCat);

      // Simpan transaksi pertama dengan counterparty Kopi Kenangan
      await repo.addManual(
        amount: 25000,
        direction: Direction.outgoing,
        kind: TxKind.payment,
        counterparty: 'Kopi Kenangan',
        categoryId: catKopi.id,
        occurredAt: DateTime(2026, 10, 1, 10),
      );

      // Preferred sekarang harus Kopi & Nongkrong
      final learnedPref = await repo.preferredCategoryId(
        counterparty: 'kopi kenangan', // huruf kecil
        kind: TxKind.payment,
      );
      expect(learnedPref, catKopi.id);

      // Draf baru dari notifikasi dengan counterparty sama otomatis dapat kategori tersebut
      final draftId = await repo.addDraftFromCapture(
        raw: capture(
          body: 'Pembayaran QRIS Rp28.000 ke KOPI KENANGAN berhasil',
          postedAt: DateTime(2026, 10, 11, 10),
        ),
        draft: ParsedDraft(
          bankId: 'blu',
          bankName: 'blu by BCA',
          ruleName: 'pembayaran',
          kind: TxKind.payment,
          direction: Direction.outgoing,
          amount: 28000,
          counterparty: 'KOPI KENANGAN',
        ),
      );
      expect(draftId, isNotNull);
      final savedDraft = await (db.select(db.drafts)..where((d) => d.id.equals(draftId!))).getSingle();
      expect(savedDraft.categoryId, catKopi.id);

      // Jika user mencatat transaksi baru dengan kategori berbeda, memory terupdate ke yang terbaru
      await repo.addManual(
        amount: 30000,
        direction: Direction.outgoing,
        kind: TxKind.payment,
        counterparty: 'Kopi Kenangan',
        categoryId: catMakan.id,
        occurredAt: DateTime(2026, 10, 12, 10),
      );
      final updatedPref = await repo.preferredCategoryId(
        counterparty: 'KOPI KENANGAN',
        kind: TxKind.payment,
      );
      expect(updatedPref, catMakan.id);
    });
  });

  group('Internal Transfer Pairing & Confirmation', () {
    test('partitionDrafts mendeteksi pasangan draf keluar & masuk bernominal sama', () {
      final now = DateTime(2026, 11, 1, 10, 0);
      final draftBca = Draft(
        id: 1,
        bankId: 'bca',
        kind: TxKind.transfer,
        direction: Direction.outgoing,
        amount: 150000,
        occurredAt: now,
        createdAt: now,
      );
      final draftGopay = Draft(
        id: 2,
        bankId: 'gopay',
        kind: TxKind.topup,
        direction: Direction.incoming,
        amount: 150000,
        occurredAt: now.add(const Duration(minutes: 1)),
        createdAt: now,
      );
      final draftSingle = Draft(
        id: 3,
        bankId: 'bca',
        kind: TxKind.payment,
        direction: Direction.outgoing,
        amount: 25000,
        occurredAt: now.add(const Duration(minutes: 2)),
        createdAt: now,
      );

      final result = LedgerRepository.partitionDrafts([
        draftBca,
        draftGopay,
        draftSingle,
      ]);

      expect(result.pairs, hasLength(1));
      expect(result.singles, hasLength(1));
      expect(result.pairs.first.outDraft.id, draftBca.id);
      expect(result.pairs.first.inDraft.id, draftGopay.id);
      expect(result.pairs.first.amount, 150000);
      expect(result.singles.first.id, draftSingle.id);
    });

    test('confirmTransferPair mencatat 2 transaksi transfer, hapus draf, dan tak menambah pengeluaran', () async {
      final accBca = await repo.ensureBankAccount(
        bankId: 'bca',
        name: 'BCA',
        kind: AccountKind.bank,
      );
      await repo.setOpeningBalance(accBca.id, 500000);

      final accGopay = await repo.ensureBankAccount(
        bankId: 'gopay',
        name: 'GoPay',
        kind: AccountKind.ewallet,
      );
      await repo.setOpeningBalance(accGopay.id, 50000);

      final now = DateTime(2026, 11, 1, 10, 0);
      final idOut = await repo.addDraftFromCapture(
        raw: capture(
          packageName: 'com.bca',
          title: 'm-BCA',
          body: 'Transfer berhasil ke GoPay Rp 100.000',
          postedAt: now,
        ),
        draft: ParsedDraft(
          bankId: 'bca',
          bankName: 'BCA',
          ruleName: 'm-transfer keluar',
          kind: TxKind.transfer,
          direction: Direction.outgoing,
          amount: 100000,
        ),
      );
      final idIn = await repo.addDraftFromCapture(
        raw: capture(
          packageName: 'com.gojek.app',
          title: 'GoPay',
          body: 'Top up berhasil Rp 100.000 dari BCA',
          postedAt: now.add(const Duration(minutes: 1)),
        ),
        draft: ParsedDraft(
          bankId: 'gopay',
          bankName: 'GoPay',
          ruleName: 'top up',
          kind: TxKind.topup,
          direction: Direction.incoming,
          amount: 100000,
        ),
      );

      final allDrafts = await db.select(db.drafts).get();
      final partition = LedgerRepository.partitionDrafts(allDrafts);
      expect(partition.pairs, hasLength(1));

      // Konfirmasi transfer pair
      await repo.confirmTransferPair(pair: partition.pairs.first);

      // 1. Draf harus terhapus
      expect(await db.select(db.drafts).get(), isEmpty);

      // 2. Transaksi baru harus tercatat dengan kind transfer
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(2));
      expect(txs.every((t) => t.kind == TxKind.transfer), isTrue);

      // 3. Saldo akun terupdate: BCA berkurang 100k, GoPay bertambah 100k
      final balances = await repo.watchAccountBalances().first;
      expect(balances[accBca.id], 400000);
      expect(balances[accGopay.id], 150000);

      // 4. Belanja murni tetap 0 (transfer antar akun tidak dihitung sebagai beban pengeluaran)
      final spend = await repo.outSpendPairsBetween(
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 2),
      );
      expect(spend.values.fold<int>(0, (a, b) => a + b), 0);
    });
  });
}
