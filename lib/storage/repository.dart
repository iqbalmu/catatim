import 'package:drift/drift.dart';

import '../models.dart';
import '../rules/engine.dart' show RuleEngine, UserRuleDef;
import '../rules/rule_set.dart' show BankRules;
import 'database.dart';

/// Transaksi + kategori ter-join (kategori null bila belum disetel).
class TxWithCategory {
  const TxWithCategory({required this.tx, this.category});

  final Transaction tx;
  final Category? category;
}

/// Akses data transaksi, kategori, settings, dan dedup capture.
class LedgerRepository {
  LedgerRepository(this._db);

  final AppDatabase _db;

  /// Dua notifikasi dari bank+nominal+arah yang sama dalam jendela ini
  /// dianggap duplikat (bank sering kirim ganda / push+SMS).
  static const dedupWindow = Duration(seconds: 120);

  /// Pemetaan jenis transaksi → nama kategori bawaan.
  static const _kindCategoryName = {
    TxKind.transfer: 'Transfer',
    TxKind.payment: 'Belanja',
    TxKind.topup: 'Transfer',
    TxKind.withdrawal: 'Transfer',
    TxKind.other: 'Lainnya',
  };

  // --- capture ------------------------------------------------------------

  /// Simpan transaksi hasil capture; kembalikan id baris (baru atau lama
  /// bila terdeteksi duplikat). [existingLogId] mengisi ulang baris capture
  /// log yang sudah ada (alur "parse ulang") alih-alih menambah baris baru.
  Future<int> recordFromCapture({
    required RawCapture raw,
    required ParsedDraft draft,
    int? existingLogId,
  }) async {
    final categoryId = await _defaultCategoryId(draft.kind);
    final accountId =
        draft.accountId ?? await _accountIdForBank(draft.bankId);
    final from = raw.postedAt.subtract(dedupWindow);
    final to = raw.postedAt.add(dedupWindow);
    final existing =
        await (_db.select(_db.transactions)
              ..where(
                (t) =>
                    t.bankId.equals(draft.bankId) &
                    t.amount.equals(draft.amount) &
                    t.direction.equalsValue(draft.direction) &
                    t.occurredAt.isBetweenValues(from, to),
              )
              ..limit(1))
            .getSingleOrNull();

    if (existing != null) {
      await _logCapture(
        raw,
        parsed: true,
        transactionId: existing.id,
        updateLogId: existingLogId,
      );
      return existing.id;
    }

    final id = await _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            uuid: newUuid(),
            bankId: draft.bankId,
            kind: draft.kind,
            direction: draft.direction,
            amount: draft.amount,
            counterparty: Value(draft.counterparty),
            occurredAt: raw.postedAt,
            source: TxSource.notification,
            rawBody: Value(raw.body),
            categoryId: Value(categoryId),
            accountId: Value(accountId),
          ),
        );
    await _logCapture(
      raw,
      parsed: true,
      transactionId: id,
      updateLogId: existingLogId,
    );
    return id;
  }

  /// Catat notifikasi yang tidak berhasil diparse (untuk layar Capture Log).
  Future<void> recordUnparsedCapture(RawCapture raw) =>
      _logCapture(raw, parsed: false);

  /// Notifikasi mentah yang belum berhasil diparse.
  Future<List<CaptureLog>> unparsedCaptures() async {
    return (_db.select(_db.captureLogs)
          ..where((c) => c.parsed.equals(false))
          ..orderBy([(c) => OrderingTerm.desc(c.postedAt)]))
        .get();
  }

  /// Parse ulang semua capture gagal dengan rules terkini.
  /// Mengembalikan jumlah yang berhasil dicatat.
  Future<int> reparseUnparsed(RuleEngine engine) async {
    final logs = await unparsedCaptures();
    var saved = 0;
    for (final log in logs) {
      final raw = RawCapture(
        packageName: log.packageName,
        title: log.title,
        body: log.body,
        postedAt: log.postedAt,
      );
      final draft = engine.parse(
        packageName: raw.packageName,
        title: raw.title,
        body: raw.body,
      );
      if (draft == null) continue;
      await recordFromCapture(raw: raw, draft: draft, existingLogId: log.id);
      saved++;
    }
    return saved;
  }

  // --- transaksi manual & edit ---------------------------------------------

  Future<int> addManual({
    required int amount,
    required Direction direction,
    required TxKind kind,
    String? counterparty,
    int? categoryId,
    int? accountId,
    DateTime? occurredAt,
  }) {
    final clean = (counterparty == null || counterparty.trim().isEmpty)
        ? null
        : counterparty.trim();
    return _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            uuid: newUuid(),
            bankId: 'manual',
            kind: kind,
            direction: direction,
            amount: amount,
            counterparty: Value(clean),
            occurredAt: occurredAt ?? DateTime.now(),
            source: TxSource.manual,
            categoryId: Value(categoryId),
            accountId: Value(accountId),
          ),
        );
  }

  Future<void> updateTransaction(int id, TransactionsCompanion data) {
    return (_db.update(
      _db.transactions,
    )..where((t) => t.id.equals(id))).write(data);
  }

  Future<void> deleteTransaction(int id) {
    return (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
  }

  // --- kategori -------------------------------------------------------------

  Stream<List<Category>> watchCategories() {
    return (_db.select(
      _db.categories,
    )..orderBy([(c) => OrderingTerm.asc(c.id)])).watch();
  }

  Future<List<Category>> getCategories() => _db.select(_db.categories).get();

  /// Tambah kategori; melempar bila nama sudah dipakai (unique).
  Future<Category> addCategory(String name) async {
    final all = await getCategories();
    final id = await _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(name: name.trim(), colorIndex: all.length),
        );
    return (await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(id))).getSingle());
  }

  Future<int?> _defaultCategoryId(TxKind kind) async {
    final name = _kindCategoryName[kind]!;
    final row = await (_db.select(
      _db.categories,
    )..where((c) => c.name.equals(name))).getSingleOrNull();
    return row?.id;
  }

  // --- query transaksi --------------------------------------------------------

  JoinedSelectStatement _withCategoryQuery({
    DateTime? start,
    DateTime? end,
    int? limit,
    int? accountId,
  }) {
    final query = _db.select(_db.transactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ]);
    if (start != null && end != null) {
      query.where(_db.transactions.occurredAt.isBetweenValues(start, end));
    }
    if (accountId != null) {
      query.where(_db.transactions.accountId.equals(accountId));
    }
    query.orderBy([OrderingTerm.desc(_db.transactions.occurredAt)]);
    if (limit != null) query.limit(limit);
    return query;
  }

  List<TxWithCategory> _mapRows(List<TypedResult> rows) => [
    for (final row in rows)
      TxWithCategory(
        tx: row.readTable(_db.transactions),
        category: row.readTableOrNull(_db.categories),
      ),
  ];

  Stream<List<TxWithCategory>> watchBetweenWithCategory(
    DateTime start,
    DateTime end, {
    int? accountId,
  }) => _withCategoryQuery(
    start: start,
    end: end,
    accountId: accountId,
  ).watch().map(_mapRows);

  Stream<List<TxWithCategory>> watchRecentWithCategory({
    int limit = 300,
    int? accountId,
  }) => _withCategoryQuery(
    limit: limit,
    accountId: accountId,
  ).watch().map(_mapRows);

  // --- capture log -------------------------------------------------------------

  Stream<List<CaptureLog>> watchCaptureLog({int limit = 300}) {
    return (_db.select(_db.captureLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.postedAt)])
          ..limit(limit))
        .watch();
  }

  /// Jumlah transaksi per hari lokal, sejak [since] — sumber kebenaran
  /// untuk streak di ProgressService.
  Future<Map<DateTime, int>> txCountByDaySince(DateTime since) async {
    final rows = await (_db.select(
      _db.transactions,
    )..where((t) => t.occurredAt.isBiggerOrEqualValue(since))).get();
    final map = <DateTime, int>{};
    for (final t in rows) {
      final d = DateTime(
        t.occurredAt.year,
        t.occurredAt.month,
        t.occurredAt.day,
      );
      map.update(d, (v) => v + 1, ifAbsent: () => 1);
    }
    return map;
  }

  /// Total keluar per hari lokal sejak [since] (inklusif) — bahan
  /// sparkline insight beranda. Re-emit tiap tabel transaksi berubah.
  Stream<Map<DateTime, int>> watchOutSumByDaySince(DateTime since) {
    final query = (_db.select(_db.transactions)..where((t) =>
        t.direction.equalsValue(Direction.outgoing) &
        t.occurredAt.isBiggerOrEqualValue(since)));
    return query.watch().map((rows) {
      final map = <DateTime, int>{};
      for (final t in rows) {
        final d = DateTime(
          t.occurredAt.year,
          t.occurredAt.month,
          t.occurredAt.day,
        );
        map.update(d, (v) => v + t.amount, ifAbsent: () => t.amount);
      }
      return map;
    });
  }

  // --- settings -----------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.valueText;
  }

  Future<void> setSetting(String key, String value) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, valueText: value),
        );
  }

  // --- anggaran ---------------------------------------------------------------

  Stream<List<Budget>> watchBudgets() => (_db.select(
        _db.budgets,
      )..orderBy([(b) => OrderingTerm.asc(b.id)])).watch();

  /// Set (atau timpa) alokasi bulanan satu kategori. [accountId] null =
  /// berlaku di semua akun; beda akun = baris alokasi yang berbeda.
  Future<void> setBudget(
    int categoryId,
    int monthlyLimit, {
    int? accountId,
  }) async {
    final existing = await (_db.select(
      _db.budgets,
    )..where(
        (b) =>
            b.categoryId.equals(categoryId) &
            (accountId == null
                ? b.accountId.isNull()
                : b.accountId.equals(accountId)),
      )).getSingleOrNull();
    if (existing != null) {
      await (_db.update(
        _db.budgets,
      )..where((b) => b.id.equals(existing.id))).write(
        BudgetsCompanion(monthlyLimit: Value(monthlyLimit)),
      );
    } else {
      await _db.into(_db.budgets).insert(
            BudgetsCompanion.insert(
              categoryId: categoryId,
              monthlyLimit: monthlyLimit,
              accountId: Value(accountId),
            ),
          );
    }
  }

  /// Hapus alokasi satu kategori (seluruh scope, atau akun tertentu).
  Future<void> removeBudget(int categoryId, {int? accountId}) {
    return (_db.delete(_db.budgets)..where(
        (b) =>
            b.categoryId.equals(categoryId) &
            (accountId == null
                ? b.accountId.isNull()
                : b.accountId.equals(accountId)),
      )).go();
  }

  /// Keluar bulan dikelompokkan per pasangan (kategori, akun) dalam
  /// [start, end). Kunci kategori null = tanpa kategori, dst.
  Stream<Map<({int? category, int? account}), int>> watchOutPairsBetween(
    DateTime start,
    DateTime end,
  ) {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([
        _db.transactions.categoryId,
        _db.transactions.accountId,
        amountSum,
      ])
      ..where(
        _db.transactions.direction.equalsValue(Direction.outgoing) &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      )
      ..groupBy([_db.transactions.categoryId, _db.transactions.accountId]);
    return query.watch().map(
          (rows) => {
            for (final row in rows)
              (
                category: row.read(_db.transactions.categoryId),
                account: row.read(_db.transactions.accountId),
              ):
                  row.read(amountSum) ?? 0,
          },
        );
  }

  /// Versi one-shot dari [watchOutPairsBetween].
  Future<Map<({int? category, int? account}), int>> outPairsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([
        _db.transactions.categoryId,
        _db.transactions.accountId,
        amountSum,
      ])
      ..where(
        _db.transactions.direction.equalsValue(Direction.outgoing) &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      )
      ..groupBy([_db.transactions.categoryId, _db.transactions.accountId]);
    final rows = await query.get();
    return {
      for (final row in rows)
        (
          category: row.read(_db.transactions.categoryId),
          account: row.read(_db.transactions.accountId),
        ):
            row.read(amountSum) ?? 0,
    };
  }

  /// Total (masuk atau keluar) dalam [start, end) — hidup (watch).
  Stream<int> watchSumBetween(
    DateTime start,
    DateTime end,
    Direction direction,
  ) {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([amountSum])
      ..where(
        _db.transactions.direction.equalsValue(direction) &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      );
    return query.watchSingle().map((row) => row.read(amountSum) ?? 0);
  }

  /// Versi one-shot dari [watchSumBetween] — untuk perhitungan sekali
  /// jalan (ProgressService.refresh) tanpa langganan stream.
  Future<int> sumBetween(
    DateTime start,
    DateTime end,
    Direction direction,
  ) async {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([amountSum])
      ..where(
        _db.transactions.direction.equalsValue(direction) &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      );
    final row = await query.getSingle();
    return row.read(amountSum) ?? 0;
  }

  /// Saldo berjalan tiap akun = saldo awal + masuk − keluar. Transfer/
  /// topup satu kaki sementara dihitung sebagai keluar/masuk akun asal;
  /// transfer dua kaki menyusul.
  Stream<Map<int, int>> watchAccountBalances() {
    final inSum = _db.transactions.amount.sum(
      filter: _db.transactions.direction.equalsValue(Direction.incoming),
    );
    final outSum = _db.transactions.amount.sum(
      filter: _db.transactions.direction.equalsValue(Direction.outgoing),
    );
    final query = _db.selectOnly(_db.accounts).join([
      leftOuterJoin(
        _db.transactions,
        _db.transactions.accountId.equalsExp(_db.accounts.id),
      ),
    ]);
    query.addColumns([
      _db.accounts.id,
      _db.accounts.openingBalance,
      inSum,
      outSum,
    ]);
    query.groupBy([_db.accounts.id]);
    return query.watch().map(
          (rows) => {
            for (final row in rows)
              row.read(_db.accounts.id)!:
                  _intOf(row.read(_db.accounts.openingBalance)) +
                      _intOf(row.read(inSum)) -
                      _intOf(row.read(outSum)),
          },
        );
  }

  static int _intOf(Object? value) => (value as num?)?.toInt() ?? 0;

  // --- kategori -----------------------------------------------------------------

  /// Ubah nama kategori; melempar bila nama sudah dipakai (unique).
  Future<void> renameCategory(int id, String name) {
    return (_db.update(
      _db.categories,
    )..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(name: Value(name.trim())),
    );
  }

  /// Hapus kategori: transaksinya dipindah ke kategori [fallbackId]
  /// (biasanya "Lainnya"), alokasinya ikut terhapus.
  Future<void> deleteCategory(int id, {required int fallbackId}) async {
    if (id == fallbackId) throw ArgumentError('tidak boleh hapus fallback');
    await (_db.update(
      _db.transactions,
    )..where((t) => t.categoryId.equals(id))).write(
      TransactionsCompanion(categoryId: Value(fallbackId)),
    );
    await (_db.delete(_db.budgets)..where((b) => b.categoryId.equals(id))).go();
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }

  // --- aturan pengguna ------------------------------------------------------

  Stream<List<UserRule>> watchUserRules() {
    return (_db.select(_db.userRules)
          ..orderBy([
            (r) => OrderingTerm.desc(r.enabled),
            (r) => OrderingTerm.asc(r.id),
          ]))
        .watch();
  }

  Future<List<UserRule>> getUserRules({bool? enabled}) async {
    final query = _db.select(_db.userRules);
    if (enabled != null) {
      query.where((r) => r.enabled.equals(enabled));
    }
    return query.get();
  }

  Future<int> addUserRule(UserRulesCompanion data) =>
      _db.into(_db.userRules).insert(data);

  Future<void> updateUserRule(int id, UserRulesCompanion data) {
    return (_db.update(_db.userRules)..where((r) => r.id.equals(id)))
        .write(data);
  }

  Future<void> deleteUserRule(int id) {
    return (_db.delete(_db.userRules)..where((r) => r.id.equals(id))).go();
  }

  /// Petakan baris DB → definisi untuk engine.
  Future<List<UserRuleDef>> userRuleDefs() async {
    final rows = await getUserRules(enabled: true);
    return [
      for (final r in rows)
        UserRuleDef(
          id: r.id,
          name: r.name,
          packageName: r.packageName,
          matchText: r.matchText,
          amountPattern: r.amountPattern,
          direction: r.direction.direction,
          kind: r.kind,
          accountId: r.accountId,
        ),
    ];
  }

  /// Seed aturan pengguna dari seed rules bawaan — sekali, saat tabel
  /// masih kosong.
  Future<void> seedUserRulesFromBanks(List<BankRules> banks) async {
    final existing = await _db.select(_db.userRules).get();
    if (existing.isNotEmpty) return;

    final accounts = await getAccounts();
    int? accountByName(String name) {
      for (final a in accounts) {
        if (a.name == name) return a.id;
      }
      return null;
    }

    final rows = <UserRulesCompanion>[];
    for (final bank in banks) {
      final package = bank.packageNames.isNotEmpty
          ? bank.packageNames.first
          : null;
      for (final t in bank.templates) {
        rows.add(
          UserRulesCompanion.insert(
            name: '${bank.displayName} · ${t.name}',
            packageName: Value(package),
            matchText: Value(
              t.matchAll.isNotEmpty
                  ? t.matchAll.first
                  : (t.matchAny.isNotEmpty ? t.matchAny.first : null),
            ),
            amountPattern: Value(t.amountPattern),
            direction: t.direction == Direction.incoming
                ? UserRuleDirection.in_
                : UserRuleDirection.out_,
            kind: t.kind,
            accountId: Value(
              bank.id == 'blu'
                  ? accountByName('blu by BCA')
                  : (bank.id == 'nagari'
                      ? accountByName('Bank Nagari')
                      : null),
            ),
          ),
        );
      }
    }
    if (rows.isNotEmpty) {
      await _db.batch((b) => b.insertAll(_db.userRules, rows));
    }
  }

  // --- backup -----------------------------------------------------------------

  /// Flush WAL ke file utama sebelum file DB dicopy untuk backup.
  Future<void> checkpoint() =>
      _db.customStatement('PRAGMA wal_checkpoint(FULL)');

  // --- CSV ------------------------------------------------------------------------

  Future<String> buildCsv() async {
    final rows = await _withCategoryQuery().get().then((r) => _mapRows(r));
    String esc(String s) => '"${s.replaceAll('"', '""')}"';
    final buf = StringBuffer(
      'tanggal,arah,nominal,jenis,kategori,bank,pihak,sumber\n',
    );
    for (final r in rows) {
      final t = r.tx;
      buf.write(
        '${t.occurredAt.toIso8601String()},'
        '${t.direction == Direction.incoming ? 'masuk' : 'keluar'},'
        '${t.amount},'
        '${esc(t.kind.label)},'
        '${esc(r.category?.name ?? '')},'
        '${esc(t.bankId)},'
        '${esc(t.counterparty ?? '')},'
        '${esc(t.source.label)}\n',
      );
    }
    return buf.toString();
  }

  // --- akun ------------------------------------------------------------------

  Stream<List<Account>> watchAccounts() {
    return (_db.select(
      _db.accounts,
    )..orderBy([(a) => OrderingTerm.asc(a.id)])).watch();
  }

  Future<List<Account>> getAccounts() => _db.select(_db.accounts).get();

  /// Tambah akun; melempar bila nama sudah dipakai (unique).
  Future<Account> addAccount(String name, AccountKind kind) async {
    final all = await getAccounts();
    final id = await _db
        .into(_db.accounts)
        .insert(
          AccountsCompanion.insert(
            name: name.trim(),
            kind: kind,
            colorIndex: all.length,
          ),
        );
    return (await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(id))).getSingle());
  }

  /// Petakan bankId hasil parser ke akun bawaan (blu/nagari).
  Future<int?> _accountIdForBank(String bankId) async {
    const names = {'blu': 'blu by BCA', 'nagari': 'Bank Nagari'};
    final name = names[bankId];
    if (name == null) return null;
    final row = await (_db.select(
      _db.accounts,
    )..where((a) => a.name.equals(name))).getSingleOrNull();
    return row?.id;
  }

  // --- bon -------------------------------------------------------------------

  /// Semua bon, yang belum lunas dulu (NULL settledAt diurut pertama).
  Stream<List<Bon>> watchBons() {
    return (_db.select(_db.bons)..orderBy([
          (b) => OrderingTerm.asc(b.settledAt),
          (b) => OrderingTerm.desc(b.occurredAt),
        ]))
        .watch();
  }

  Future<int> addBon({
    required String person,
    required int amount,
    required BonDirection direction,
    String? note,
    DateTime? occurredAt,
  }) {
    final cleanNote = (note == null || note.trim().isEmpty)
        ? null
        : note.trim();
    return _db
        .into(_db.bons)
        .insert(
          BonsCompanion.insert(
            uuid: newUuid(),
            person: person.trim(),
            amount: amount,
            direction: direction,
            note: Value(cleanNote),
            occurredAt: occurredAt ?? DateTime.now(),
          ),
        );
  }

  Future<void> updateBon(int id, BonsCompanion data) {
    return (_db.update(_db.bons)..where((b) => b.id.equals(id))).write(data);
  }

  Future<void> deleteBon(int id) {
    return (_db.delete(_db.bons)..where((b) => b.id.equals(id))).go();
  }

  /// Ubah nama akun; melempar bila nama sudah dipakai (unique).
  Future<void> updateAccount(int id, String name) {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(name: Value(name.trim())),
    );
  }

  /// Set saldo awal akun — dasar perhitungan saldo berjalan.
  Future<void> setOpeningBalance(int id, int amount) {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(openingBalance: Value(amount)),
    );
  }

  /// Hapus akun; transaksi yang memakainya jadi tanpa akun (tidak ikut
  /// terhapus).
  Future<void> deleteAccount(int id) async {
    await (_db.update(_db.transactions)..where((t) => t.accountId.equals(id)))
        .write(const TransactionsCompanion(accountId: Value(null)));
    await (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
  }

  Future<void> _logCapture(
    RawCapture raw, {
    required bool parsed,
    int? transactionId,
    int? updateLogId,
  }) async {
    if (updateLogId != null) {
      await (_db.update(
        _db.captureLogs,
      )..where((c) => c.id.equals(updateLogId))).write(
        CaptureLogsCompanion(
          parsed: Value(parsed),
          transactionId: Value(transactionId),
        ),
      );
      return;
    }
    await _db
        .into(_db.captureLogs)
        .insert(
          CaptureLogsCompanion.insert(
            packageName: raw.packageName,
            title: raw.title,
            body: raw.body,
            postedAt: raw.postedAt,
            parsed: parsed,
            transactionId: Value(transactionId),
          ),
        );
  }
}
