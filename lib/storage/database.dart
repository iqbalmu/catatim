import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../models.dart';

part 'database.g.dart';

/// Kategori pengeluaran/pemasukan, dapat diatur user.
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get colorIndex => integer()();
}

/// Key-value kecil (mis. mode pelajaran capture).
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get valueText => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Dompet/akun: bank, e-wallet, atau tunai.
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get kind => textEnum<AccountKind>()();
  IntColumn get colorIndex => integer()();

  /// Saldo awal saat akun didaftarkan — dasar perhitungan saldo berjalan.
  IntColumn get openingBalance => integer().withDefault(const Constant(0))();

  /// ID bank/e-wallet di katalog (seed_rules) bila akun lahir dari koneksi;
  /// null = akun manual (mis. Tunai).
  TextColumn get bankId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Semua transaksi tercatat (hasil capture notifikasi maupun manual).
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  TextColumn get bankId => text()();
  TextColumn get kind => textEnum<TxKind>()();
  TextColumn get direction => textEnum<Direction>()();
  IntColumn get amount => integer()(); // rupiah, selalu positif
  TextColumn get counterparty => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get source => textEnum<TxSource>()();
  TextColumn get rawTitle => text().nullable()();
  TextColumn get rawBody => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
}

/// Draf transaksi hasil notifikasi bank terhubung — menunggu keputusan
/// user: dicatat (jadi transaksi) atau dibuang. Tak pernah masuk
/// saldo/laporan sebelum dikonfirmasi.
class Drafts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bankId => text()();
  TextColumn get kind => textEnum<TxKind>()();
  TextColumn get direction => textEnum<Direction>()();
  IntColumn get amount => integer()(); // rupiah, selalu positif
  TextColumn get counterparty => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get rawTitle => text().nullable()();
  TextColumn get rawBody => text().nullable()();
  IntColumn get categoryId => integer().nullable()();
  IntColumn get accountId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Alokasi dana bulanan per kategori (rupiah). Opsional di-scope ke satu
/// akun (mis. "Makanan @ e-wallet"); null = berlaku di semua akun.
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  IntColumn get monthlyLimit => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {categoryId, accountId},
  ];
}

