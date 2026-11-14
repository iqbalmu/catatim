part of '../repository.dart';

// SECTION: drafts.dart
extension DraftsRepo on LedgerRepository {
  // --- draf (model hubungkan bank) ------------------------------------------------

  /// Simpan hasil capture sebagai DRAF menunggu keputusan user.
  /// Mengembalikan id draf baru, atau null bila dianggap duplikat
  /// (sudah ada draf / transaksi se-bank+nominal+arah dalam jendela).
  Future<int?> addDraftFromCapture({
    required RawCapture raw,
    required ParsedDraft draft,
  }) {
    return _db.transaction(() async {
      final from = raw.postedAt.subtract(LedgerRepository.dedupWindow);
      final to = raw.postedAt.add(LedgerRepository.dedupWindow);
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

  /// - Tarik tunai keluar: buat kaki masuk di akun Tunai.
  /// - Transfer/top up: bila ada kaki lawan (nominal sama, arah berlawanan,
  ///   akun berbeda, dalam [LedgerRepository.linkWindow]) dari notifikasi, keduanya jadi
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
                        tx.occurredAt.subtract(LedgerRepository.linkWindow),
                        tx.occurredAt.add(LedgerRepository.linkWindow),
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
                    tx.occurredAt.subtract(LedgerRepository.linkWindow),
                    tx.occurredAt.add(LedgerRepository.linkWindow),
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
  /// jendela [LedgerRepository.dedupWindow] hanya jadi satu draf — nominal 0 dua kali tidak
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
      final from = raw.postedAt.subtract(LedgerRepository.dedupWindow);
      final to = raw.postedAt.add(LedgerRepository.dedupWindow);
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

}
