import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';

import '../core/budget.dart';
import '../models.dart';
import 'database.dart';
import 'repository.dart';

/// Isi data contoh supaya emulator/demo langsung hidup.
///
/// Transaksi contoh hanya diisi sekali saat DB benar-benar kosong. Batas
/// (harian/mingguan/bulanan), saldo awal akun, dan alokasi kategori diisi
/// idempoten bila masih kosong — supaya DB dev lama yang sudah punya
/// transaksi tapi belum punya batas ikut hidup tanpa hapus data.
/// Hanya berjalan di debug build; rilis tidak tersentuh.
///
/// Tanggal transaksi demo **relatif ke "sekarang"**: [refreshSeedDemoDates]
/// dipanggil setiap start debug untuk menggeser tanggal baris demo
/// (diidentifikasi uuid deterministik `seed-dummy-*`) sehingga meter
/// harian/mingguan/bulanan selalu terisi. Baris yang dihapus pengguna
/// tidak dihidupkan ulang.
Future<void> seedDummyIfEmpty(AppDatabase db, LedgerRepository repo) async {
  if (!kDebugMode) return;
  await _seedLimitsAccountsBudgets(repo);
  await _purgeLegacySeed(repo, db);
  // Insert selama baris demo (uuid seed-dummy-*) belum ada — data
  // testing buatan pengguna tidak menghalangi kehadiran data demo.
  final existingSeed = await (db.select(db.transactions)
        ..where((t) => t.uuid.like('seed-dummy-%')))
      .get();
  if (existingSeed.isNotEmpty) return;

  final cats = await repo.getCategories();
  if (cats.isEmpty) return;
  int cat(String name) => cats.firstWhere((c) => c.name == name).id;

  final rows = <TransactionsCompanion>[
    for (final s in _seedSpecs(DateTime.now())) s.toCompanion(cat),
  ];

  await db.batch((b) => b.insertAll(db.transactions, rows));

  // Satu contoh capture mentah supaya Capture Log tidak kosong.
  await repo.recordUnparsedCapture(
    RawCapture(
      packageName: 'com.bcadigital.blu',
      title: 'blu by BCA',
      body: 'Penambahan dana ke bluSaving sisa Rp 2.000 berhasil',
      postedAt: DateTime.now(),
    ),
  );
}

/// Geser tanggal transaksi demo mengikuti hari berjalan. Dipanggil
/// setiap start debug — meter harian/mingguan/bulanan selalu punya
/// bahan. Baris tanpa uuid `seed-dummy-*` (termasuk yang dihapus
/// pengguna) tidak disentuh.
Future<void> refreshSeedDemoDates(AppDatabase db) async {
  if (!kDebugMode) return;
  for (final s in _seedSpecs(DateTime.now())) {
    await (db.update(db.transactions)..where((t) => t.uuid.equals(s.uuid)))
        .write(TransactionsCompanion(occurredAt: drift.Value(s.when)));
  }
}

/// Satu transaksi demo: identitas tetap + isi.
class _SeedTx {
  const _SeedTx(
    this.uuid,
    this.when,
    this.amount,
    this.direction,
    this.kind,
    this.category,
    this.counterparty,
    this.source,
  );

  final String uuid;
  final DateTime when;
  final int amount;
  final Direction direction;
  final TxKind kind;
  final String category;
  final String counterparty;
  final TxSource source;

  TransactionsCompanion toCompanion(int Function(String name) cat) =>
      TransactionsCompanion.insert(
        uuid: uuid,
        bankId: source == TxSource.notification ? 'blu' : 'manual',
        kind: kind,
        direction: direction,
        amount: amount,
        counterparty: drift.Value(counterparty),
        occurredAt: when,
        source: source,
        categoryId: drift.Value(cat(category)),
      );
}

