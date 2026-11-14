part of '../repository.dart';

// SECTION: categories.dart
extension CategoriesRepo on LedgerRepository {
  Stream<List<Category>> watchCategories() {
    return (_db.select(_db.categories)
          ..orderBy([(c) => OrderingTerm.asc(c.id)]))
        .watch()
        .map((cats) => [...cats]..sort(LedgerRepository.categoryDisplayOrder));
  }

  Future<List<Category>> getCategories() async {
    final cats = await _db.select(_db.categories).get();
    return [...cats]..sort(LedgerRepository.categoryDisplayOrder);
  }

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
    final name = LedgerRepository._kindCategoryName[kind]!;
    final row = await (_db.select(
      _db.categories,
    )..where((c) => c.name.equals(name))).getSingleOrNull();
    return row?.id;
  }

  /// Kategori yang disukai/terakhir dipilih untuk [counterparty] tertentu.
  /// Bila belum ada riwayat transaksi dengan pihak ini, gunakan default dari [kind].
  Future<int?> preferredCategoryId({String? counterparty, TxKind? kind}) async {
    final clean = counterparty?.trim();
    if (clean != null && clean.isNotEmpty) {
      final cleanLower = clean.toLowerCase();
      final lastTx =
          await (_db.select(_db.transactions)
                ..where(
                  (t) =>
                      t.counterparty.isNotNull() &
                      t.categoryId.isNotNull() &
                      t.counterparty.lower().equals(cleanLower),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
                ..limit(1))
              .getSingleOrNull();
      if (lastTx?.categoryId != null) {
        return lastTx!.categoryId;
      }
    }
    if (kind != null) {
      return _defaultCategoryId(kind);
    }
    return null;
  }

  // --- kategori -----------------------------------------------------------------

  /// Ubah nama kategori; melempar bila nama sudah dipakai (unique).
  Future<void> renameCategory(int id, String name) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(name: Value(name.trim())),
    );
  }

  /// Hapus kategori: transaksinya dipindah ke kategori [fallbackId]
  /// (biasanya "Lainnya"), alokasinya ikut terhapus, dan filter kategori
  /// pada scope batas ikut dibersihkan.
  ///
  /// Audit C-1: keempat langkah harus atomik — crash di tengah jalan
  /// (mis. transaksi sudah pindah tapi kategori masih ada) meninggalkan
  /// data konsisten-parsial.
  Future<void> deleteCategory(int id, {required int fallbackId}) {
    if (id == fallbackId) throw ArgumentError('tidak boleh hapus fallback');
    return _db.transaction(() async {
      await (_db.update(_db.transactions)
            ..where((t) => t.categoryId.equals(id)))
          .write(TransactionsCompanion(categoryId: Value(fallbackId)));
      await (_db.delete(
        _db.budgets,
      )..where((b) => b.categoryId.equals(id))).go();
      await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
      await _removeCategoryFromLimitScopes(id);
    });
  }
}
