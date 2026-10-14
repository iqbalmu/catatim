import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:bukuduit/models.dart';
import 'package:bukuduit/storage/database.dart'
    show AppDatabase, defaultCategoryNames;
import 'package:bukuduit/storage/repository.dart';

/// Regression: DB ber-schema v1 (dipakai versi app sebelum kategori) HARUS
/// termigrasi mulus ke v2 tanpa kehilangan data.
void main() {
  late File dbFile;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('bukuduit_mig');
    dbFile = File('${dir.path}/legacy.sqlite');

    // Bangun DB v1 persis seperti yang ada di device lama.
    final raw = sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        bank_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        direction TEXT NOT NULL,
        amount INTEGER NOT NULL,
        counterparty TEXT NULL,
        occurred_at INTEGER NOT NULL,
        source TEXT NOT NULL,
        raw_title TEXT NULL,
        raw_body TEXT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    raw.execute('''
      CREATE TABLE capture_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        posted_at INTEGER NOT NULL,
        parsed INTEGER NOT NULL,
        transaction_id INTEGER NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    raw.execute("PRAGMA user_version = 1");
    raw.execute('''
      INSERT INTO transactions
        (uuid, bank_id, kind, direction, amount, counterparty,
         occurred_at, source, raw_title, raw_body, created_at)
      VALUES ('legacy-1', 'blu', 'transfer', 'incoming', 2000000, 'BUDI',
              1790000000, 'notification', 'blu', 'Penambahan dana', 1790000000)
    ''');
    raw.close();
  });

  tearDown(() async {
    if (await dbFile.exists()) await dbFile.delete();
  });

  test('migrasi v1→v2: data lama tetap terbaca, kategori ter-seed', () async {
    final db = AppDatabase(NativeDatabase(dbFile));

    // Query apa pun memicu open + migrasi.
    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1));
    expect(txs.first.amount, 2000000);
    expect(txs.first.uuid, 'legacy-1');

    final logs = await db.select(db.captureLogs).get();
    expect(logs, hasLength(0));

    // Kolom baru dapat dipakai.
    final rows = await repo(db).watchRecentWithCategory().first;
    expect(rows.single.tx.uuid, 'legacy-1');
    expect(rows.single.category, isNotNull); // auto-assign Transfer

    final cats = await db.select(db.categories).get();
    expect(cats.map((c) => c.name), contains('Transfer'));

    await db.close();
  });

  test(
    'self-heal: DB "v2 rusak" (tanpa tabel categories) ikut disembuhkan',
    () async {
      // Simulasikan kondisi device yang menjalankan migrasi lama yang gagal:
      // user_version sudah 2, kolom category_id sudah ada, tapi tabel
      // categories & app_settings tidak pernah dibuat.
      final raw = sqlite3.open(dbFile.path);
      raw.execute(
        'ALTER TABLE transactions ADD COLUMN category_id INTEGER NULL '
        'REFERENCES categories (id)',
      );
      raw.execute('PRAGMA user_version = 2');
      raw.close();

      final db = AppDatabase(NativeDatabase(dbFile));
      final rows = await repo(db).watchRecentWithCategory().first;
      expect(rows.single.tx.amount, 2000000);
      expect(rows.single.category?.name, 'Transfer'); // seeded oleh beforeOpen

      final cats = await db.select(db.categories).get();
      expect(cats, hasLength(defaultCategoryNames.length));

      await db.close();
    },
  );

  test(
    'self-heal: DB setengah-migrasi (user_version=1, kolom sudah ada)',
    () async {
      // Kondisi persis device nyata: ALTER TABLE sudah ter-apply, tapi
      // user_version tetap 1 karena migrasi gagal di tengah jalan.
      final raw = sqlite3.open(dbFile.path);
      raw.execute(
        'ALTER TABLE transactions ADD COLUMN category_id INTEGER NULL '
        'REFERENCES categories (id)',
      );
      raw.close();

      final db = AppDatabase(
        NativeDatabase(dbFile),
      ); // from=1 → onUpgrade jalan
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(1)); // tidak melempar duplicate column

      final rows = await repo(db).watchRecentWithCategory().first;
      expect(rows.single.category?.name, 'Transfer');
      await db.close();
    },
  );

  test('migrasi v2→v3: akun ter-seed, accountId ter-backfill', () async {
    // setUp sudah membuat skema v1; simulasikan hasil migrasi v1→v2:
    // tambah kolom category_id + tabel categories/app_settings.
    final raw = sqlite3.open(dbFile.path);
    raw.execute(
      'ALTER TABLE transactions ADD COLUMN category_id INTEGER NULL '
      'REFERENCES categories (id)',
    );
    raw.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color_index INTEGER NOT NULL
      )
    ''');
    raw.execute('''
      CREATE TABLE app_settings (
        key TEXT NOT NULL PRIMARY KEY,
        value_text TEXT NOT NULL
      )
    ''');
    raw.execute('PRAGMA user_version = 2');
    raw.execute('''
      INSERT INTO transactions
        (uuid, bank_id, kind, direction, amount, counterparty,
         occurred_at, source, raw_title, raw_body, created_at, category_id)
      VALUES ('legacy-blu', 'blu', 'transfer', 'incoming', 100000, 'BUDI',
              1790000000, 'notification', 't', 'b', 1790000000, NULL),
             ('legacy-manual', 'manual', 'payment', 'outgoing', 25000, NULL,
              1790000000, 'manual', NULL, NULL, 1790000000, NULL)
    ''');
    raw.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    final accounts = await db.select(db.accounts).get();
    expect(
      accounts.map((a) => a.name),
      containsAll(['blu by BCA', 'Bank Nagari', 'Tunai']),
    );

    final txs = await db.select(db.transactions).get();
    final blu = txs.firstWhere((t) => t.uuid == 'legacy-blu');
    final bluAccount = accounts.firstWhere((a) => a.name == 'blu by BCA');
    expect(blu.accountId, bluAccount.id);
    final manual = txs.firstWhere((t) => t.uuid == 'legacy-manual');
    expect(manual.accountId, isNull);

    final repository = repo(db);
    await repository.addBon(
      person: 'Andi',
      amount: 50000,
      direction: BonDirection.lent,
    );
    final bons = await repository.watchBons().first;
    expect(bons.single.person, 'Andi');
    expect(bons.single.settledAt, isNull);

    await db.close();
  });

  test('migrasi v5→v6: alokasi & saldo awal baru, data lama utuh', () async {
    // Naikkan skema secara manual ke v5 (bentuk lama: budgets tanpa
    // account_id dengan UNIQUE(category_id), accounts tanpa saldo awal).
    final raw = sqlite3.open(dbFile.path);
    raw.execute(
      'ALTER TABLE transactions ADD COLUMN category_id INTEGER NULL '
      'REFERENCES categories (id)',
    );
    raw.execute(
      'ALTER TABLE transactions ADD COLUMN account_id INTEGER NULL '
      'REFERENCES accounts (id)',
    );
    raw.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color_index INTEGER NOT NULL
      )
    ''');
    raw.execute('''
      CREATE TABLE app_settings (
        key TEXT NOT NULL PRIMARY KEY,
        value_text TEXT NOT NULL
      )
    ''');
    raw.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        kind TEXT NOT NULL,
        color_index INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    raw.execute('''
      CREATE TABLE bons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        person TEXT NOT NULL,
        amount INTEGER NOT NULL,
        direction TEXT NOT NULL,
        note TEXT NULL,
        occurred_at INTEGER NOT NULL,
        settled_at INTEGER NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    raw.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL UNIQUE REFERENCES categories (id),
        monthly_limit INTEGER NOT NULL
      )
    ''');
    raw.execute('PRAGMA user_version = 5');
    raw.execute("INSERT INTO categories (name, color_index) VALUES ('Makanan', 0)");
    raw.execute(
      "INSERT INTO accounts (name, kind, color_index, created_at) "
      "VALUES ('blu by BCA', 'bank', 0, 1790000000)",
    );
    raw.execute(
      "INSERT INTO budgets (category_id, monthly_limit) "
      "VALUES ((SELECT id FROM categories WHERE name = 'Makanan'), 2000000)",
    );
    raw.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    final budgets = await db.select(db.budgets).get();
    expect(budgets.single.monthlyLimit, 2000000);
    expect(budgets.single.accountId, isNull); // kolom baru terisi null
    final accounts = await db.select(db.accounts).get();
    expect(accounts.single.openingBalance, 0); // kolom baru default 0

    // Tabel baru bisa dipakai: alokasi ber-scope akun disimpan terpisah
    // dari alokasi global untuk kategori yang sama.
    final repository = repo(db);
    await repository.setBudget(
      budgets.single.categoryId,
      3000000,
      accountId: accounts.single.id,
    );
    final scoped = await repository.watchBudgets().first;
    expect(scoped, hasLength(2));

    await db.close();
  });

  test('migrasi v7→v8: tabel target dibuang, data lama utuh', () async {
    // Naikkan skema secara manual ke v7 (bentuk terakhir dengan fitur
    // Target): skema v6 plus tabel targets & target_deposits berisi satu
    // pos.
    final raw = sqlite3.open(dbFile.path);
    raw.execute(
      'ALTER TABLE transactions ADD COLUMN category_id INTEGER NULL '
      'REFERENCES categories (id)',
    );
    raw.execute(
      'ALTER TABLE transactions ADD COLUMN account_id INTEGER NULL '
      'REFERENCES accounts (id)',
    );
    raw.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color_index INTEGER NOT NULL
      )
    ''');
    raw.execute('''
      CREATE TABLE app_settings (
        key TEXT NOT NULL PRIMARY KEY,
        value_text TEXT NOT NULL
      )
    ''');
    raw.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        kind TEXT NOT NULL,
        color_index INTEGER NOT NULL,
        opening_balance INTEGER NOT NULL DEFAULT (0),
        created_at INTEGER NOT NULL
      )
    ''');
    raw.execute('''
      CREATE TABLE bons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        person TEXT NOT NULL,
        amount INTEGER NOT NULL,
        direction TEXT NOT NULL,
        note TEXT NULL,
        occurred_at INTEGER NOT NULL,
        settled_at INTEGER NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    raw.execute('''
      CREATE TABLE user_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        package_name TEXT NULL,
        match_text TEXT NULL,
        amount_pattern TEXT NULL,
        direction TEXT NOT NULL,
        kind TEXT NOT NULL,
        account_id INTEGER NULL REFERENCES accounts (id),
        enabled INTEGER NOT NULL DEFAULT (1),
        created_at INTEGER NOT NULL
      )
    ''');
    raw.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL REFERENCES categories (id),
        account_id INTEGER NULL REFERENCES accounts (id),
        monthly_limit INTEGER NOT NULL,
        UNIQUE (category_id, account_id)
      )
    ''');
    raw.execute('''
      CREATE TABLE targets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL UNIQUE,
        goal_amount INTEGER NOT NULL,
        deadline INTEGER NULL,
        archived_at INTEGER NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    raw.execute('''
      CREATE TABLE target_deposits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        target_id INTEGER NOT NULL REFERENCES targets (id) ON DELETE CASCADE,
        account_id INTEGER NULL REFERENCES accounts (id),
        amount INTEGER NOT NULL CHECK (amount > 0),
        occurred_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    raw.execute('PRAGMA user_version = 6');
    raw.execute("INSERT INTO categories (name, color_index) VALUES ('Makanan', 0)");
    raw.execute(
      "INSERT INTO accounts (name, kind, color_index, created_at) "
      "VALUES ('blu by BCA', 'bank', 0, 1790000000)",
    );
    raw.execute(
      "INSERT INTO targets (uuid, name, goal_amount, created_at) "
      "VALUES ('tgt-1', 'Dana Darurat', 1000000, 1790000000)",
    );
    raw.close();

    final db = AppDatabase(NativeDatabase(dbFile));

    // Data lama tetap terbaca.
    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1));
    expect(txs.first.uuid, 'legacy-1');

    // Tabel target dibuang migrasi v8; riwayat setoran tetap ada sebagai
    // transaksi transfer biasa.
    final leftovers = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name IN ('targets', 'target_deposits')",
        )
        .get();
    expect(leftovers, isEmpty);

    await db.close();
  });
}

LedgerRepository repo(AppDatabase db) => LedgerRepository(db);
