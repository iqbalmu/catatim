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
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
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
}

@DriftDatabase(tables: [Transactions, CaptureLogs, Categories, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(transactions, transactions.categoryId);
            await m.createTable(appSettings);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          // Seed kategori bawaan sekali — berlaku untuk DB baru maupun hasil
          // upgrade v1.
          final existing = await select(categories).get();
          if (existing.isEmpty) {
            await batch((b) => b.insertAll(categories, defaultCategoryRows()));
          }
        },
      );
}

const List<String> defaultCategoryNames = [
  'Makanan',
  'Transportasi',
  'Tagihan',
  'Belanja',
  'Hiburan',
  'Kesehatan',
  'Gaji',
  'Transfer',
  'Lainnya',
];

List<CategoriesCompanion> defaultCategoryRows() => [
      for (var i = 0; i < defaultCategoryNames.length; i++)
        CategoriesCompanion.insert(
          name: defaultCategoryNames[i],
          colorIndex: i,
        ),
    ];

/// Menerapkan backup yang di-stage oleh layar Backup (jika ada).
///
/// Dipanggil di main() SEBELUM database dibuka: mengganti file DB dengan
/// hasil restore pilihan user.
Future<void> applyPendingRestore() async {
  final marker = File('${(await getApplicationDocumentsDirectory()).path}/'
      'restore_pending');
  if (!marker.existsSync()) return;
  final dbFile = await currentDatabaseFile();
  if (dbFile.existsSync()) await dbFile.delete();
  for (final suffix in ['-wal', '-shm']) {
    final side = File('${dbFile.path}$suffix');
    if (side.existsSync()) await side.delete();
  }
  final staging = File('${(await getTemporaryDirectory()).path}/'
      'restore_staging.sqlite');
  if (staging.existsSync()) {
    await staging.copy(dbFile.path);
    await staging.delete();
  }
  await marker.delete();
}

/// Lokasi file DB aktif — dipakai openAppDatabase & layar Backup.
Future<File> currentDatabaseFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/bukuduit.sqlite');
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
  return LazyDatabase(() async {
    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        rawDb.execute("PRAGMA key = '$passphrase'");
      },
    );
  });
}

Future<String> _passphrase() async {
  const storage = FlutterSecureStorage();
  final existing = await storage.read(key: 'db_passphrase');
  if (existing != null) return existing;
  final random = Random.secure();
  final generated = List.generate(32, (_) => random.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  await storage.write(key: 'db_passphrase', value: generated);
  return generated;
}