/// Pola demo — dirakit relatif ke [now]:
///
/// * **Minggu berjalan** dipatok ke hari dalam minggu (Senin = 0) agar
///   meter mingguan (kalender sejak Senin) selalu terisi: Senin 55rb,
///   Selasa 40rb, Rabu 45rb, Kamis 35rb, Jumat 30rb, Sabtu 25rb.
/// * **Bulan berjalan** dipatok ke tanggal (3, 7, 11, 14, 18, 21) untuk
///   tagihan/belanana bulanan; tanggal yang belum tercapai dilewati.
/// * Pemasukan (gaji, freelance, proyek) menyeimbangi kartu arus.
List<_SeedTx> _seedSpecs(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: now.weekday - 1));

  DateTime? week(int sinceMonday, int hour, int minute) {
    final d = DateTime(
      monday.year,
      monday.month,
      monday.day + sinceMonday,
      hour,
      minute,
    );
    return d.isAfter(now) ? null : d;
  }

  DateTime? month(int day, int hour, int minute) {
    final d = DateTime(now.year, now.month, day, hour, minute);
    return d.isAfter(now) ? null : d;
  }

  return [
    // ── Minggu berjalan (kalender sejak Senin) ──
    if (week(0, 7, 40) case final d?)
      _SeedTx('seed-dummy-01', d, 35000, Direction.outgoing, TxKind.payment,
          'Transportasi', 'Pertamax 2L', TxSource.notification),
    if (week(0, 12, 30) case final d?)
      _SeedTx('seed-dummy-02', d, 20000, Direction.outgoing, TxKind.payment,
          'Makanan', 'Kopi Kenangan', TxSource.manual),
    if (week(0, 20, 15) case final d?)
      _SeedTx('seed-dummy-03', d, 2500000, Direction.incoming, TxKind.transfer,
          'Transfer', 'Proyek desain logo', TxSource.manual),
    if (week(1, 12, 30) case final d?)
      _SeedTx('seed-dummy-04', d, 25000, Direction.outgoing, TxKind.payment,
          'Makanan', 'Warung Nasi Bu Sri', TxSource.manual),
    if (week(1, 17, 45) case final d?)
      _SeedTx('seed-dummy-05', d, 15000, Direction.outgoing, TxKind.payment,
          'Transportasi', 'Gojek ke kantor', TxSource.manual),
    if (week(2, 9, 40) case final d?)
      _SeedTx('seed-dummy-06', d, 25000, Direction.outgoing, TxKind.payment,
          'Tagihan', 'Pulsa & paket data', TxSource.manual),
    if (week(2, 19, 5) case final d?)
      _SeedTx('seed-dummy-07', d, 20000, Direction.outgoing, TxKind.payment,
          'Makanan', 'Ayam Geprek Bakar', TxSource.manual),
    if (week(3, 10, 20) case final d?)
      _SeedTx('seed-dummy-08', d, 35000, Direction.outgoing, TxKind.payment,
          'Belanja', 'Indomaret', TxSource.manual),
    if (week(4, 19, 30) case final d?)
      _SeedTx('seed-dummy-09', d, 30000, Direction.outgoing, TxKind.payment,
          'Makanan', 'Ayam Geprek Bakar', TxSource.manual),
    if (week(5, 20, 0) case final d?)
      _SeedTx('seed-dummy-10', d, 25000, Direction.outgoing, TxKind.payment,
          'Hiburan', 'Nonton bioskop', TxSource.manual),

    // ── Bulan berjalan (dipatok tanggal) ──
    if (month(3, 10, 0) case final d?)
      _SeedTx('seed-dummy-11', d, 200000, Direction.outgoing, TxKind.payment,
          'Tagihan', 'Listrik PLN', TxSource.manual),
    if (month(7, 14, 0) case final d?)
      _SeedTx('seed-dummy-12', d, 220000, Direction.outgoing, TxKind.payment,
          'Belanja', 'Belanja bulanan pasar', TxSource.manual),
    if (month(10, 9, 15) case final d?)
      _SeedTx('seed-dummy-13', d, 8500000, Direction.incoming, TxKind.transfer,
          'Gaji', 'Gaji bulanan', TxSource.manual),
    if (month(11, 13, 0) case final d?)
      _SeedTx('seed-dummy-14', d, 90000, Direction.outgoing, TxKind.payment,
          'Kesehatan', 'Apotek Kimia Farma', TxSource.manual),
    if (month(14, 15, 0) case final d?)
      _SeedTx('seed-dummy-15', d, 180000, Direction.outgoing, TxKind.payment,
          'Belanja', 'Shopee: rak sepatu', TxSource.manual),
    if (month(18, 20, 0) case final d?)
      _SeedTx('seed-dummy-16', d, 120000, Direction.outgoing, TxKind.payment,
          'Hiburan', 'Langganan streaming', TxSource.manual),
    if (month(19, 19, 0) case final d?)
      _SeedTx('seed-dummy-17', d, 1000000, Direction.incoming, TxKind.transfer,
          'Transfer', 'Bayaran freelance artikel', TxSource.manual),
    if (month(5, 8, 30) case final d?)
      _SeedTx('seed-dummy-18', d, 100000, Direction.outgoing, TxKind.payment,
          'Transportasi', 'Bensin & parkir', TxSource.manual),
  ];
}

