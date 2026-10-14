import 'dart:math';

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
Future<void> seedDummyIfEmpty(AppDatabase db, LedgerRepository repo) async {
  if (!kDebugMode) return;
  await _seedLimitsAccountsBudgets(repo);
  final existing = await db.select(db.transactions).get();
  if (existing.isNotEmpty) return;

  final cats = await repo.getCategories();
  if (cats.isEmpty) return;
  int cat(String name) => cats.firstWhere((c) => c.name == name).id;

  final now = DateTime.now();
  DateTime at(int dayAgo, int hour, int minute) =>
      DateTime(now.year, now.month, now.day - dayAgo, hour, minute);

  TransactionsCompanion tx(
    DateTime when,
    int amount,
    Direction direction,
    TxKind kind,
    String category,
    String counterparty,
    TxSource source,
  ) => TransactionsCompanion.insert(
    uuid: newUuid(),
    bankId: source == TxSource.notification ? 'blu' : 'manual',
    kind: kind,
    direction: direction,
    amount: amount,
    counterparty: drift.Value(counterparty),
    occurredAt: when,
    source: source,
    categoryId: drift.Value(cat(category)),
  );

  final rows = <TransactionsCompanion>[
    // Hari ini
    tx(
      at(0, 7, 45),
      18000,
      Direction.outgoing,
      TxKind.payment,
      'Makanan',
      'Kopi Kenangan',
      TxSource.manual,
    ),
    tx(
      at(0, 12, 30),
      22000,
      Direction.outgoing,
      TxKind.payment,
      'Makanan',
      'Warung Nasi Bu Sri',
      TxSource.manual,
    ),
    // Kemarin
    tx(
      at(1, 8, 10),
      50000,
      Direction.outgoing,
      TxKind.payment,
      'Transportasi',
      'Pertamax 2L',
      TxSource.notification,
    ),
    tx(
      at(1, 19, 5),
      75000,
      Direction.outgoing,
      TxKind.payment,
      'Makanan',
      'Ayam Geprek Bakar',
      TxSource.manual,
    ),
    tx(
      at(1, 20, 0),
      2500000,
      Direction.incoming,
      TxKind.transfer,
      'Transfer',
      'Proyek desain logo',
      TxSource.manual,
    ),
    // 3 hari lalu
    tx(
      at(3, 9, 0),
      35000,
      Direction.outgoing,
      TxKind.payment,
      'Transportasi',
      'Gojek ke kantor',
      TxSource.manual,
    ),
    tx(
      at(3, 15, 40),
      68000,
      Direction.outgoing,
      TxKind.payment,
      'Tagihan',
      'Pulsa & paket data',
      TxSource.manual,
    ),
    // 5 hari lalu
    tx(
      at(5, 10, 20),
      125000,
      Direction.outgoing,
      TxKind.payment,
      'Belanja',
      'Indomaret bulanan',
      TxSource.manual,
    ),
    tx(
      at(5, 16, 0),
      30000,
      Direction.outgoing,
      TxKind.topup,
      'Transfer',
      'Top up bluSaving',
      TxSource.notification,
    ),
    // 7 hari lalu
    tx(
      at(7, 11, 0),
      45000,
      Direction.outgoing,
      TxKind.payment,
      'Hiburan',
      'Netflix',
      TxSource.manual,
    ),
    tx(
      at(7, 18, 30),
      60000,
      Direction.outgoing,
      TxKind.payment,
      'Makanan',
      'Sate Ayam Pak Kusno',
      TxSource.manual,
    ),
    // 10 hari lalu
    tx(
      at(10, 9, 15),
      8500000,
      Direction.incoming,
      TxKind.transfer,
      'Gaji',
      'Gaji bulanan',
      TxSource.manual,
    ),
    tx(
      at(10, 14, 0),
      500000,
      Direction.outgoing,
      TxKind.payment,
      'Tagihan',
      'Listrik PLN',
      TxSource.manual,
    ),
    // 14 hari lalu
    tx(
      at(14, 13, 0),
      90000,
      Direction.outgoing,
      TxKind.payment,
      'Kesehatan',
      'Apotek Kimia Farma',
      TxSource.manual,
    ),
    tx(
      at(14, 17, 45),
      55000,
      Direction.outgoing,
      TxKind.payment,
      'Makanan',
      'Bakso Pak Mahmud',
      TxSource.manual,
    ),
    // 20 hari lalu
    tx(
      at(20, 10, 0),
      200000,
      Direction.outgoing,
      TxKind.payment,
      'Belanja',
      'Shopee: rak sepatu',
      TxSource.manual,
    ),
    tx(
      at(20, 20, 15),
      40000,
      Direction.outgoing,
      TxKind.withdrawal,
      'Transfer',
      'Tarik tunai ATM',
      TxSource.manual,
    ),
    // 25 hari lalu
    tx(
      at(25, 12, 0),
      120000,
      Direction.outgoing,
      TxKind.payment,
      'Hiburan',
      'Nonton bioskop',
      TxSource.manual,
    ),
    tx(
      at(25, 19, 0),
      1000000,
      Direction.incoming,
      TxKind.transfer,
      'Transfer',
      'Bayaran freelance artikel',
      TxSource.manual,
    ),
  ];

  await db.batch((b) => b.insertAll(db.transactions, rows));

  // Satu contoh capture mentah supaya Capture Log tidak kosong.
  await repo.recordUnparsedCapture(
    RawCapture(
      packageName: 'com.bcadigital.blu',
      title: 'blu by BCA',
      body: 'Penambahan dana ke bluSaving sisa Rp 2.000 berhasil',
      postedAt: now,
    ),
  );
}

