import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../core/budget.dart';
import '../core/csv_export.dart' show ExportRow;
import '../models.dart';
import '../rules/engine.dart' show RuleEngine;
import '../rules/rule_set.dart' show CustomTemplate;
import 'database.dart';

// Dipecah ke part files — satu library, semua nama tetap.
part 'repository/capture_logs.dart';
part 'repository/manual_transactions.dart';
part 'repository/categories.dart';
part 'repository/drafts.dart';
part 'repository/banks_rules.dart';
part 'repository/queries.dart';
part 'repository/settings.dart';
part 'repository/budgets.dart';
part 'repository/accounts.dart';
part 'repository/bons.dart';

/// Transaksi + kategori ter-join (kategori null bila belum disetel).
class TxWithCategory {
  const TxWithCategory({required this.tx, this.category});

  final Transaction tx;
  final Category? category;
}

/// Akses data transaksi, kategori, settings, dan dedup capture.
class LedgerRepository {
  LedgerRepository(this._db);

  final AppDatabase _db;

  /// Akses database untuk kebutuhan di luar repository (mis. seeder data
  /// contoh pada build debug).
  AppDatabase get db => _db;

  /// Dua notifikasi dari bank+nominal+arah yang sama dalam jendela ini
  /// dianggap duplikat (bank sering kirim ganda / push+SMS).
  static const dedupWindow = Duration(seconds: 120);

  static const _internalKinds = [
    TxKind.internal,
    TxKind.topup,
    TxKind.withdrawal,
  ];

  /// Pemetaan jenis transaksi → nama kategori bawaan.
  static const _kindCategoryName = {
    TxKind.transfer: 'Transfer',
    TxKind.payment: 'Belanja',
    TxKind.topup: 'Transfer',
    TxKind.withdrawal: 'Transfer',
    TxKind.other: 'Lainnya',
    TxKind.internal: 'Transfer',
  };

  // --- kategori -------------------------------------------------------------

  /// Urutan tampil kategori: id naik, kecuali "Lainnya" — fallback yang
  /// tidak bisa dihapus — selalu paling akhir di semua daftar.
  static int categoryDisplayOrder(Category a, Category b) {
    final aLast = a.name.toLowerCase() == 'lainnya';
    final bLast = b.name.toLowerCase() == 'lainnya';
    if (aLast != bLast) return aLast ? 1 : -1;
    return a.id.compareTo(b.id);
  }

  /// Jendela waktu dua kaki perpindahan dana dianggap satu kejadian.
  static const linkWindow = Duration(minutes: 5);

  // --- koneksi bank (model hubungkan bank) ----------------------------------------

  /// Kunci settings penyimpan daftar bankId terhubung (CSV).
  static const connectedBanksKey = 'connected_banks';

  // --- bank custom (mode belajar: app apa pun) --------------------------------

  static const customBanksKey = 'custom_banks';

  // --- template aturan kustom (tuning capture) -------------------------------

  static const customTemplatesKey = 'custom_templates_json';

  // --- pola notifikasi yang diabaikan (blacklist / auto-ignore) ----------------

  static const ignoredPatternsKey = 'ignored_patterns';

  // --- tema tampilan -----------------------------------------------------------

  static const themeModeKey = 'theme_mode';

  static const autoRecordKey = 'auto_record_enabled';

  // --- peringatan batas (notifikasi Android) -----------------------------------

  static const budgetAlertsEnabledKey = 'budget_alerts_enabled';

  static const budgetAlertThresholdKey = 'budget_alert_threshold';

  static const budgetAlertStateKey = 'budget_alert_state';

  /// Persen bawaan peringatan batas saat user belum memilih.
  static const defaultBudgetAlertThreshold = 80;

  // --- transfer antar-akun internal -------------------------------------------