/// Seed lama (sebelum uuid deterministik) memakai uuid acak — tidak bisa
/// di-re-date. Dibersihkan sekali saat versi seed naik, ditandai lewat
/// setting agar data buatan pengguna dengan nama serupa aman setelahnya.
const String _kSeedVersionKey = 'seed_dummy_version';
const String _kSeedVersion = '2';

const Set<String> _legacySeedCounterparties = {
  'Kopi Kenangan',
  'Warung Nasi Bu Sri',
  'Pertamax 2L',
  'Ayam Geprek Bakar',
  'Proyek desain logo',
  'Gojek ke kantor',
  'Pulsa & paket data',
  'Indomaret bulanan',
  'Top up bluSaving',
  'Netflix',
  'Sate Ayam Pak Kusno',
  'Gaji bulanan',
  'Listrik PLN',
  'Apotek Kimia Farma',
  'Bakso Pak Mahmud',
  'Shopee: rak sepatu',
  'Tarik tunai ATM',
  'Nonton bioskop',
  'Bayaran freelance artikel',
};

Future<void> _purgeLegacySeed(LedgerRepository repo, AppDatabase db) async {
  final version = await repo.getSetting(_kSeedVersionKey);
  if (version == _kSeedVersion) return;
  final legacyRows = await (db.select(db.transactions)
        ..where((t) => t.counterparty.isIn(_legacySeedCounterparties)))
      .get();
  final staleUuids = legacyRows
      .where((r) => !r.uuid.startsWith('seed-dummy-'))
      .map((r) => r.uuid)
      .toList();
  if (staleUuids.isNotEmpty) {
    await (db.delete(db.transactions)..where((t) => t.uuid.isIn(staleUuids)))
        .go();
  }
  await repo.setSetting(_kSeedVersionKey, _kSeedVersion);
}

/// Batas + saldo + alokasi contoh. Idempoten: hanya mengisi yang kosong.
Future<void> _seedLimitsAccountsBudgets(LedgerRepository repo) async {
  // Batas demo dipatok matang dan diset ulang setiap start debug —
  // seeder memilikinya. Alasan: derivasi dari belanja aktual (versi
  // lama) mengikuti transaksi uji yang menumpuk di DB dev hingga
  // menghasilkan batas raksasa/urutan timpang, dan aturan "hormati
  // angka manual" tak bisa membedakannya dari setup demo. Perubahan
  // batas manual saat sesi berjalan tetap berlaku sampai restart.
  await repo.setSetting(kKeyDailyLimit, '50000');
  await repo.setSetting(kKeyWeeklyLimit, '300000');
  await repo.setSetting(kKeyMonthlyTotal, '1500000');

  // Saldo awal: total 4,8jt agar baris saldo tenang terisi wajar.
  final accounts = await repo.getAccounts();
  final balances = await repo.watchAccountBalances().first;
  final allZero = balances.values.every((v) => v == 0);
  if (allZero) {
    for (final a in accounts) {
      final opening = switch (a.name) {
        'blu by BCA' => 3500000,
        'Bank Nagari' => 800000,
        'Tunai' => 500000,
        _ => 0,
      };
      if (opening > 0) await repo.setOpeningBalance(a.id, opening);
    }
  }

  // Alokasi kategori contoh (bulanan).
  final budgets = await repo.watchBudgets().first;
  if (budgets.isEmpty) {
    final cats = await repo.getCategories();
    int? catId(String name) =>
        cats.where((c) => c.name == name).map((c) => c.id).firstOrNull;
    final seed = <String, int>{
      'Makanan': 600000,
      'Transportasi': 300000,
      'Tagihan': 400000,
      'Belanja': 500000,
      'Hiburan': 200000,
    };
    for (final e in seed.entries) {
      final id = catId(e.key);
      if (id != null) await repo.setBudget(id, e.value);
    }
  }
}