/// Batas + saldo + alokasi contoh. Idempoten: hanya mengisi yang kosong.
Future<void> _seedLimitsAccountsBudgets(LedgerRepository repo) async {
  /// Default debug lama yang kekecilan (50rb/400rb/2jt) ikut ditimpa —
  /// hanya itu; angka yang user atur manual tidak disentuh.
  const oldDefaults = {
    kKeyDailyLimit: '50000',
    kKeyWeeklyLimit: '400000',
    kKeyMonthlyTotal: '2000000',
  };
  Future<bool> needsLimit(String key) async {
    final v = await repo.getSetting(key);
    if (v == null || v.isEmpty || int.tryParse(v) == null) return true;
    return v == oldDefaults[key];
  }

  // Batas global diturunkan dari belanja aktual + headroom, agar beranda
  // debug beraneka (ok/warning), bukan OVER semua. DB segar tanpa
  // transaksi → fallback angka mati kecil.
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dayEnd = DateTime(now.year, now.month, now.day + 1);
  final weekStart = today.subtract(Duration(days: now.weekday - 1));
  final monthStart = DateTime(now.year, now.month);
  final monthEnd = DateTime(now.year, now.month + 1);
  Future<int> eff(DateTime s, DateTime e) async =>
      (await repo.sumSpendBetween(s, e)) +
      (await repo.sumTargetTransferBetween(s, e));
  int withHeadroom(int used, double mult, int fallback) =>
      used <= 0 ? fallback : _niceLimit((used * mult).round());
  if (await needsLimit(kKeyDailyLimit)) {
    await repo.setSetting(
        kKeyDailyLimit, '${withHeadroom(await eff(today, dayEnd), 2.2, 50000)}');
  }
  if (await needsLimit(kKeyWeeklyLimit)) {
    await repo.setSetting(kKeyWeeklyLimit,
        '${withHeadroom(await eff(weekStart, dayEnd), 1.7, 400000)}');
  }
  if (await needsLimit(kKeyMonthlyTotal)) {
    await repo.setSetting(kKeyMonthlyTotal,
        '${withHeadroom(await eff(monthStart, monthEnd), 1.5, 2000000)}');
  }

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

/// Bulatkan [v] ke atas ke tangga 1–1,5–2–2,5–3–4–5–6–8–10 × 10ⁿ,
/// agar batas contoh terlihat seperti angka yang orang tulis manual.
int _niceLimit(int v) {
  if (v <= 0) return v;
  final mag = pow(10, (log(v) / ln10).floor()).toInt();
  final n = v / mag;
  const steps = [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10];
  for (final s in steps) {
    if (n <= s) return (s * mag).round();
  }
  return 10 * mag;
}