  /// Pisahkan daftar draf menjadi pasangan transfer antar-akun sendiri dan draf tunggal.
  /// Dua draf berpasangan bila:
  /// - Nominalnya sama
  /// - Arahnya berlawanan (satu keluar, satu masuk)
  /// - Berasal dari bank berbeda (atau akun berbeda)
  /// - Waktu kejadiannya berdekatan (dalam [window], default 5 menit).
  static ({List<InternalTransferPair> pairs, List<Draft> singles})
  partitionDrafts(
    List<Draft> drafts, {
    Duration window = const Duration(minutes: 5),
  }) {
    if (drafts.length < 2) {
      return (pairs: const [], singles: drafts);
    }

    final pairs = <InternalTransferPair>[];
    final matchedIds = <int>{};

    for (var i = 0; i < drafts.length; i++) {
      final a = drafts[i];
      if (matchedIds.contains(a.id)) continue;

      for (var j = i + 1; j < drafts.length; j++) {
        final b = drafts[j];
        if (matchedIds.contains(b.id)) continue;

        final isOppositeDirection = a.direction != b.direction;
        final isSameAmount = a.amount == b.amount;
        final isDifferentBankOrAccount =
            a.bankId != b.bankId ||
            (a.accountId != null &&
                b.accountId != null &&
                a.accountId != b.accountId);
        final isWithinWindow =
            a.occurredAt.difference(b.occurredAt).abs() <= window;

        if (isOppositeDirection &&
            isSameAmount &&
            isDifferentBankOrAccount &&
            isWithinWindow) {
          matchedIds.add(a.id);
          matchedIds.add(b.id);
          final outDraft = a.direction == Direction.outgoing ? a : b;
          final inDraft = a.direction == Direction.incoming ? a : b;
          pairs.add(InternalTransferPair(outDraft: outDraft, inDraft: inDraft));
          break;
        }
      }
    }

    final singles = [
      for (final d in drafts)
        if (!matchedIds.contains(d.id)) d,
    ];

    return (pairs: pairs, singles: singles);
  }

  /// Kosongkan seluruh data aplikasi (transaksi, draf, bon, anggaran, log capture,
  /// saldo akun) dan kembalikan ke kondisi bawaan bersih.
  Future<void> resetAllData() async {
    await _db.transaction(() async {
      // 1. Hapus transaksi, draf, bon, anggaran, dan log capture
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.drafts).go();
      await _db.delete(_db.bons).go();
      await _db.delete(_db.captureLogs).go();
      await _db.delete(_db.budgets).go();

      // 2. Hapus preferensi dan setelan lama, lalu tandai demo seed dinonaktifkan
      await _db.delete(_db.appSettings).go();
      await _db
          .into(_db.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: 'demo_seed_disabled',
              valueText: '1',
            ),
          );

      // 3. Reset akun: hapus semua akun dan buat ulang akun default bersih dengan saldo 0
      await _db.delete(_db.accounts).go();
      await _db.batch((b) => b.insertAll(_db.accounts, defaultAccountRows()));

      // 4. Reset kategori: hapus semua kategori dan buat ulang kategori bawaan
      await _db.delete(_db.categories).go();
      await _db.batch(
        (b) => b.insertAll(_db.categories, defaultCategoryRows()),
      );
    });
  }

  // --- backup -----------------------------------------------------------------

  /// Flush WAL ke file utama sebelum file DB dicopy untuk backup.
  Future<void> checkpoint() =>
      _db.customStatement('PRAGMA wal_checkpoint(FULL)');
}

/// Pasangan dua draf notifikasi yang saling melengkapi sebagai
/// transfer antar rekening sendiri (uang keluar di satu akun, masuk di akun lain).
class InternalTransferPair {
  const InternalTransferPair({required this.outDraft, required this.inDraft});

  final Draft outDraft;
  final Draft inDraft;

  int get amount => outDraft.amount;

  DateTime get occurredAt => outDraft.occurredAt.isAfter(inDraft.occurredAt)
      ? outDraft.occurredAt
      : inDraft.occurredAt;
}