/// Bon pribadi: utang-piutang dengan seseorang.
class Bons extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get person => text()();
  IntColumn get amount => integer().withDefault(const Constant(0))();
  TextColumn get direction => textEnum<BonDirection>()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get settledAt => dateTime().nullable()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  IntColumn get settlementTransactionId =>
      integer().nullable().references(Transactions, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Log notifikasi mentah untuk audit & penyetelan template parser.
class CaptureLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get packageName => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  DateTimeColumn get postedAt => dateTime()();
  BoolColumn get parsed => boolean()();
  IntColumn get transactionId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Notifikasi dikenali tapi digugurkan dedup (±120s) — disimpan agar
  /// keputusan mengabaikannya tetap terlihat dan bisa ditindaklanjuti.
  BoolColumn get ignoredDup => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(
  tables: [
    Transactions,
    Drafts,
    CaptureLogs,
    Categories,
    AppSettings,
    Accounts,
    Budgets,
    Bons,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(categories);
        await m.createTable(appSettings);
        // Device yang gagal migrasi lama bisa jadi sudah punya kolom
        // ini (DDL ter-apply tapi user_version tak terangkat) — jangan
        // tambah dua kali.
        if (!await _hasColumn(m, 'transactions', 'category_id')) {
          await m.addColumn(transactions, transactions.categoryId);
        }
      }
      if (from < 3) {
        await m.createTable(accounts);
        await m.createTable(bons);
        if (!await _hasColumn(m, 'transactions', 'account_id')) {
          await m.addColumn(transactions, transactions.accountId);
        }
      }
      if (from < 5) {
        await m.createTable(budgets);
      }
      if (from < 6) {
        // budgets dibangun ulang: unique(kategori) lama dilepas,
        // diganti unique(kategori, akun); accountId ikut ditambah.
        // DB yang lompat jauh (mis. v2→v6) sudah membuat budgets
        // bentuk baru di langkah from<5 — jangan tambah dua kali.
        if (!await _hasColumn(m, 'budgets', 'account_id')) {
          await m.alterTable(
            TableMigration(budgets, newColumns: [budgets.accountId]),
          );
        }
        if (!await _hasColumn(m, 'accounts', 'opening_balance')) {
          await m.addColumn(accounts, accounts.openingBalance);
        }
      }
      if (from < 8) {
        // Fitur Target/Sisihkan dipensiunkan: tabel pos dibuang. Riwayat
        // setoran tetap ada sebagai transaksi transfer (bankId 'target').
        await customStatement('DROP TABLE IF EXISTS target_deposits');
        await customStatement('DROP TABLE IF EXISTS targets');
      }

      if (from < 9) {
        // Model "hubungkan bank": antrean draf menunggu keputusan user
        // + tautan akun↔bank katalog.
        await m.createTable(drafts);
        if (!await _hasColumn(m, 'accounts', 'bank_id')) {
          await m.addColumn(accounts, accounts.bankId);
        }
        // Tautkan akun lama ke bank katalog via nama — idempoten.
        for (final entry in <String, String>{
          'blu': 'blu by BCA',
          'nagari': 'Bank Nagari',
        }.entries) {
          await customStatement(
            'UPDATE accounts SET bank_id = ? '
            'WHERE bank_id IS NULL AND name = ?',
            [entry.key, entry.value],
          );
        }
      }
      if (from < 10) {
        // Aturan buatan pengguna dipensiunkan bersama model
        // hubungkan bank; tabelnya dibuang. Notifikasi yang digugurkan
        // dedup kini dicatat (ignored_dup) agar tetap terlihat.
        await customStatement('DROP TABLE IF EXISTS user_rules');
        if (!await _hasColumn(m, 'capture_logs', 'ignored_dup')) {
          await m.addColumn(captureLogs, captureLogs.ignoredDup);
        }
      }
      if (from < 11) {
        // Index kolom panas & komposit: query periode/watch, filter akun,
        // serta kalkulasi saldo tidak lagi full table scan.
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_transactions_occurred_at '
          'ON transactions (occurred_at)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_transactions_account_occurred '
          'ON transactions (account_id, occurred_at DESC)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_transactions_balance_covering '
          'ON transactions (account_id, direction, amount)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_transactions_dir_occurred '
          'ON transactions (direction, occurred_at DESC)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_transactions_cat_occurred '
          'ON transactions (category_id, occurred_at DESC)',
        );
      }
      if (from < 12) {
        if (await _hasTable(m, 'bons')) {
          if (!await _hasColumn(m, 'bons', 'category_id')) {
            await m.addColumn(bons, bons.categoryId);
          }
          if (!await _hasColumn(m, 'bons', 'account_id')) {
            await m.addColumn(bons, bons.accountId);
          }
          if (!await _hasColumn(m, 'bons', 'settlement_transaction_id')) {
            await m.addColumn(bons, bons.settlementTransactionId);
          }
        }
      }
      if (from < 13) {
        // Transfer antar akun sendiri (pasangan/manual) dulu bertanda
        // 'transfer'; sekarang 'internal'. Transfer dari notifikasi
        // (ke pihak lain) tetap 'transfer' dan ikut dihitung.
        await customStatement(
          "UPDATE transactions SET kind = 'internal' "
          "WHERE kind = 'transfer' AND (source = 'manual' "
          "OR counterparty LIKE 'Transfer ke %' "
          "OR counterparty LIKE 'Transfer dari %')",
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // Self-heal index v11 untuk DB baru maupun lama.
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_transactions_occurred_at '
        'ON transactions (occurred_at)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_transactions_account_occurred '
        'ON transactions (account_id, occurred_at DESC)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_transactions_balance_covering '
        'ON transactions (account_id, direction, amount)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_transactions_dir_occurred '
        'ON transactions (direction, occurred_at DESC)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_transactions_cat_occurred '
        'ON transactions (category_id, occurred_at DESC)',
      );
      final m = createMigrator();
      // Self-heal idempoten: buat ulang tabel yang hilang (IF NOT
      // EXISTS) — menyembuhkan device yang gagal migrasi di tengah jalan.
      await m.createTable(categories);
      await m.createTable(appSettings);
      await m.createTable(accounts);
      await m.createTable(bons);
      await m.createTable(budgets);

      await m.createTable(drafts);
      if (!await _hasColumn(m, 'bons', 'category_id')) {
        await m.addColumn(bons, bons.categoryId);
      }
      if (!await _hasColumn(m, 'bons', 'account_id')) {
        await m.addColumn(bons, bons.accountId);
      }
      if (!await _hasColumn(m, 'bons', 'settlement_transaction_id')) {
        await m.addColumn(bons, bons.settlementTransactionId);
      }
      if (!await _hasColumn(m, 'capture_logs', 'ignored_dup')) {
        await m.addColumn(captureLogs, captureLogs.ignoredDup);
      }
      // Seed kategori bawaan sekali — berlaku untuk DB baru maupun hasil
      // upgrade.
      final existing = await select(categories).get();
      if (existing.isEmpty) {
        await batch((b) => b.insertAll(categories, defaultCategoryRows()));
      }
      // Seed akun bawaan sekali.
      final existingAccounts = await select(accounts).get();
      if (existingAccounts.isEmpty) {
        await batch((b) => b.insertAll(accounts, defaultAccountRows()));
      }
      // Backfill kategori default untuk baris lama yang belum punya —
      // idempoten (hanya category_id IS NULL).
      for (final entry in <String, List<String>>{
        'Transfer': ['transfer', 'topup', 'withdrawal'],
        'Belanja': ['payment'],
        'Lainnya': ['other'],
      }.entries) {
        await customStatement(
          'UPDATE transactions SET category_id = '
          '(SELECT id FROM categories WHERE name = ?) '
          'WHERE category_id IS NULL AND kind IN '
          "(${entry.value.map((_) => '?').join(', ')})",
          [entry.key, ...entry.value],
        );
      }
      // Backfill akun dari bank_id lama — idempoten.
      for (final entry in <String, String>{
        'blu': 'blu by BCA',
        'nagari': 'Bank Nagari',
      }.entries) {
        await customStatement(
          'UPDATE transactions SET account_id = '
          '(SELECT id FROM accounts WHERE name = ?) '
          'WHERE account_id IS NULL AND bank_id = ?',
          [entry.value, entry.key],
        );
      }
    },
  );
}

