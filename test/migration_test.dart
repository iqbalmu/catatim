import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
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

  test('self-heal: DB "v2 rusak" (tanpa tabel categories) ikut disembuhkan',
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
  });
}

LedgerRepository repo(AppDatabase db) => LedgerRepository(db);
