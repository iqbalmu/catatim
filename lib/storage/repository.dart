import 'package:drift/drift.dart';

import '../models.dart';
import '../rules/engine.dart' show RuleEngine;
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

  /// Catat notifikasi yang tidak berhasil diparse (untuk Diagnostik).
  ///
  /// Log mentah yang identik (paket+judul+isi dalam jendela dedup) hanya
  /// dicatat sekali — melindungi dari pemrosesan ganda drain+stream.
  Future<void> recordUnparsedCapture(RawCapture raw) {
    return _db.transaction(() async {
      await _logCaptureOnce(raw, parsed: false);
    });
  }

  /// Notifikasi mentah yang belum berhasil diparse.
  Future<List<CaptureLog>> unparsedCaptures() async {
    return (_db.select(_db.captureLogs)
          ..where((c) => c.parsed.equals(false))
          ..orderBy([(c) => OrderingTerm.desc(c.postedAt)]))
        .get();
  }

  /// Notifikasi dikenali namun digugurkan dedup (duplikat) — bisa
  /// ditindaklanjuti manual atau dihapus dari Diagnostik.
  Stream<List<CaptureLog>> watchIgnoredDuplicates({int limit = 20}) {
    return (_db.select(_db.captureLogs)
          ..where((c) => c.ignoredDup.equals(true))
          ..orderBy([(c) => OrderingTerm.desc(c.postedAt)])
          ..limit(limit))
        .watch();
  }

  /// Hapus satu baris log notifikasi.
  Future<void> deleteCaptureLog(int id) {
    return (_db.delete(_db.captureLogs)..where((c) => c.id.equals(id))).go();
  }

  /// Bersihkan log yang tak lagi relevan: sudah terbaca atau duplikat
  /// yang lebih tua dari 30 hari. Mengembalikan jumlah baris terhapus.
  Future<int> pruneCaptureLogs() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return (_db.delete(_db.captureLogs)..where(
          (c) =>
              (c.parsed.equals(true) | c.ignoredDup.equals(true)) &
              c.postedAt.isSmallerThanValue(cutoff),
        ))
        .go();
  }

  /// Parse ulang semua capture gagal dengan rules terkini, berbatas bank
  /// [connectedBankIds]. Yang berhasil menjadi DRAF (bukan transaksi).
  /// Mengembalikan jumlah draf yang dibuat.
  Future<int> reparseUnparsed(
    RuleEngine engine, {
    required Set<String> connectedBankIds,
  }) {
    return reparseWith(
      (raw) => engine.parse(
        packageName: raw.packageName,
        title: raw.title,
        body: raw.body,
      ),
      connectedBankIds: connectedBankIds,
    );
  }

  /// Inti [reparseUnparsed] yang dapat diuji tanpa engine sungguhan.
  Future<int> reparseWith(
    ParsedDraft? Function(RawCapture raw) parse, {
    required Set<String> connectedBankIds,
  }) async {
    final logs = await unparsedCaptures();
    var created = 0;
    for (final log in logs) {
      final raw = RawCapture(
        packageName: log.packageName,
        title: log.title,
        body: log.body,
        postedAt: log.postedAt,
      );
      final draft = parse(raw);
      if (draft == null || !connectedBankIds.contains(draft.bankId)) continue;
      final id = await addDraftFromCapture(raw: raw, draft: draft);
      // Dikenali → tandai terbaca; duplikat yang digugurkan sudah
      // tercatat sebagai baris ignored_dup, tak perlu dicoba ulang.
      await (_db.update(_db.captureLogs)..where((c) => c.id.equals(log.id)))
          .write(const CaptureLogsCompanion(parsed: Value(true)));
      if (id != null) created++;
    }
    return created;
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

  // --- draf (model hubungkan bank) ------------------------------------------------

  /// Simpan hasil capture sebagai DRAF menunggu keputusan user.
  /// Mengembalikan id draf baru, atau null bila dianggap duplikat
  /// (sudah ada draf / transaksi se-bank+nominal+arah dalam jendela).
  Future<int?> addDraftFromCapture({
    required RawCapture raw,
    required ParsedDraft draft,
  }) {
    return _db.transaction(() async {
      final from = raw.postedAt.subtract(dedupWindow);
      final to = raw.postedAt.add(dedupWindow);
      final dupTx =
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
      if (dupTx != null) {
        await _logCaptureOnce(raw, parsed: true, ignoredDup: true);
        return null;
      }
      final dupDraft =
          await (_db.select(_db.drafts)
                ..where(
                  (d) =>
                      d.bankId.equals(draft.bankId) &
                      d.amount.equals(draft.amount) &
                      d.direction.equalsValue(draft.direction) &
                      d.occurredAt.isBetweenValues(from, to),
                )
                ..limit(1))
              .getSingleOrNull();
      if (dupDraft != null) {
        await _logCaptureOnce(raw, parsed: true, ignoredDup: true);
        return null;
      }

      return _db
          .into(_db.drafts)
          .insert(
            DraftsCompanion.insert(
              bankId: draft.bankId,
              kind: draft.kind,
              direction: draft.direction,
              amount: draft.amount,
              counterparty: Value(draft.counterparty),
              occurredAt: raw.postedAt,
              rawTitle: Value(raw.title),
              rawBody: Value(raw.body),
              categoryId: Value(await _defaultCategoryId(draft.kind)),
              accountId: Value(await _accountIdForBank(draft.bankId)),
            ),
          );
    });
  }

  /// Draf menunggu keputusan, terbaru dulu — hidup (watch).
  Stream<List<Draft>> watchDrafts() {
    return (_db.select(
      _db.drafts,
    )..orderBy([(d) => OrderingTerm.desc(d.occurredAt)])).watch();
  }

  /// Konfirmasi draf → transaksi source notifikasi; draf terhapus.
  /// Field boleh dikoreksi user dulu; yang tak disebut mengikuti draf.
  Future<int> confirmDraft(
    Draft draft, {
    required int amount,
    required Direction direction,
    required TxKind kind,
    String? counterparty,
    int? categoryId,
    int? accountId,
    DateTime? occurredAt,
  }) {
    return _db.transaction(() async {
      final clean = (counterparty == null || counterparty.trim().isEmpty)
          ? null
          : counterparty.trim();
      final id = await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              uuid: newUuid(),
              bankId: draft.bankId,
              kind: kind,
              direction: direction,
              amount: amount,
              counterparty: Value(clean ?? draft.counterparty),
              occurredAt: occurredAt ?? draft.occurredAt,
              source: TxSource.notification,
              rawTitle: Value(draft.rawTitle),
              rawBody: Value(draft.rawBody),
              categoryId: Value(
                categoryId ??
                    draft.categoryId ??
                    await _defaultCategoryId(kind),
              ),
              accountId: Value(accountId ?? draft.accountId),
            ),
          );
      await (_db.delete(_db.drafts)..where((d) => d.id.equals(draft.id))).go();
      return id;
    });
  }

  /// Buang draf tanpa mencatat apa pun.
  Future<void> discardDraft(int id) {
    return (_db.delete(_db.drafts)..where((d) => d.id.equals(id))).go();
  }

  // --- koneksi bank (model hubungkan bank) ----------------------------------------

  /// Kunci settings penyimpan daftar bankId terhubung (CSV).
  static const connectedBanksKey = 'connected_banks';

  /// ID bank/e-wallet katalog (seed_rules) yang sedang terhubung.
  Future<Set<String>> connectedBankIds() async {
    final raw = await getSetting(connectedBanksKey);
    if (raw == null || raw.trim().isEmpty) return {};
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  /// Versi hidup dari [connectedBankIds].
  Stream<Set<String>> watchConnectedBanks() {
    return (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(connectedBanksKey)))
        .watchSingleOrNull()
        .map((row) {
          final raw = row?.valueText;
          if (raw == null || raw.trim().isEmpty) return {};
          return raw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toSet();
        });
  }

  /// Hubungkan / putuskan satu bank. Urutan koneksi dipertahankan.
  Future<void> setBankConnected(String bankId, bool connected) async {
    final current = (await connectedBankIds()).toList();
    if (connected && !current.contains(bankId)) {
      current.add(bankId);
    } else if (!connected) {
      current.remove(bankId);
    }
    await setSetting(connectedBanksKey, current.join(','));
  }

  /// Akun milik bank [bankId]: cari yang tertaut, adopsi dari nama bila ada
  /// (DB lama), atau buat baru. Tak pernah duplikat per bankId.
  Future<Account> ensureBankAccount({
    required String bankId,
    required String name,
    required AccountKind kind,
  }) async {
    final linked = await (_db.select(
      _db.accounts,
    )..where((a) => a.bankId.equals(bankId))).getSingleOrNull();
    if (linked != null) return linked;
    final sameName = await (_db.select(
      _db.accounts,
    )..where((a) => a.name.equals(name))).getSingleOrNull();
    if (sameName != null) {
      await (_db.update(_db.accounts)..where((a) => a.id.equals(sameName.id)))
          .write(AccountsCompanion(bankId: Value(bankId)));
      return sameName.copyWith(bankId: Value(bankId));
    }
    final all = await getAccounts();
    final id = await _db
        .into(_db.accounts)
        .insert(
          AccountsCompanion.insert(
            name: name.trim(),
            kind: kind,
            colorIndex: all.length,
            bankId: Value(bankId),
          ),
        );
    return (await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(id))).getSingle());
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
      // Periode [start, end) — ujung atas eksklusif (audit B-02);
      // transaksi tepat 00:00 bulan berikutnya milik bulan itu sendiri.
      query.where(
        _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      );
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
    final query = (_db.select(_db.transactions)
      ..where(
        (t) =>
            t.direction.equalsValue(Direction.outgoing) &
            t.occurredAt.isBiggerOrEqualValue(since),
      ));
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

  /// Total belanja MURNI per hari lokal sejak [since] (inklusif) —
  /// kunci tengah-malam lokal seperti [txCountByDaySince]. Transfer
  /// tidak ikut.
  Future<Map<DateTime, int>> outSpendByDaySince(DateTime since) async {
    final rows =
        await (_db.select(_db.transactions)..where(
              (t) =>
                  t.direction.equalsValue(Direction.outgoing) &
                  t.kind.equalsValue(TxKind.transfer).not() &
                  t.occurredAt.isBiggerOrEqualValue(since),
            ))
            .get();
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
    final existing =
        await (_db.select(_db.budgets)..where(
              (b) =>
                  b.categoryId.equals(categoryId) &
                  (accountId == null
                      ? b.accountId.isNull()
                      : b.accountId.equals(accountId)),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.budgets)..where((b) => b.id.equals(existing.id)))
          .write(BudgetsCompanion(monthlyLimit: Value(monthlyLimit)));
    } else {
      await _db
          .into(_db.budgets)
          .insert(
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
        ))
        .go();
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
          ): row.read(amountSum) ?? 0,
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
        ): row.read(amountSum) ?? 0,
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

  /// Total keluar MURNI dalam [start, end): outgoing TANPA kind
  /// transfer (transfer dikecualikan).
  Future<int> sumSpendBetween(DateTime start, DateTime end) async {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([amountSum])
      ..where(
        _db.transactions.direction.equalsValue(Direction.outgoing) &
            _db.transactions.kind.equalsValue(TxKind.transfer).not() &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      );
    final row = await query.getSingle();
    return row.read(amountSum) ?? 0;
  }

  /// Versi belanja-murni dari [outPairsBetween]: kind transfer
  /// dikecualikan (alokasi spend-murni, Plan 04).
  Future<Map<({int? category, int? account}), int>> outSpendPairsBetween(
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
            _db.transactions.kind.equalsValue(TxKind.transfer).not() &
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
        ): row.read(amountSum) ?? 0,
    };
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
    return (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(name: Value(name.trim())),
    );
  }

  /// Hapus kategori: transaksinya dipindah ke kategori [fallbackId]
  /// (biasanya "Lainnya"), alokasinya ikut terhapus.
  Future<void> deleteCategory(int id, {required int fallbackId}) async {
    if (id == fallbackId) throw ArgumentError('tidak boleh hapus fallback');
    await (_db.update(_db.transactions)..where((t) => t.categoryId.equals(id)))
        .write(TransactionsCompanion(categoryId: Value(fallbackId)));
    await (_db.delete(_db.budgets)..where((b) => b.categoryId.equals(id))).go();
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }

  // --- backup -----------------------------------------------------------------

  /// Flush WAL ke file utama sebelum file DB dicopy untuk backup.
  Future<void> checkpoint() =>
      _db.customStatement('PRAGMA wal_checkpoint(FULL)');

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

  /// Petakan bankId hasil parser ke akun yang tertaut (lahir dari
  /// koneksi / di-backfill migrasi). Null bila bank belum terhubung.
  Future<int?> _accountIdForBank(String bankId) async {
    final row = await (_db.select(
      _db.accounts,
    )..where((a) => a.bankId.equals(bankId))).getSingleOrNull();
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

  /// Tulis log mentah sekali — konten identik (paket+judul+isi) dalam
  /// jendela dedup tidak ditulis dua kali, melindungi dari pemrosesan
  /// ganda drain+stream. [ignoredDup] memisahkan jenis penanda.
  Future<void> _logCaptureOnce(
    RawCapture raw, {
    required bool parsed,
    bool ignoredDup = false,
  }) async {
    final from = raw.postedAt.subtract(dedupWindow);
    final to = raw.postedAt.add(dedupWindow);
    final dup =
        await (_db.select(_db.captureLogs)
              ..where(
                (c) =>
                    c.ignoredDup.equals(ignoredDup) &
                    c.packageName.equals(raw.packageName) &
                    c.title.equals(raw.title) &
                    c.body.equals(raw.body) &
                    c.postedAt.isBetweenValues(from, to),
              )
              ..limit(1))
            .getSingleOrNull();
    if (dup != null) return;
    await _db
        .into(_db.captureLogs)
        .insert(
          CaptureLogsCompanion.insert(
            packageName: raw.packageName,
            title: raw.title,
            body: raw.body,
            postedAt: raw.postedAt,
            parsed: parsed,
            ignoredDup: Value(ignoredDup),
          ),
        );
  }
}
