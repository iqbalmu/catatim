import 'package:drift/drift.dart';

import '../models.dart';
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
    final from = raw.postedAt.subtract(dedupWindow);
    final to = raw.postedAt.add(dedupWindow);
    final existing = await (_db.select(_db.transactions)
          ..where((t) =>
              t.bankId.equals(draft.bankId) &
              t.amount.equals(draft.amount) &
              t.direction.equalsValue(draft.direction) &
              t.occurredAt.isBetweenValues(from, to))
          ..limit(1))
        .getSingleOrNull();

    if (existing != null) {
      await _logCapture(raw,
          parsed: true, transactionId: existing.id, updateLogId: existingLogId);
      return existing.id;
    }

    final id = await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            uuid: newUuid(),
            bankId: draft.bankId,
            kind: draft.kind,
            direction: draft.direction,
            amount: draft.amount,
            counterparty: Value(draft.counterparty),
            occurredAt: raw.postedAt,
            source: TxSource.notification,
            rawTitle: Value(raw.title),
            rawBody: Value(raw.body),
            categoryId: Value(categoryId),
          ),
        );
    await _logCapture(raw,
        parsed: true, transactionId: id, updateLogId: existingLogId);
    return id;
  }

  /// Catat notifikasi yang tidak berhasil diparse (untuk layar Capture Log).
  Future<void> recordUnparsedCapture(RawCapture raw) =>
      _logCapture(raw, parsed: false);

  // --- transaksi manual & edit ---------------------------------------------

  Future<int> addManual({
    required int amount,
    required Direction direction,
    required TxKind kind,
    String? counterparty,
    int? categoryId,
    DateTime? occurredAt,
  }) {
    final clean = (counterparty == null || counterparty.trim().isEmpty)
        ? null
        : counterparty.trim();
    return _db.into(_db.transactions).insert(
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
          ),
        );
  }

  Future<void> updateTransaction(int id, TransactionsCompanion data) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id)))
        .write(data);
  }

  Future<void> deleteTransaction(int id) {
    return (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
  }

  // --- kategori -------------------------------------------------------------

  Stream<List<Category>> watchCategories() {
    return (_db.select(_db.categories)
          ..orderBy([(c) => OrderingTerm.asc(c.id)]))
        .watch();
  }

  Future<List<Category>> getCategories() => _db.select(_db.categories).get();

  /// Tambah kategori; melempar bila nama sudah dipakai (unique).
  Future<Category> addCategory(String name) async {
    final all = await getCategories();
    final id = await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            name: name.trim(),
            colorIndex: all.length,
          ),
        );
    return (await (_db.select(_db.categories)
              ..where((c) => c.id.equals(id)))
            .getSingle());
  }

  Future<int?> _defaultCategoryId(TxKind kind) async {
    final name = _kindCategoryName[kind]!;
    final row = await (_db.select(_db.categories)
          ..where((c) => c.name.equals(name)))
        .getSingleOrNull();
    return row?.id;
  }

  // --- query transaksi --------------------------------------------------------

  JoinedSelectStatement _withCategoryQuery({
    DateTime? start,
    DateTime? end,
    int? limit,
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
          DateTime start, DateTime end) =>
      _withCategoryQuery(start: start, end: end).watch().map(_mapRows);

  Stream<List<TxWithCategory>> watchRecentWithCategory({int limit = 300}) =>
      _withCategoryQuery(limit: limit).watch().map(_mapRows);

  @Deprecated('Gunakan watchRecentWithCategory')
  Stream<List<Transaction>> watchRecent({int limit = 300}) {
    return (_db.select(_db.transactions)
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
          ..limit(limit))
        .watch();
  }

  // --- capture log -------------------------------------------------------------

  Stream<List<CaptureLog>> watchCaptureLog({int limit = 300}) {
    return (_db.select(_db.captureLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.postedAt)])
          ..limit(limit))
        .watch();
  }

  // --- settings -----------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final row = await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.valueText;
  }

  Future<void> setSetting(String key, String value) {
    return _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, valueText: value),
        );
  }

  // --- backup -----------------------------------------------------------------

  /// Flush WAL ke file utama sebelum file DB dicopy untuk backup.
  Future<void> checkpoint() =>
      _db.customStatement('PRAGMA wal_checkpoint(FULL)');

  // --- CSV ------------------------------------------------------------------------

  Future<String> buildCsv() async {
    final rows =
        await _withCategoryQuery().get().then((r) => _mapRows(r));
    String esc(String s) => '"${s.replaceAll('"', '""')}"';
    final buf = StringBuffer(
        'tanggal,arah,nominal,jenis,kategori,bank,pihak,sumber\n');
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

  // --- internal ---------------------------------------------------------------------

  Future<void> _logCapture(
    RawCapture raw, {
    required bool parsed,
    int? transactionId,
    int? updateLogId,
  }) async {
    if (updateLogId != null) {
      await (_db.update(_db.captureLogs)..where((c) => c.id.equals(updateLogId)))
          .write(
        CaptureLogsCompanion(
          parsed: Value(parsed),
          transactionId: Value(transactionId),
        ),
      );
      return;
    }
    await _db.into(_db.captureLogs).insert(
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