const List<String> defaultCategoryNames = [
  'Makanan',
  'Transportasi',
  'Tagihan',
  'Belanja',
  'Gaji',
  'Transfer',
  'Lainnya',
];

List<CategoriesCompanion> defaultCategoryRows() => [
  for (var i = 0; i < defaultCategoryNames.length; i++)
    CategoriesCompanion.insert(name: defaultCategoryNames[i], colorIndex: i),
];

const List<({String name, AccountKind kind})> defaultAccounts = [
  (name: 'blu by BCA', kind: AccountKind.bank),
  (name: 'Bank Nagari', kind: AccountKind.bank),
  (name: 'Tunai', kind: AccountKind.cash),
];

List<AccountsCompanion> defaultAccountRows() => [
  for (var i = 0; i < defaultAccounts.length; i++)
    AccountsCompanion.insert(
      name: defaultAccounts[i].name,
      kind: defaultAccounts[i].kind,
      colorIndex: i,
    ),
];

/// Menerapkan backup yang di-stage oleh layar Backup (jika ada).
///
/// Dipanggil di main() SEBELUM database dibuka: mengganti file DB dengan
/// hasil restore pilihan user.
Future<void> applyPendingRestore() async {
  final marker = File(
    '${(await getApplicationDocumentsDirectory()).path}/'
    'restore_pending',
  );
  if (!marker.existsSync()) return;
  final dbFile = await currentDatabaseFile();
  if (dbFile.existsSync()) await dbFile.delete();
  for (final suffix in ['-wal', '-shm']) {
    final side = File('${dbFile.path}$suffix');
    if (side.existsSync()) await side.delete();
  }
  final staging = File(
    '${(await getTemporaryDirectory()).path}/'
    'restore_staging.sqlite',
  );
  if (staging.existsSync()) {
    await staging.copy(dbFile.path);
    await staging.delete();
  }
  await marker.delete();
}

Future<bool> _hasTable(Migrator m, String table) async {
  final rows = await m.database
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable.withString(table)],
      )
      .get();
  return rows.isNotEmpty;
}

Future<bool> _hasColumn(Migrator m, String table, String column) async {
  final rows = await m.database
      .customSelect(
        'SELECT name FROM pragma_table_info(?)',
        variables: [Variable.withString(table)],
      )
      .get();
  return rows.any((r) => r.data['name'] == column);
}

/// Executor terenkripsi untuk file DB tertentu — helper top-level
/// murni agar closure `setup` TIDAK membawa konteks pemanggilnya
/// (BuildContext/State) ke isolate background: objek seperti itu
/// unsendable dan membuat `Isolate.spawn` melempar (bug audit A-11 —
/// rekey backup gagal senyap).
QueryExecutor encryptedExecutor(File file, String passphrase) {
  return NativeDatabase.createInBackground(
    file,
    setup: (rawDb) {
      rawDb.execute("PRAGMA key = '$passphrase'");
    },
  );
}

/// Lokasi file DB aktif — dipakai openAppDatabase & layar Backup.
Future<File> currentDatabaseFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/catatim.sqlite');
}

/// Passphrase aktif — dibutuhkan layar Backup agar user bisa menyimpannya
/// bersama file backup.
Future<String> currentPassphrase() => _passphrase();

/// Membuka database terenkripsi SQLCipher.
///
/// Passphrase dibuat acak sekali dan disimpan di Android Keystore
/// (flutter_secure_storage) — file .sqlite di penyimpanan app tidak
/// dapat dibaca tanpa passphrase tersebut.
Future<QueryExecutor> openAppDatabase() async {
  final file = await currentDatabaseFile();
  final passphrase = await _passphrase();
  return LazyDatabase(() async => encryptedExecutor(file, passphrase));
}

Future<String> _passphrase() async {
  const storage = FlutterSecureStorage();
  final existing = await storage.read(key: 'db_passphrase');
  if (existing != null) return existing;
  final random = Random.secure();
  final generated = List.generate(
    32,
    (_) => random.nextInt(256),
  ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  await storage.write(key: 'db_passphrase', value: generated);
  return generated;
}
