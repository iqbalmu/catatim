part of '../repository.dart';

// SECTION: manual_transactions.dart
extension ManualTransactionsRepo on LedgerRepository {
  // --- transaksi manual & edit ---------------------------------------------

  Future<int> addManual({
    required int amount,
    required Direction direction,
    required TxKind kind,
    String? counterparty,
    int? categoryId,
    int? accountId,
    DateTime? occurredAt,
  }) async {
    final clean = (counterparty == null || counterparty.trim().isEmpty)
        ? null
        : counterparty.trim();
    final resolvedCategoryId =
        categoryId ??
        await preferredCategoryId(
          counterparty: clean,
          kind: kind,
          direction: direction,
        );
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
            categoryId: Value(resolvedCategoryId),
            accountId: Value(accountId),
          ),
        );
  }

  /// Tambah pasangan transfer internal manual: 1 keluar di akun asal, 1 masuk di akun tujuan.
  Future<void> addManualTransfer({
    required int fromAccountId,
    required int toAccountId,
    required int amount,
    DateTime? occurredAt,
    String? note,
  }) async {
    final at = occurredAt ?? DateTime.now();
    final transferCatId = await _defaultCategoryId(TxKind.internal);
    final allAccounts = await getAccounts();
    final fromAcc = allAccounts.where((a) => a.id == fromAccountId).firstOrNull;
    final toAcc = allAccounts.where((a) => a.id == toAccountId).firstOrNull;
    final fromLabel = fromAcc?.name ?? 'Akun #$fromAccountId';
    final toLabel = toAcc?.name ?? 'Akun #$toAccountId';
    final cleanNote = note?.trim();
    final outNote = (cleanNote != null && cleanNote.isNotEmpty)
        ? '$cleanNote (ke $toLabel)'
        : 'Transfer ke $toLabel';
    final inNote = (cleanNote != null && cleanNote.isNotEmpty)
        ? '$cleanNote (dari $fromLabel)'
        : 'Transfer dari $fromLabel';

    await _db.transaction(() async {
      await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              uuid: newUuid(),
              bankId: fromAcc?.bankId ?? 'manual',
              kind: TxKind.internal,
              direction: Direction.outgoing,
              amount: amount,
              counterparty: Value(outNote),
              occurredAt: at,
              source: TxSource.manual,
              categoryId: Value(transferCatId),
              accountId: Value(fromAccountId),
            ),
          );
      await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              uuid: newUuid(),
              bankId: toAcc?.bankId ?? 'manual',
              kind: TxKind.internal,
              direction: Direction.incoming,
              amount: amount,
              counterparty: Value(inNote),
              occurredAt: at,
              source: TxSource.manual,
              categoryId: Value(transferCatId),
              accountId: Value(toAccountId),
            ),
          );
    });
  }

  Future<void> updateTransaction(int id, TransactionsCompanion data) {
    return (_db.update(
      _db.transactions,
    )..where((t) => t.id.equals(id))).write(data);
  }

  Future<void> deleteTransaction(int id) async {
    return _db.transaction(() async {
      await (_db.update(
        _db.bons,
      )..where((b) => b.settlementTransactionId.equals(id))).write(
        const BonsCompanion(
          settledAt: Value(null),
          settlementTransactionId: Value(null),
        ),
      );
      await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
    });
  }
}
