part of '../repository.dart';

// SECTION: budgets.dart
extension BudgetsRepo on LedgerRepository {
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

  // --- filter kategori per scope batas ---------------------------------------

  /// Filter kategori satu scope batas. null = semua kategori (belum ada
  /// filter tersimpan).
  Future<Set<int>?> getLimitCategories(String key) async =>
      parseLimitCategories(await getSetting(key));

  /// Simpan filter kategori scope batas. null atau set kosong = semua
  /// kategori (filter dihapus, kembali ke perilaku bawaan).
  Future<void> setLimitCategories(String key, Set<int>? categories) async {
    if (categories == null || categories.isEmpty) {
      await setSetting(key, '');
      return;
    }
    await setSetting(key, encodeLimitCategories(categories));
  }

  /// Stream filter kategori scope batas — null = semua kategori.
  Stream<Set<int>?> watchLimitCategories(String key) {
    return (_db.select(_db.appSettings)..where((s) => s.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => parseLimitCategories(row?.valueText));
  }

  /// Buang id kategori yang dihapus dari filter seluruh scope batas.
  /// Filter yang jadi kosong dikembalikan ke "semua kategori" — batas
  /// yang tidak menghitung apa pun lebih membingungkan daripada default.
  Future<void> _removeCategoryFromLimitScopes(int categoryId) async {
    for (final scope in LimitScope.values) {
      final ids = await getLimitCategories(scope.categoriesKey);
      if (ids == null || !ids.contains(categoryId)) continue;
      final kept = ids.where((id) => id != categoryId).toSet();
      await setLimitCategories(scope.categoriesKey, kept.isEmpty ? null : kept);
    }
  }
}
