import 'dart:math';

import 'package:drift/drift.dart';

import '../models.dart';
import 'database.dart';

/// Akses data transaksi + dedup capture.
class LedgerRepository {
  LedgerRepository(this._db);

  final AppDatabase _db;

  /// Dua notifikasi dari bank+nominal+arah yang sama dalam jendela ini
  /// dianggap duplikat (bank sering kirim ganda / push+SMS).
  static const dedupWindow = Duration(seconds: 120);

  /// Simpan transaksi hasil capture; kembalikan id baris (baru atau lama
  /// bila terdeteksi duplikat).
  Future<int> recordFromCapture({
    required RawCapture raw,
    required ParsedDraft draft,
  }) async {
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
      await _logCapture(raw, parsed: true, transactionId: existing.id);
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
          ),
        );
    await _logCapture(raw, parsed: true, transactionId: id);
    return id;
  }

  /// Catat notifikasi yang tidak berhasil diparse (untuk layar Capture Log).
  Future<void> recordUnparsedCapture(RawCapture raw) =>
      _logCapture(raw, parsed: false);

  Future<int> addManual({
    required int amount,
    required Direction direction,
    required TxKind kind,
    String? counterparty,
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
            occurredAt: DateTime.now(),
            source: TxSource.manual,
          ),
        );
  }

  Stream<List<Transaction>> watchBetween(DateTime start, DateTime end) {
    return (_db.select(_db.transactions)
          ..where((t) => t.occurredAt.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
        .watch();
  }

  Stream<List<Transaction>> watchRecent({int limit = 300}) {
    return (_db.select(_db.transactions)
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
          ..limit(limit))
        .watch();
  }

  Stream<List<CaptureLog>> watchCaptureLog({int limit = 300}) {
    return (_db.select(_db.captureLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.postedAt)])
          ..limit(limit))
        .watch();
  }

  Future<void> _logCapture(
    RawCapture raw, {
    required bool parsed,
    int? transactionId,
  }) async {
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

String newId() {
  final random = Random.secure();
  return List.generate(8, (_) => random.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}
