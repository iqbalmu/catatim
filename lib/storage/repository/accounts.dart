part of '../repository.dart';

// SECTION: accounts.dart
extension AccountsRepo on LedgerRepository {
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
  /// terhapus). Audit C-1: dua langkah dijadikan satu transaksi agar
  /// FK `account_id → accounts` tidak sempat melanggar bila app mati
  /// di antara null-ing dan delete.
  Future<void> deleteAccount(int id) {
    return _db.transaction(() async {
      await (_db.update(_db.transactions)..where((t) => t.accountId.equals(id)))
          .write(const TransactionsCompanion(accountId: Value(null)));
      await (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
    });
  }
}
