import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models.dart';

part 'database.g.dart';

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

@DriftDatabase(tables: [Transactions, CaptureLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

/// Membuka database terenkripsi SQLCipher.
///
/// Passphrase dibuat acak sekali dan disimpan di Android Keystore
/// (flutter_secure_storage) — file .sqlite di penyimpanan app tidak
/// dapat dibaca tanpa passphrase tersebut.
Future<QueryExecutor> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'bukuduit.sqlite'));
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
