part of '../repository.dart';

// SECTION: bons.dart
extension BonsRepo on LedgerRepository {
  // --- bon -------------------------------------------------------------------

  /// Semua bon, yang belum lunas dulu (NULL settledAt diurut pertama).
  Stream<List<Bon>> watchBons() {
    return (_db.select(_db.bons)..orderBy([
          (b) => OrderingTerm.asc(b.settledAt),
          (b) => OrderingTerm.desc(b.occurredAt),
        ]))
        .watch();
  }

  Future<List<Bon>> getBons() {
    return (_db.select(_db.bons)..orderBy([
          (b) => OrderingTerm.asc(b.settledAt),
          (b) => OrderingTerm.desc(b.occurredAt),
        ]))
        .get();
  }

  Future<int> addBon({
    required String person,
    int amount = 0,
    required BonDirection direction,
    String? note,
    DateTime? occurredAt,
    int? categoryId,
    int? accountId,
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
            amount: Value(amount),
            direction: direction,
            note: Value(cleanNote),
            occurredAt: occurredAt ?? DateTime.now(),
            categoryId: Value(categoryId),
            accountId: Value(accountId),
          ),
        );
  }

  Future<void> updateBon(int id, BonsCompanion data) {
    return (_db.update(_db.bons)..where((b) => b.id.equals(id))).write(data);
  }

  /// Lunasi bon: buat transaksi kas riil di akun dan kategori yang dipilih,
  /// lalu tandai bon lunas dengan mereferensikan transaksi tersebut.
  Future<int> settleBon({
    required int bonId,
    required int amount,
    required int accountId,
    required int categoryId,
    DateTime? settledAt,
  }) async {
    return _db.transaction(() async {
      final bon = await (_db.select(
        _db.bons,
      )..where((b) => b.id.equals(bonId))).getSingle();
      final date = settledAt ?? DateTime.now();
      final isLent = bon.direction == BonDirection.lent;

      final txId = await addManual(
        amount: amount,
        direction: isLent ? Direction.incoming : Direction.outgoing,
        kind: TxKind.payment,
        counterparty: isLent
            ? 'Pelunasan piutang: ${bon.person}'
            : 'Pelunasan bon: ${bon.person}',
        accountId: accountId,
        categoryId: categoryId,
        occurredAt: date,
      );

      await updateBon(
        bonId,
        BonsCompanion(
          amount: Value(amount),
          accountId: Value(accountId),
          categoryId: Value(categoryId),
          settledAt: Value(date),
          settlementTransactionId: Value(txId),
        ),
      );

      return txId;
    });
  }

  /// Batal lunas: putuskan tautan dan hapus transaksi pelunasan yang tercipta.
  Future<void> unsettleBon(int bonId) async {
    return _db.transaction(() async {
      final bon = await (_db.select(
        _db.bons,
      )..where((b) => b.id.equals(bonId))).getSingle();
      final txId = bon.settlementTransactionId;
      await updateBon(
        bonId,
        const BonsCompanion(
          settledAt: Value(null),
          settlementTransactionId: Value(null),
        ),
      );
      if (txId != null) {
        await (_db.delete(
          _db.transactions,
        )..where((t) => t.id.equals(txId))).go();
      }
    });
  }

  /// Hapus bon. Jika bon sudah lunas dan deleteLinkedTx == true, transaksi pelunasan
  /// ikut dihapus; jika false (default), transaksi pelunasan tetap dipertahankan.
  Future<void> deleteBon(int id, {bool deleteLinkedTx = false}) async {
    return _db.transaction(() async {
      final bon = await (_db.select(
        _db.bons,
      )..where((b) => b.id.equals(id))).getSingleOrNull();
      final txId = bon?.settlementTransactionId;
      await (_db.delete(_db.bons)..where((b) => b.id.equals(id))).go();
      if (txId != null && deleteLinkedTx) {
        await (_db.delete(
          _db.transactions,
        )..where((t) => t.id.equals(txId))).go();
      }
    });
  }

}
