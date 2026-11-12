import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../models.dart';
import '../rules/engine.dart' show RuleEngine;
import '../rules/rule_set.dart' show CustomTemplate;
import 'database.dart';

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

  // --- capture ------------------------------------------------------------

  /// Catat notifikasi yang tidak berhasil diparse (untuk Diagnostik).
  ///
  /// Log mentah yang identik (paket+judul+isi dalam jendela dedup) hanya
  /// dicatat sekali — melindungi dari pemrosesan ganda drain+stream.
  Future<void> recordUnparsedCapture(RawCapture raw) {
    return _db.transaction(() async {
      await _logCaptureOnce(raw, parsed: false);
    });
  }

  /// Catat notifikasi yang diabaikan (karena non-transaksi atau pola yang diblokir).
  Future<void> recordIgnoredCapture(RawCapture raw) {
    return _db.transaction(() async {
      await _logCaptureOnce(raw, parsed: true, ignoredDup: true);
    });
  }

  /// Notifikasi mentah yang belum berhasil diparse.
  Future<List<CaptureLog>> unparsedCaptures() async {
    return (_db.select(_db.captureLogs)
          ..where((c) => c.parsed.equals(false))
          ..orderBy([(c) => OrderingTerm.desc(c.postedAt)]))
        .get();
  }

  /// Notifikasi dikenali namun digugurkan dedup (duplikat) — bisa
  /// ditindaklanjuti manual atau dihapus dari Diagnostik.
  Stream<List<CaptureLog>> watchIgnoredDuplicates({int limit = 20}) {
    return (_db.select(_db.captureLogs)
          ..where((c) => c.ignoredDup.equals(true))
          ..orderBy([(c) => OrderingTerm.desc(c.postedAt)])
          ..limit(limit))
        .watch();
  }

  /// Hapus satu baris log notifikasi.
  Future<void> deleteCaptureLog(int id) {
    return (_db.delete(_db.captureLogs)..where((c) => c.id.equals(id))).go();
  }

  /// Hapus beberapa baris log notifikasi sekaligus.
  Future<int> deleteCaptureLogs(Iterable<int> ids) {
    if (ids.isEmpty) return Future.value(0);
    return (_db.delete(_db.captureLogs)..where((c) => c.id.isIn(ids))).go();
  }

  /// Bersihkan log yang tak lagi relevan: sudah terbaca atau duplikat
  /// yang lebih tua dari 30 hari. Mengembalikan jumlah baris terhapus.
  Future<int> pruneCaptureLogs() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return (_db.delete(_db.captureLogs)..where(
          (c) =>
              (c.parsed.equals(true) | c.ignoredDup.equals(true)) &
              c.postedAt.isSmallerThanValue(cutoff),
        ))
        .go();
  }

  /// Parse ulang semua capture gagal dengan rules terkini, berbatas bank
  /// [connectedBankIds]. Yang berhasil menjadi DRAF (bukan transaksi).
  /// Mengembalikan jumlah draf yang dibuat.
  Future<int> reparseUnparsed(
    RuleEngine engine, {
    required Set<String> connectedBankIds,
  }) {
    return reparseWith(
      (raw) => engine.parse(
        packageName: raw.packageName,
        title: raw.title,
        body: raw.body,
      ),
      connectedBankIds: connectedBankIds,
    );
  }

  /// Inti [reparseUnparsed] yang dapat diuji tanpa engine sungguhan.
  Future<int> reparseWith(
    ParsedDraft? Function(RawCapture raw) parse, {
    required Set<String> connectedBankIds,
  }) async {
    final logs = await unparsedCaptures();
    var created = 0;
    for (final log in logs) {
      final raw = RawCapture(
        packageName: log.packageName,
        title: log.title,
        body: log.body,
        postedAt: log.postedAt,
      );
      final draft = parse(raw);
      if (draft == null || !connectedBankIds.contains(draft.bankId)) continue;
      final id = await addDraftFromCapture(raw: raw, draft: draft);
      // Dikenali → tandai terbaca; duplikat yang digugurkan sudah
      // tercatat sebagai baris ignored_dup, tak perlu dicoba ulang.
      await (_db.update(_db.captureLogs)..where((c) => c.id.equals(log.id)))
          .write(const CaptureLogsCompanion(parsed: Value(true)));
      if (id != null) created++;
    }
    return created;
  }

  // --- transaksi manual & edit ---------------------------------------------

  Future<int> addManual({
    required int amount,
    required Direction direction,
    required TxKind kind,
    String? counterparty,
    int? categoryId,
    int? accountId,
    DateTime? occurredAt,
  }) async {
    final clean = (counterparty == null || counterparty.trim().isEmpty)
        ? null
        : counterparty.trim();
    final resolvedCategoryId =
        categoryId ??
        await preferredCategoryId(counterparty: clean, kind: kind);
    return _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            uuid: newUuid(),
            bankId: 'manual',
            kind: kind,
            direction: direction,
            amount: amount,
            counterparty: Value(clean),
            occurredAt: occurredAt ?? DateTime.now(),
            source: TxSource.manual,
            categoryId: Value(resolvedCategoryId),
            accountId: Value(accountId),
          ),
        );
  }

  /// Tambah pasangan transfer internal manual: 1 keluar di akun asal, 1 masuk di akun tujuan.
  Future<void> addManualTransfer({
    required int fromAccountId,
    required int toAccountId,
    required int amount,
    DateTime? occurredAt,
    String? note,
  }) async {
    final at = occurredAt ?? DateTime.now();
    final transferCatId = await _defaultCategoryId(TxKind.internal);
    final allAccounts = await getAccounts();
    final fromAcc = allAccounts.where((a) => a.id == fromAccountId).firstOrNull;
    final toAcc = allAccounts.where((a) => a.id == toAccountId).firstOrNull;
    final fromLabel = fromAcc?.name ?? 'Akun #$fromAccountId';
    final toLabel = toAcc?.name ?? 'Akun #$toAccountId';
    final cleanNote = note?.trim();
    final outNote = (cleanNote != null && cleanNote.isNotEmpty)
        ? '$cleanNote (ke $toLabel)'
        : 'Transfer ke $toLabel';
    final inNote = (cleanNote != null && cleanNote.isNotEmpty)
        ? '$cleanNote (dari $fromLabel)'
        : 'Transfer dari $fromLabel';

    await _db.transaction(() async {
      await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              uuid: newUuid(),
              bankId: fromAcc?.bankId ?? 'manual',
              kind: TxKind.internal,
              direction: Direction.outgoing,
              amount: amount,
              counterparty: Value(outNote),
              occurredAt: at,
              source: TxSource.manual,
              categoryId: Value(transferCatId),
              accountId: Value(fromAccountId),
            ),
          );
      await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              uuid: newUuid(),
              bankId: toAcc?.bankId ?? 'manual',
              kind: TxKind.internal,
              direction: Direction.incoming,
              amount: amount,
              counterparty: Value(inNote),
              occurredAt: at,
              source: TxSource.manual,
              categoryId: Value(transferCatId),
              accountId: Value(toAccountId),
            ),
          );
    });
  }

  Future<void> updateTransaction(int id, TransactionsCompanion data) {
    return (_db.update(
      _db.transactions,
    )..where((t) => t.id.equals(id))).write(data);
  }

  Future<void> deleteTransaction(int id) async {
    return _db.transaction(() async {
      await (_db.update(
        _db.bons,
      )..where((b) => b.settlementTransactionId.equals(id))).write(
        const BonsCompanion(
          settledAt: Value(null),
          settlementTransactionId: Value(null),
        ),
      );
      await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
    });
  }

  // --- kategori -------------------------------------------------------------

  Stream<List<Category>> watchCategories() {
    return (_db.select(
      _db.categories,
    )..orderBy([(c) => OrderingTerm.asc(c.id)])).watch();
  }

  Future<List<Category>> getCategories() => _db.select(_db.categories).get();

  /// Tambah kategori; melempar bila nama sudah dipakai (unique).
  Future<Category> addCategory(String name) async {
    final all = await getCategories();
    final id = await _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(name: name.trim(), colorIndex: all.length),
        );
    return (await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(id))).getSingle());
  }

  Future<int?> _defaultCategoryId(TxKind kind) async {
    final name = _kindCategoryName[kind]!;
    final row = await (_db.select(
      _db.categories,
    )..where((c) => c.name.equals(name))).getSingleOrNull();
    return row?.id;
  }

  /// Kategori yang disukai/terakhir dipilih untuk [counterparty] tertentu.
  /// Bila belum ada riwayat transaksi dengan pihak ini, gunakan default dari [kind].
  Future<int?> preferredCategoryId({String? counterparty, TxKind? kind}) async {
    final clean = counterparty?.trim();
    if (clean != null && clean.isNotEmpty) {
      final cleanLower = clean.toLowerCase();
      final lastTx =
          await (_db.select(_db.transactions)
                ..where(
                  (t) =>
                      t.counterparty.isNotNull() &
                      t.categoryId.isNotNull() &
                      t.counterparty.lower().equals(cleanLower),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
                ..limit(1))
              .getSingleOrNull();
      if (lastTx?.categoryId != null) {
        return lastTx!.categoryId;
      }
    }
    if (kind != null) {
      return _defaultCategoryId(kind);
    }
    return null;
  }

  // --- draf (model hubungkan bank) ------------------------------------------------

  /// Simpan hasil capture sebagai DRAF menunggu keputusan user.
  /// Mengembalikan id draf baru, atau null bila dianggap duplikat
  /// (sudah ada draf / transaksi se-bank+nominal+arah dalam jendela).
  Future<int?> addDraftFromCapture({
    required RawCapture raw,
    required ParsedDraft draft,
  }) {
    return _db.transaction(() async {
      final from = raw.postedAt.subtract(dedupWindow);
      final to = raw.postedAt.add(dedupWindow);
      final dupTx =
          await (_db.select(_db.transactions)
                ..where(
                  (t) =>
                      t.bankId.equals(draft.bankId) &
                      t.amount.equals(draft.amount) &
                      t.direction.equalsValue(draft.direction) &
                      t.occurredAt.isBetweenValues(from, to),
                )
                ..limit(1))
              .getSingleOrNull();
      if (dupTx != null) {
        await _logCaptureOnce(raw, parsed: true, ignoredDup: true);
        return null;
      }
      final dupDraft =
          await (_db.select(_db.drafts)
                ..where(
                  (d) =>
                      d.bankId.equals(draft.bankId) &
                      d.amount.equals(draft.amount) &
                      d.direction.equalsValue(draft.direction) &
                      d.occurredAt.isBetweenValues(from, to),
                )
                ..limit(1))
              .getSingleOrNull();
      if (dupDraft != null) {
        await _logCaptureOnce(raw, parsed: true, ignoredDup: true);
        return null;
      }

      final resolvedCatId = await preferredCategoryId(
        counterparty: draft.counterparty,
        kind: draft.kind,
      );

      return _db
          .into(_db.drafts)
          .insert(
            DraftsCompanion.insert(
              bankId: draft.bankId,
              kind: draft.kind,
              direction: draft.direction,
              amount: draft.amount,
              counterparty: Value(draft.counterparty),
              occurredAt: raw.postedAt,
              rawTitle: Value(raw.title),
              rawBody: Value(raw.body),
              categoryId: Value(resolvedCatId),
              accountId: Value(await _accountIdForBank(draft.bankId)),
            ),
          );
    });
  }

  /// Draf menunggu keputusan, terbaru dulu — hidup (watch).
  Stream<List<Draft>> watchDrafts() {
    return (_db.select(
      _db.drafts,
    )..orderBy([(d) => OrderingTerm.desc(d.occurredAt)])).watch();
  }

  /// Konfirmasi draf → transaksi source notifikasi; draf terhapus.
  /// Field boleh dikoreksi user dulu; yang tak disebut mengikuti draf.
  Future<int> confirmDraft(
    Draft draft, {
    required int amount,
    required Direction direction,
    required TxKind kind,
    String? counterparty,
    int? categoryId,
    int? accountId,
    DateTime? occurredAt,
    bool auto = false,
  }) {
    return _db.transaction(() async {
      final clean = (counterparty == null || counterparty.trim().isEmpty)
          ? null
          : counterparty.trim();
      final targetCounterparty = clean ?? draft.counterparty;
      final resolvedCategoryId =
          categoryId ??
          draft.categoryId ??
          await preferredCategoryId(
            counterparty: targetCounterparty,
            kind: kind,
          );
      final id = await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              uuid: newUuid(),
              bankId: draft.bankId,
              kind: kind,
              direction: direction,
              amount: amount,
              counterparty: Value(targetCounterparty),
              occurredAt: occurredAt ?? draft.occurredAt,
              source: auto ? TxSource.auto : TxSource.notification,
              rawTitle: Value(draft.rawTitle),
              rawBody: Value(draft.rawBody),
              categoryId: Value(resolvedCategoryId),
              accountId: Value(accountId ?? draft.accountId),
            ),
          );
      await (_db.delete(_db.drafts)..where((d) => d.id.equals(draft.id))).go();
      return id;
    });
  }

  static const autoRecordKey = 'auto_record_enabled';

  /// Apakah draf hasil parse langsung dicatat tanpa menunggu konfirmasi.
  Future<bool> autoRecordEnabled() async =>
      await getSetting(autoRecordKey) == '1';

  Future<void> setAutoRecordEnabled(bool on) =>
      setSetting(autoRecordKey, on ? '1' : '0');

  Stream<bool> watchAutoRecordEnabled() {
    return (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(autoRecordKey)))
        .watchSingleOrNull()
        .map((row) => row?.valueText == '1');
  }

  /// Catat draf [id] otomatis sebagai transaksi source auto, lalu tautkan
  /// dengan kaki lawannya bila perpindahan dana antar akun sendiri.
  /// Draf tanpa nominal dilewati. Mengembalikan true bila tercatat.
  Future<bool> autoConfirmDraft(int id) async {
    final draft = await (_db.select(
      _db.drafts,
    )..where((d) => d.id.equals(id))).getSingleOrNull();
    if (draft == null || draft.amount <= 0) {
      return false;
    }
    final txId = await confirmDraft(
      draft,
      amount: draft.amount,
      direction: draft.direction,
      kind: draft.kind,
      auto: true,
    );
    await _linkInternalMove(txId);
    return true;
  }

  /// Jendela waktu dua kaki perpindahan dana dianggap satu kejadian.
  static const linkWindow = Duration(minutes: 5);

  /// - Tarik tunai keluar: buat kaki masuk di akun Tunai.
  /// - Transfer/top up: bila ada kaki lawan (nominal sama, arah berlawanan,
  ///   akun berbeda, dalam [linkWindow]) dari notifikasi, keduanya jadi
  ///   'internal' (antar akun sendiri) dan keluar dari arus kas.
  Future<void> _linkInternalMove(int txId) async {
    final tx = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(txId))).getSingleOrNull();
    if (tx == null) return;
    final accounts = await getAccounts();
    String nameOf(int? accountId, String fallback) =>
        accounts.where((a) => a.id == accountId).firstOrNull?.name ?? fallback;

    if (tx.kind == TxKind.withdrawal && tx.direction == Direction.outgoing) {
      final cash = accounts
          .where((a) => a.kind == AccountKind.cash)
          .firstOrNull;
      if (cash == null || cash.id == tx.accountId) return;
      final existing =
          await (_db.select(_db.transactions)
                ..where(
                  (t) =>
                      t.accountId.equals(cash.id) &
                      t.kind.equalsValue(TxKind.withdrawal) &
                      t.direction.equalsValue(Direction.incoming) &
                      t.amount.equals(tx.amount) &
                      t.occurredAt.isBetweenValues(
                        tx.occurredAt.subtract(linkWindow),
                        tx.occurredAt.add(linkWindow),
                      ),
                )
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) return;
      await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              uuid: newUuid(),
              bankId: cash.bankId ?? 'manual',
              kind: TxKind.withdrawal,
              direction: Direction.incoming,
              amount: tx.amount,
              counterparty: Value(
                'Tarik tunai dari ${nameOf(tx.accountId, tx.bankId)}',
              ),
              occurredAt: tx.occurredAt,
              source: TxSource.auto,
              categoryId: Value(await _defaultCategoryId(TxKind.internal)),
              accountId: Value(cash.id),
            ),
          );
      return;
    }

    if (tx.kind != TxKind.transfer && tx.kind != TxKind.topup) return;
    final opposite = tx.direction == Direction.incoming
        ? Direction.outgoing
        : Direction.incoming;
    final candidates =
        await (_db.select(_db.transactions)..where(
              (t) =>
                  t.id.equals(tx.id).not() &
                  t.amount.equals(tx.amount) &
                  t.direction.equalsValue(opposite) &
                  t.kind.isInValues(const [TxKind.transfer, TxKind.topup]) &
                  t.source.isInValues(const [
                    TxSource.auto,
                    TxSource.notification,
                  ]) &
                  t.occurredAt.isBetweenValues(
                    tx.occurredAt.subtract(linkWindow),
                    tx.occurredAt.add(linkWindow),
                  ),
            ))
            .get();
    final other = candidates.where((o) {
      if (o.accountId != null && tx.accountId != null) {
        return o.accountId != tx.accountId;
      }
      return o.bankId != tx.bankId;
    }).firstOrNull;
    if (other == null) return;

    final out = tx.direction == Direction.outgoing ? tx : other;
    final inn = tx.direction == Direction.incoming ? tx : other;
    final transferCatId = await _defaultCategoryId(TxKind.internal);
    await _db.transaction(() async {
      await (_db.update(
        _db.transactions,
      )..where((t) => t.id.equals(out.id))).write(
        TransactionsCompanion(
          kind: const Value(TxKind.internal),
          categoryId: Value(transferCatId),
          counterparty: Value(
            'Transfer ke ${nameOf(inn.accountId, inn.bankId)}',
          ),
        ),
      );
      await (_db.update(
        _db.transactions,
      )..where((t) => t.id.equals(inn.id))).write(
        TransactionsCompanion(
          kind: const Value(TxKind.internal),
          categoryId: Value(transferCatId),
          counterparty: Value(
            'Transfer dari ${nameOf(out.accountId, out.bankId)}',
          ),
        ),
      );
    });
  }

  /// Buang draf tanpa mencatat apa pun.
  Future<void> discardDraft(int id) {
    return (_db.delete(_db.drafts)..where((d) => d.id.equals(id))).go();
  }

  /// Buang beberapa draf sekaligus berdasarkan ID.
  Future<int> discardDrafts(Iterable<int> ids) {
    if (ids.isEmpty) return Future.value(0);
    return (_db.delete(_db.drafts)..where((d) => d.id.isIn(ids))).go();
  }

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

  /// Konfirmasi pasangan transfer antar rekening sendiri:
  /// Mencatat dua transaksi jenis transfer (keluar di akun asal, masuk di akun tujuan)
  /// dengan kategori "Transfer", lalu menghapus kedua draf.
  Future<void> confirmTransferPair({
    required InternalTransferPair pair,
    int? outAccountId,
    int? inAccountId,
  }) {
    return _db.transaction(() async {
      final transferCatId = await _defaultCategoryId(TxKind.internal);
      final fromAccId =
          outAccountId ??
          pair.outDraft.accountId ??
          await _accountIdForBank(pair.outDraft.bankId);
      final toAccId =
          inAccountId ??
          pair.inDraft.accountId ??
          await _accountIdForBank(pair.inDraft.bankId);

      final toAccount = toAccId != null
          ? await (_db.select(
              _db.accounts,
            )..where((a) => a.id.equals(toAccId))).getSingleOrNull()
          : null;
      final fromAccount = fromAccId != null
          ? await (_db.select(
              _db.accounts,
            )..where((a) => a.id.equals(fromAccId))).getSingleOrNull()
          : null;

      final toLabel = toAccount?.name ?? pair.inDraft.bankId;
      final fromLabel = fromAccount?.name ?? pair.outDraft.bankId;

      // 1. Kaki keluar
      await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              uuid: newUuid(),
              bankId: pair.outDraft.bankId,
              kind: TxKind.internal,
              direction: Direction.outgoing,
              amount: pair.amount,
              counterparty: Value('Transfer ke $toLabel'),
              occurredAt: pair.outDraft.occurredAt,
              source: TxSource.notification,
              rawTitle: Value(pair.outDraft.rawTitle),
              rawBody: Value(pair.outDraft.rawBody),
              categoryId: Value(transferCatId),
              accountId: Value(fromAccId),
            ),
          );

      // 2. Kaki masuk
      await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              uuid: newUuid(),
              bankId: pair.inDraft.bankId,
              kind: TxKind.internal,
              direction: Direction.incoming,
              amount: pair.amount,
              counterparty: Value('Transfer dari $fromLabel'),
              occurredAt: pair.inDraft.occurredAt,
              source: TxSource.notification,
              rawTitle: Value(pair.inDraft.rawTitle),
              rawBody: Value(pair.inDraft.rawBody),
              categoryId: Value(transferCatId),
              accountId: Value(toAccId),
            ),
          );

      // 3. Hapus kedua draf
      await (_db.delete(
        _db.drafts,
      )..where((d) => d.id.isIn([pair.outDraft.id, pair.inDraft.id]))).go();
    });
  }

  /// Cari transaksi pasangan transfer yang mungkin sudah tercatat sebelumnya.
  Future<Transaction?> findMatchingTransferTransaction(
    Draft draft, {
    Duration window = const Duration(minutes: 5),
  }) async {
    final from = draft.occurredAt.subtract(window);
    final to = draft.occurredAt.add(window);
    final oppositeDirection = draft.direction == Direction.incoming
        ? Direction.outgoing
        : Direction.incoming;

    return (_db.select(_db.transactions)
          ..where(
            (t) =>
                t.amount.equals(draft.amount) &
                t.direction.equalsValue(oppositeDirection) &
                t.bankId.equals(draft.bankId).not() &
                t.occurredAt.isBetweenValues(from, to),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  // --- koneksi bank (model hubungkan bank) ----------------------------------------

  /// Kunci settings penyimpan daftar bankId terhubung (CSV).
  static const connectedBanksKey = 'connected_banks';

  /// ID bank/e-wallet katalog (seed_rules) yang sedang terhubung.
  Future<Set<String>> connectedBankIds() async {
    final raw = await getSetting(connectedBanksKey);
    if (raw == null || raw.trim().isEmpty) return {};
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  /// Versi hidup dari [connectedBankIds].
  Stream<Set<String>> watchConnectedBanks() {
    return (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(connectedBanksKey)))
        .watchSingleOrNull()
        .map((row) {
          final raw = row?.valueText;
          if (raw == null || raw.trim().isEmpty) return {};
          return raw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toSet();
        });
  }

  /// Hubungkan / putuskan satu bank. Urutan koneksi dipertahankan.
  Future<void> setBankConnected(String bankId, bool connected) async {
    final current = (await connectedBankIds()).toList();
    if (connected && !current.contains(bankId)) {
      current.add(bankId);
    } else if (!connected) {
      current.remove(bankId);
    }
    await setSetting(connectedBanksKey, current.join(','));
  }

  // --- bank custom (mode belajar: app apa pun) --------------------------------

  static const customBanksKey = 'custom_banks';

  /// App apa pun yang dihubungkan user lewat Mode Belajar — disimpan
  /// sebagai baris "paket|nama" di app_settings.
  Future<List<({String package, String label})>> customBanks() async {
    final raw = await getSetting(customBanksKey);
    return _parseCustomBanks(raw);
  }

  /// Versi hidup dari [customBanks].
  Stream<List<({String package, String label})>> watchCustomBanks() {
    return (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(customBanksKey)))
        .watchSingleOrNull()
        .map((row) => _parseCustomBanks(row?.valueText));
  }

  static List<({String package, String label})> _parseCustomBanks(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return [
      for (final line in raw.split('\n'))
        if (line.contains('|'))
          (
            package: line.substring(0, line.indexOf('|')).trim(),
            label: line.substring(line.indexOf('|') + 1).trim(),
          ),
    ];
  }

  /// Hubungkan / putuskan app custom. bankId-nya berbentuk `app:<paket>`.
  Future<void> setCustomBankConnected(
    String package,
    String label,
    bool connected,
  ) async {
    final current = [...await customBanks()];
    if (connected && !current.any((c) => c.package == package)) {
      current.add((package: package, label: label));
    } else if (!connected) {
      current.removeWhere((c) => c.package == package);
    }
    await setSetting(
      customBanksKey,
      [for (final c in current) '${c.package}|${c.label}'].join('\n'),
    );
  }

  // --- template aturan kustom (tuning capture) -------------------------------

  static const customTemplatesKey = 'custom_templates_json';

  Future<List<CustomTemplate>> customTemplates() async {
    final raw = await getSetting(customTemplatesKey);
    return _parseCustomTemplates(raw);
  }

  Stream<List<CustomTemplate>> watchCustomTemplates() {
    return (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(customTemplatesKey)))
        .watchSingleOrNull()
        .map((row) => _parseCustomTemplates(row?.valueText));
  }

  static List<CustomTemplate> _parseCustomTemplates(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>? ?? const [];
      return [
        for (final item in list)
          if (item is Map<String, dynamic>) CustomTemplate.fromJson(item),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveCustomTemplate(CustomTemplate template) async {
    final current = [...await customTemplates()];
    final idx = current.indexWhere((t) => t.id == template.id);
    if (idx >= 0) {
      current[idx] = template;
    } else {
      current.add(template);
    }
    await setSetting(
      customTemplatesKey,
      jsonEncode([for (final t in current) t.toJson()]),
    );
  }

  Future<void> deleteCustomTemplate(String id) async {
    final current = [...await customTemplates()];
    current.removeWhere((t) => t.id == id);
    await setSetting(
      customTemplatesKey,
      jsonEncode([for (final t in current) t.toJson()]),
    );
  }

  // --- pola notifikasi yang diabaikan (blacklist / auto-ignore) ----------------

  static const ignoredPatternsKey = 'ignored_patterns';

  Future<List<IgnoredPattern>> ignoredPatterns() async {
    final raw = await getSetting(ignoredPatternsKey);
    return _parseIgnoredPatterns(raw);
  }

  Stream<List<IgnoredPattern>> watchIgnoredPatterns() {
    return (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(ignoredPatternsKey)))
        .watchSingleOrNull()
        .map((row) => _parseIgnoredPatterns(row?.valueText));
  }

  static List<IgnoredPattern> _parseIgnoredPatterns(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>? ?? const [];
      return [
        for (final item in list)
          if (item is Map<String, dynamic>) IgnoredPattern.fromJson(item),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> addIgnoredPattern({
    required String pattern,
    required String label,
    String? bankId,
  }) async {
    final cleanPattern = pattern.trim().toLowerCase();
    if (cleanPattern.isEmpty) return;
    final current = [...await ignoredPatterns()];
    if (current.any((p) => p.pattern == cleanPattern && p.bankId == bankId)) {
      return;
    }
    current.add(
      IgnoredPattern(
        id: newUuid(),
        pattern: cleanPattern,
        label: label.trim(),
        bankId: bankId,
        createdAt: DateTime.now(),
      ),
    );
    await setSetting(
      ignoredPatternsKey,
      jsonEncode([for (final p in current) p.toJson()]),
    );
  }

  Future<void> deleteIgnoredPattern(String id) async {
    final current = [...await ignoredPatterns()];
    current.removeWhere((p) => p.id == id);
    await setSetting(
      ignoredPatternsKey,
      jsonEncode([for (final p in current) p.toJson()]),
    );
  }

  /// Ekstrak frasa yang cocok untuk diabaikan dari draf, simpan ke pola abaikan,
  /// dan bersihkan draf saat ini serta draf lain yang berpola sama.
  Future<String> discardDraftAndLearnPattern(
    Draft draft, {
    String? customPattern,
  }) async {
    final rawText =
        '${draft.rawTitle ?? ''} ${draft.rawBody ?? ''} ${draft.counterparty ?? ''}'
            .trim();
    String pattern = (customPattern ?? '').trim().toLowerCase();
    if (pattern.isEmpty) {
      pattern = _smartExtractIgnorePattern(rawText);
    }
    if (pattern.isNotEmpty) {
      final bank = draft.bankId.startsWith('app:')
          ? draft.bankId.substring(4)
          : draft.bankId;
      await addIgnoredPattern(
        pattern: pattern,
        label: '$bank: "$pattern"',
        bankId: draft.bankId != 'unknown' && !draft.bankId.startsWith('app:')
            ? draft.bankId
            : null,
      );
    }

    // Hapus draf ini dan draf lain yang cocok dengan pola tersebut
    final allDrafts = await (_db.select(_db.drafts)).get();
    final toDelete = <int>[draft.id];
    if (pattern.isNotEmpty) {
      for (final d in allDrafts) {
        final dText =
            '${d.rawTitle ?? ''} ${d.rawBody ?? ''} ${d.counterparty ?? ''}'
                .toLowerCase();
        if (dText.contains(pattern)) {
          toDelete.add(d.id);
        }
      }
    }
    await discardDrafts(toDelete.toSet());
    return pattern;
  }

  /// Bersihkan draf non-transaksi (OTP, login alert, promo, info saldo).
  Future<int> purgeNonTransactionDrafts(RuleEngine engine) async {
    final allDrafts = await (_db.select(_db.drafts)).get();
    final toDelete = <int>[];
    for (final d in allDrafts) {
      final text =
          '${d.rawTitle ?? ''} ${d.rawBody ?? ''} ${d.counterparty ?? ''}'
              .trim();
      if (engine.isIgnored(text, bankId: d.bankId)) {
        toDelete.add(d.id);
      }
    }
    if (toDelete.isNotEmpty) {
      await discardDrafts(toDelete.toSet());
    }
    return toDelete.length;
  }

  static String _smartExtractIgnorePattern(String rawText) {
    if (rawText.isEmpty) return '';
    // Buang angka dinamis (OTP, nomor rekening, nominal) untuk mendapatkan kata kunci inti
    final withoutNumbers = rawText
        .replaceAll(RegExp(r'\b\d+\b'), '')
        .replaceAll(RegExp(r'Rp\.?\s*[\d.,]*', caseSensitive: false), '')
        .replaceAll(RegExp(r'[.,:;!?()\[\]]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    final words = withoutNumbers.split(' ').where((w) => w.length > 2).toList();
    if (words.isEmpty) return rawText.toLowerCase().trim();
    // Ambil 3-5 kata pertama yang signifikan
    return words.take(4).join(' ');
  }

  /// Draf "mentah" dari app custom (mode belajar): format notifikasinya
  /// belum dikenal rule — user yang melengkapi nominal/kategori saat
  /// konfirmasi. Dedup khusus: isi mentah identik (paket+judul+isi) dalam
  /// jendela [dedupWindow] hanya jadi satu draf — nominal 0 dua kali tidak
  /// boleh saling menelan.
  Future<int?> addRawDraftFromCapture({
    required RawCapture raw,
    required String bankId,
    required String bankName,
    required int amount,
    required Direction direction,
    int? categoryId,
    int? accountId,
  }) {
    return _db.transaction(() async {
      final from = raw.postedAt.subtract(dedupWindow);
      final to = raw.postedAt.add(dedupWindow);
      final title = raw.title.trim();
      final body = raw.body.trim();
      final dup =
          await (_db.select(_db.drafts)
                ..where(
                  (d) =>
                      d.bankId.equals(bankId) &
                      d.rawTitle.equals(title) &
                      d.rawBody.equals(body) &
                      d.occurredAt.isBetweenValues(from, to),
                )
                ..limit(1))
              .getSingleOrNull();
      if (dup != null) return null;
      final resolvedCatId =
          categoryId ??
          await preferredCategoryId(counterparty: title, kind: TxKind.other);
      final resolvedAccId = accountId ?? await _accountIdForBank(bankId);
      return _db
          .into(_db.drafts)
          .insert(
            DraftsCompanion.insert(
              bankId: bankId,
              kind: TxKind.other,
              direction: direction,
              amount: amount,
              occurredAt: raw.postedAt,
              rawTitle: Value(title),
              rawBody: Value(body),
              categoryId: Value(resolvedCatId),
              accountId: Value(resolvedAccId),
            ),
          );
    });
  }

  /// Akun milik bank [bankId]: cari yang tertaut, adopsi dari nama bila ada
  /// (DB lama), atau buat baru. Tak pernah duplikat per bankId.
  Future<Account> ensureBankAccount({
    required String bankId,
    required String name,
    required AccountKind kind,
  }) async {
    final linked = await (_db.select(
      _db.accounts,
    )..where((a) => a.bankId.equals(bankId))).getSingleOrNull();
    if (linked != null) return linked;
    final sameName = await (_db.select(
      _db.accounts,
    )..where((a) => a.name.equals(name))).getSingleOrNull();
    if (sameName != null) {
      await (_db.update(_db.accounts)..where((a) => a.id.equals(sameName.id)))
          .write(AccountsCompanion(bankId: Value(bankId)));
      return sameName.copyWith(bankId: Value(bankId));
    }
    final all = await getAccounts();
    final id = await _db
        .into(_db.accounts)
        .insert(
          AccountsCompanion.insert(
            name: name.trim(),
            kind: kind,
            colorIndex: all.length,
            bankId: Value(bankId),
          ),
        );
    return (await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(id))).getSingle());
  }

  // --- query transaksi --------------------------------------------------------

  JoinedSelectStatement _withCategoryQuery({
    DateTime? start,
    DateTime? end,
    int? limit,
    int? accountId,
  }) {
    final query = _db.select(_db.transactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ]);
    if (start != null && end != null) {
      // Periode [start, end) — ujung atas eksklusif (audit B-02);
      // transaksi tepat 00:00 bulan berikutnya milik bulan itu sendiri.
      query.where(
        _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      );
    }
    if (accountId != null) {
      query.where(_db.transactions.accountId.equals(accountId));
    }
    query.orderBy([OrderingTerm.desc(_db.transactions.occurredAt)]);
    if (limit != null) query.limit(limit);
    return query;
  }

  List<TxWithCategory> _mapRows(List<TypedResult> rows) => [
    for (final row in rows)
      TxWithCategory(
        tx: row.readTable(_db.transactions),
        category: row.readTableOrNull(_db.categories),
      ),
  ];

  Stream<List<TxWithCategory>> watchBetweenWithCategory(
    DateTime start,
    DateTime end, {
    int? accountId,
  }) => _withCategoryQuery(
    start: start,
    end: end,
    accountId: accountId,
  ).watch().map(_mapRows);

  Stream<List<TxWithCategory>> watchRecentWithCategory({
    int limit = 300,
    int? accountId,
  }) => _withCategoryQuery(
    limit: limit,
    accountId: accountId,
  ).watch().map(_mapRows);

  // --- capture log -------------------------------------------------------------

  Stream<List<CaptureLog>> watchCaptureLog({int limit = 300}) {
    return (_db.select(_db.captureLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.postedAt)])
          ..limit(limit))
        .watch();
  }

  /// Log notifikasi capture terbaru yang tersimpan di database.
  Future<CaptureLog?> getLatestCaptureLog() async {
    return (_db.select(_db.captureLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.postedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Stream log notifikasi capture terbaru yang tersimpan di database.
  Stream<CaptureLog?> watchLatestCaptureLog() {
    return (_db.select(_db.captureLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.postedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<void> markCaptureLogParsed(int logId) async {
    await (_db.update(_db.captureLogs)..where((c) => c.id.equals(logId))).write(
      const CaptureLogsCompanion(parsed: Value(true)),
    );
  }

  /// Jumlah transaksi per hari (UTC; drift menyimpan occurred_at sebagai
  /// epoch-ms UTC dan pembacaan lama juga mengelompokkan lewat field UTC)
  /// sejak [since] — sumber kebenaran streak di ProgressService.
  /// Diagregasi di SQLite (audit O-03), bukan menarik baris mentah.
  /// Bucket = hari LOKAL (modifier offset perangkat) — semantik sama
  /// dengan pembacaan Dart lama; drift menyimpan occurred_at epoch-detik.
  static String get _localTzModifier {
    final m = DateTime.now().timeZoneOffset.inMinutes;
    return m >= 0 ? '+$m minutes' : '-${-m} minutes';
  }

  Future<Map<DateTime, int>> txCountByDaySince(DateTime since) async {
    final rows = await _db
        .customSelect(
          "SELECT date(occurred_at, 'unixepoch', '$_localTzModifier') AS day, COUNT(*) AS c "
          'FROM transactions WHERE occurred_at >= ? GROUP BY day',
          variables: [Variable.withInt(since.millisecondsSinceEpoch ~/ 1000)],
          readsFrom: {_db.transactions},
        )
        .get();
    return {
      for (final r in rows)
        DateTime.parse(r.read<String>('day')): r.read<int>('c'),
    };
  }

  /// Total keluar per hari sejak [since] (inklusif) — bahan sparkline
  /// insight beranda. Diagregasi di SQLite (audit O-03); re-emit tiap
  /// tabel transaksi berubah.
  Stream<Map<DateTime, int>> watchOutSumByDaySince(DateTime since) {
    return _db
        .customSelect(
          "SELECT date(occurred_at, 'unixepoch', '$_localTzModifier') AS day, "
          'SUM(amount) AS s FROM transactions '
          "WHERE direction = 'outgoing' AND occurred_at >= ? GROUP BY day",
          variables: [Variable.withInt(since.millisecondsSinceEpoch ~/ 1000)],
          readsFrom: {_db.transactions},
        )
        .watch()
        .map(
          (rows) => {
            for (final r in rows)
              DateTime.parse(r.read<String>('day')): r.read<int>('s'),
          },
        );
  }

  /// Total belanja MURNI per hari sejak [since] (inklusif); transfer
  /// tidak ikut. Diagregasi di SQLite (audit O-03).
  Future<Map<DateTime, int>> outSpendByDaySince(DateTime since) async {
    final rows = await _db
        .customSelect(
          "SELECT date(occurred_at, 'unixepoch', '$_localTzModifier') AS day, SUM(amount) AS s "
          'FROM transactions '
          "WHERE direction = 'outgoing' AND kind NOT IN ('internal', 'topup', 'withdrawal') "
          'AND occurred_at >= ? GROUP BY day',
          variables: [Variable.withInt(since.millisecondsSinceEpoch ~/ 1000)],
          readsFrom: {_db.transactions},
        )
        .get();
    return {
      for (final r in rows)
        DateTime.parse(r.read<String>('day')): r.read<int>('s'),
    };
  }

  // --- settings -----------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.valueText;
  }

  Future<void> setSetting(String key, String value) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, valueText: value),
        );
  }

  /// Stream nilai setting integer (mis. batas harian/mingguan/bulanan) secara reaktif.
  Stream<int?> watchIntSetting(String key) {
    return (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(key))).watchSingleOrNull().map((row) {
      final text = row?.valueText.trim();
      if (text == null || text.isEmpty) return null;
      return int.tryParse(text);
    });
  }

  // --- tema tampilan -----------------------------------------------------------

  static const themeModeKey = 'theme_mode';

  /// Mode tema aplikasi: system, light, atau dark.
  Future<ThemeMode> getThemeMode() async {
    final raw = await getSetting(themeModeKey);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// Stream reaktif mode tema aplikasi.
  Stream<ThemeMode> watchThemeMode() {
    return (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(themeModeKey))).watchSingleOrNull().map((row) {
      final raw = row?.valueText;
      return switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    });
  }

  /// Ubah dan simpan mode tema aplikasi.
  Future<void> setThemeMode(ThemeMode mode) {
    final val = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    return setSetting(themeModeKey, val);
  }

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

  /// Keluar bulan dikelompokkan per pasangan (kategori, akun) dalam
  /// [start, end). Kunci kategori null = tanpa kategori, dst.
  Stream<Map<({int? category, int? account}), int>> watchOutPairsBetween(
    DateTime start,
    DateTime end,
  ) {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([
        _db.transactions.categoryId,
        _db.transactions.accountId,
        amountSum,
      ])
      ..where(
        _db.transactions.direction.equalsValue(Direction.outgoing) &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      )
      ..groupBy([_db.transactions.categoryId, _db.transactions.accountId]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          (
            category: row.read(_db.transactions.categoryId),
            account: row.read(_db.transactions.accountId),
          ): row.read(amountSum) ?? 0,
      },
    );
  }

  /// Versi one-shot dari [watchOutPairsBetween].
  Future<Map<({int? category, int? account}), int>> outPairsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([
        _db.transactions.categoryId,
        _db.transactions.accountId,
        amountSum,
      ])
      ..where(
        _db.transactions.direction.equalsValue(Direction.outgoing) &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      )
      ..groupBy([_db.transactions.categoryId, _db.transactions.accountId]);
    final rows = await query.get();
    return {
      for (final row in rows)
        (
          category: row.read(_db.transactions.categoryId),
          account: row.read(_db.transactions.accountId),
        ): row.read(amountSum) ?? 0,
    };
  }

  /// Total (masuk atau keluar) dalam [start, end) — hidup (watch).
  Stream<int> watchSumBetween(
    DateTime start,
    DateTime end,
    Direction direction,
  ) {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([amountSum])
      ..where(
        _db.transactions.direction.equalsValue(direction) &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      );
    return query.watchSingle().map((row) => row.read(amountSum) ?? 0);
  }

  /// Versi one-shot dari [watchSumBetween] — untuk perhitungan sekali
  /// jalan (ProgressService.refresh) tanpa langganan stream.
  Future<int> sumBetween(
    DateTime start,
    DateTime end,
    Direction direction,
  ) async {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([amountSum])
      ..where(
        _db.transactions.direction.equalsValue(direction) &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      );
    final row = await query.getSingle();
    return row.read(amountSum) ?? 0;
  }

  /// Ringkasan arus kas bulanan (total masuk, total keluar, dan selisih bersih)
  /// langsung dari agregasi SQL SQLite menggunakan covering index.
  /// Transaksi transfer dikecualikan agar tidak menggelembungkan arus kas riil.
  Stream<({int totalIn, int totalOut, int net})> watchMonthlyCashflow(
    DateTime start,
    DateTime end, {
    int? accountId,
  }) {
    final inSum = _db.transactions.amount.sum(
      filter:
          _db.transactions.direction.equalsValue(Direction.incoming) &
          _db.transactions.kind.isInValues(_internalKinds).not(),
    );
    final outSum = _db.transactions.amount.sum(
      filter:
          _db.transactions.direction.equalsValue(Direction.outgoing) &
          _db.transactions.kind.isInValues(_internalKinds).not(),
    );

    final query = _db.selectOnly(_db.transactions)
      ..addColumns([inSum, outSum])
      ..where(
        _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      );

    if (accountId != null) {
      query.where(_db.transactions.accountId.equals(accountId));
    }

    return query.watchSingle().map((row) {
      final totalIn = row.read(inSum) ?? 0;
      final totalOut = row.read(outSum) ?? 0;
      return (totalIn: totalIn, totalOut: totalOut, net: totalIn - totalOut);
    });
  }

  /// Total keluar MURNI dalam [start, end): outgoing TANPA kind
  /// transfer (transfer dikecualikan).
  Future<int> sumSpendBetween(DateTime start, DateTime end) async {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([amountSum])
      ..where(
        _db.transactions.direction.equalsValue(Direction.outgoing) &
            _db.transactions.kind.isInValues(_internalKinds).not() &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      );
    final row = await query.getSingle();
    return row.read(amountSum) ?? 0;
  }

  /// Versi pemasukan-murni dari [sumBetween]: kind transfer dikecualikan.
  Future<int> sumIncomeBetween(DateTime start, DateTime end) async {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([amountSum])
      ..where(
        _db.transactions.direction.equalsValue(Direction.incoming) &
            _db.transactions.kind.isInValues(_internalKinds).not() &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      );
    final row = await query.getSingle();
    return row.read(amountSum) ?? 0;
  }

  /// Versi belanja-murni dari [outPairsBetween]: kind transfer
  /// dikecualikan (alokasi spend-murni, Plan 04).
  Future<Map<({int? category, int? account}), int>> outSpendPairsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([
        _db.transactions.categoryId,
        _db.transactions.accountId,
        amountSum,
      ])
      ..where(
        _db.transactions.direction.equalsValue(Direction.outgoing) &
            _db.transactions.kind.isInValues(_internalKinds).not() &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      )
      ..groupBy([_db.transactions.categoryId, _db.transactions.accountId]);
    final rows = await query.get();
    return {
      for (final row in rows)
        (
          category: row.read(_db.transactions.categoryId),
          account: row.read(_db.transactions.accountId),
        ): row.read(amountSum) ?? 0,
    };
  }

  /// Saldo berjalan tiap akun = saldo awal + masuk − keluar. Transfer/
  /// topup satu kaki sementara dihitung sebagai keluar/masuk akun asal;
  /// transfer dua kaki menyusul.
  Stream<Map<int, int>> watchAccountBalances() {
    final inSum = _db.transactions.amount.sum(
      filter: _db.transactions.direction.equalsValue(Direction.incoming),
    );
    final outSum = _db.transactions.amount.sum(
      filter: _db.transactions.direction.equalsValue(Direction.outgoing),
    );
    final query = _db.selectOnly(_db.accounts).join([
      leftOuterJoin(
        _db.transactions,
        _db.transactions.accountId.equalsExp(_db.accounts.id),
      ),
    ]);
    query.addColumns([
      _db.accounts.id,
      _db.accounts.openingBalance,
      inSum,
      outSum,
    ]);
    query.groupBy([_db.accounts.id]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(_db.accounts.id)!:
              _intOf(row.read(_db.accounts.openingBalance)) +
              _intOf(row.read(inSum)) -
              _intOf(row.read(outSum)),
      },
    );
  }

  Future<Map<int, int>> getAccountBalances() async {
    final inSum = _db.transactions.amount.sum(
      filter: _db.transactions.direction.equalsValue(Direction.incoming),
    );
    final outSum = _db.transactions.amount.sum(
      filter: _db.transactions.direction.equalsValue(Direction.outgoing),
    );
    final query = _db.selectOnly(_db.accounts).join([
      leftOuterJoin(
        _db.transactions,
        _db.transactions.accountId.equalsExp(_db.accounts.id),
      ),
    ]);
    query.addColumns([
      _db.accounts.id,
      _db.accounts.openingBalance,
      inSum,
      outSum,
    ]);
    query.groupBy([_db.accounts.id]);
    final rows = await query.get();
    return {
      for (final row in rows)
        row.read(_db.accounts.id)!:
            _intOf(row.read(_db.accounts.openingBalance)) +
            _intOf(row.read(inSum)) -
            _intOf(row.read(outSum)),
    };
  }

  static int _intOf(Object? value) => (value as num?)?.toInt() ?? 0;

  // --- kategori -----------------------------------------------------------------

  /// Ubah nama kategori; melempar bila nama sudah dipakai (unique).
  Future<void> renameCategory(int id, String name) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(name: Value(name.trim())),
    );
  }

  /// Hapus kategori: transaksinya dipindah ke kategori [fallbackId]
  /// (biasanya "Lainnya"), alokasinya ikut terhapus.
  Future<void> deleteCategory(int id, {required int fallbackId}) async {
    if (id == fallbackId) throw ArgumentError('tidak boleh hapus fallback');
    await (_db.update(_db.transactions)..where((t) => t.categoryId.equals(id)))
        .write(TransactionsCompanion(categoryId: Value(fallbackId)));
    await (_db.delete(_db.budgets)..where((b) => b.categoryId.equals(id))).go();
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }

  // --- backup -----------------------------------------------------------------

  /// Flush WAL ke file utama sebelum file DB dicopy untuk backup.
  Future<void> checkpoint() =>
      _db.customStatement('PRAGMA wal_checkpoint(FULL)');

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

  // --- bon -------------------------------------------------------------------

  /// Semua bon, yang belum lunas dulu (NULL settledAt diurut pertama).
  Stream<List<Bon>> watchBons() {
    return (_db.select(_db.bons)..orderBy([
          (b) => OrderingTerm.asc(b.settledAt),
          (b) => OrderingTerm.desc(b.occurredAt),
        ]))
        .watch();
  }

  Future<List<Bon>> getBons() {
    return (_db.select(_db.bons)..orderBy([
          (b) => OrderingTerm.asc(b.settledAt),
          (b) => OrderingTerm.desc(b.occurredAt),
        ]))
        .get();
  }

  Future<int> addBon({
    required String person,
    int amount = 0,
    required BonDirection direction,
    String? note,
    DateTime? occurredAt,
    int? categoryId,
    int? accountId,
  }) {
    final cleanNote = (note == null || note.trim().isEmpty)
        ? null
        : note.trim();
    return _db
        .into(_db.bons)
        .insert(
          BonsCompanion.insert(
            uuid: newUuid(),
            person: person.trim(),
            amount: Value(amount),
            direction: direction,
            note: Value(cleanNote),
            occurredAt: occurredAt ?? DateTime.now(),
            categoryId: Value(categoryId),
            accountId: Value(accountId),
          ),
        );
  }

  Future<void> updateBon(int id, BonsCompanion data) {
    return (_db.update(_db.bons)..where((b) => b.id.equals(id))).write(data);
  }

  /// Lunasi bon: buat transaksi kas riil di akun dan kategori yang dipilih,
  /// lalu tandai bon lunas dengan mereferensikan transaksi tersebut.
  Future<int> settleBon({
    required int bonId,
    required int amount,
    required int accountId,
    required int categoryId,
    DateTime? settledAt,
  }) async {
    return _db.transaction(() async {
      final bon = await (_db.select(
        _db.bons,
      )..where((b) => b.id.equals(bonId))).getSingle();
      final date = settledAt ?? DateTime.now();
      final isLent = bon.direction == BonDirection.lent;

      final txId = await addManual(
        amount: amount,
        direction: isLent ? Direction.incoming : Direction.outgoing,
        kind: TxKind.payment,
        counterparty: isLent
            ? 'Pelunasan piutang: ${bon.person}'
            : 'Pelunasan bon: ${bon.person}',
        accountId: accountId,
        categoryId: categoryId,
        occurredAt: date,
      );

      await updateBon(
        bonId,
        BonsCompanion(
          amount: Value(amount),
          accountId: Value(accountId),
          categoryId: Value(categoryId),
          settledAt: Value(date),
          settlementTransactionId: Value(txId),
        ),
      );

      return txId;
    });
  }

  /// Batal lunas: putuskan tautan dan hapus transaksi pelunasan yang tercipta.
  Future<void> unsettleBon(int bonId) async {
    return _db.transaction(() async {
      final bon = await (_db.select(
        _db.bons,
      )..where((b) => b.id.equals(bonId))).getSingle();
      final txId = bon.settlementTransactionId;
      await updateBon(
        bonId,
        const BonsCompanion(
          settledAt: Value(null),
          settlementTransactionId: Value(null),
        ),
      );
      if (txId != null) {
        await (_db.delete(
          _db.transactions,
        )..where((t) => t.id.equals(txId))).go();
      }
    });
  }

  /// Hapus bon. Jika bon sudah lunas dan deleteLinkedTx == true, transaksi pelunasan
  /// ikut dihapus; jika false (default), transaksi pelunasan tetap dipertahankan.
  Future<void> deleteBon(int id, {bool deleteLinkedTx = false}) async {
    return _db.transaction(() async {
      final bon = await (_db.select(
        _db.bons,
      )..where((b) => b.id.equals(id))).getSingleOrNull();
      final txId = bon?.settlementTransactionId;
      await (_db.delete(_db.bons)..where((b) => b.id.equals(id))).go();
      if (txId != null && deleteLinkedTx) {
        await (_db.delete(
          _db.transactions,
        )..where((t) => t.id.equals(txId))).go();
      }
    });
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
  /// terhapus).
  Future<void> deleteAccount(int id) async {
    await (_db.update(_db.transactions)..where((t) => t.accountId.equals(id)))
        .write(const TransactionsCompanion(accountId: Value(null)));
    await (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
  }

  /// Tulis log mentah sekali — konten identik (paket+judul+isi) dalam
  /// jendela dedup tidak ditulis dua kali, melindungi dari pemrosesan
  /// ganda drain+stream. [ignoredDup] memisahkan jenis penanda.
  Future<void> _logCaptureOnce(
    RawCapture raw, {
    required bool parsed,
    bool ignoredDup = false,
  }) async {
    final from = raw.postedAt.subtract(dedupWindow);
    final to = raw.postedAt.add(dedupWindow);
    final dup =
        await (_db.select(_db.captureLogs)
              ..where(
                (c) =>
                    c.ignoredDup.equals(ignoredDup) &
                    c.packageName.equals(raw.packageName) &
                    c.title.equals(raw.title) &
                    c.body.equals(raw.body) &
                    c.postedAt.isBetweenValues(from, to),
              )
              ..limit(1))
            .getSingleOrNull();
    if (dup != null) return;
    await _db
        .into(_db.captureLogs)
        .insert(
          CaptureLogsCompanion.insert(
            packageName: raw.packageName,
            title: raw.title,
            body: raw.body,
            postedAt: raw.postedAt,
            parsed: parsed,
            ignoredDup: Value(ignoredDup),
          ),
        );
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
