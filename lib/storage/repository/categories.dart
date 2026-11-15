part of '../repository.dart';

// SECTION: categories.dart
extension CategoriesRepo on LedgerRepository {
  Stream<List<Category>> watchCategories() {
    return (_db.select(_db.categories)
          ..orderBy([(c) => OrderingTerm.asc(c.id)]))
        .watch()
        .map((cats) => [...cats]..sort(LedgerRepository.categoryDisplayOrder));
  }

  Future<List<Category>> getCategories() async {
    final cats = await _db.select(_db.categories).get();
    return [...cats]..sort(LedgerRepository.categoryDisplayOrder);
  }

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
    final name = LedgerRepository._kindCategoryName[kind]!;
    final row = await (_db.select(
      _db.categories,
    )..where((c) => c.name.equals(name))).getSingleOrNull();
    return row?.id;
  }

  /// Kategori yang disukai untuk [counterparty]/[rawText] tertentu.
  /// Urutan keputusan:
  /// 1. Riwayat transaksi dengan counterparty persis (case-insensitive).
  /// 2. Vote kata kunci: token signifikan dari counterparty atau isi
  ///    notifikasi ([rawText]) dicocokkan ke teks transaksi tercatat;
  ///    kategori dengan suara terbanyak menang, seri dipecahkan yang
  ///    terbaru. Inilah yang membuat kategori otomatis makin pas —
  ///    koreksi user sebelumnya menjadi sinyal belajarnya.
  /// 3. Default kategori dari [kind].
  Future<int?> preferredCategoryId({
    String? counterparty,
    String? rawText,
    TxKind? kind,
    Direction? direction,
  }) async {
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
    final votedCategoryId = await _voteCategoryId(clean, rawText, direction);
    if (votedCategoryId != null) return votedCategoryId;
    if (kind != null) {
      return _defaultCategoryId(kind);
    }
    return null;
  }

  /// Batas pemindaian kandidat vote — cukup untuk pola belanja personal,
  /// lebih tua dari ini dianggap tidak lagi mewakili kebiasaan.
  static const _voteScanLimit = 300;

  /// Kata umum notifikasi bank & nama bank/dompet: muncul di hampir semua
  /// notifikasi sehingga tidak membedakan penjual — buang dari token vote.
  static const _voteStopwords = {
    // Kata umum isi notifikasi bank.
    'transfer', 'berhasil', 'pembayaran', 'pembelian', 'qris',
    'payment', 'payments', 'bayar', 'beli', 'debit', 'kredit', 'saldo',
    'dana', 'masuk', 'keluar', 'mutasi', 'transaksi', 'notif', 'info',
    'informasi', 'topup', 'top', 'up', 'isi', 'briva', 'virtual', 'account',
    'number', 'no', 'ref', 'refno', 'akun', 'rekening', 'kamu', 'anda',
    'kami', 'kita', 'dari', 'untuk', 'dengan', 'yang', 'the', 'and', 'your',
    'with', 'date', 'time',
    // Nama bank/dompet katalog — identitas sumber, bukan penjual.
    'bca', 'bcadigital', 'bri', 'bni', 'blu', 'blusaving', 'ovo', 'gopay',
    'shopeepay', 'shopee', 'linkaja', 'jenius', 'seabank', 'mandiri', 'bsi',
    'cimb', 'niaga', 'nagari', 'jago',
  };

  /// Token kata kunci signifikan dari teks bebas: lowercase, buang angka
  /// murni (nominal/rekening/OTP), kata pendek, dan kata umum.
  static List<String> _voteTokens(Iterable<String> texts) {
    final tokens = <String>{};
    for (final text in texts) {
      for (final word in text.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
        if (word.length < 3) continue;
        if (int.tryParse(word) != null) continue;
        if (_voteStopwords.contains(word)) continue;
        tokens.add(word);
      }
    }
    return tokens.toList(growable: false);
  }

  /// Pemenang vote kategori dari token kata kunci, null bila tidak ada
  /// transaksi tercatat yang cocok.
  Future<int?> _voteCategoryId(
    String? counterparty,
    String? rawText,
    Direction? direction,
  ) async {
    // counterparty diprioritaskan; isi notifikasi hanya dipakai bila
    // counterparty kosong (mis. draf QRIS tanpa nama penjual).
    final source = (counterparty != null && counterparty.isNotEmpty)
        ? counterparty
        : rawText ?? '';
    final tokens = _voteTokens([source]);
    if (tokens.isEmpty) return null;
    final rows =
        await (_db.select(_db.transactions)
              ..where(
                (t) =>
                    t.categoryId.isNotNull() &
                    (direction == null
                        ? const Constant(true)
                        : t.direction.equalsValue(direction)) &
                    Expression.or([
                      for (final keyword in tokens)
                        t.counterparty.like('%$keyword%') |
                            t.rawTitle.like('%$keyword%') |
                            t.rawBody.like('%$keyword%'),
                    ]),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
              ..limit(_voteScanLimit))
            .get();
    if (rows.isEmpty) return null;
    // Suara terbanyak menang; seri dipecahkan kategori yang paling
    // akhir dipakai (rows sudah urut terbaru dulu).
    final votes = <int, int>{};
    for (final row in rows) {
      final catId = row.categoryId!;
      votes[catId] = (votes[catId] ?? 0) + 1;
    }
    var best = rows.first.categoryId!;
    for (final entry in votes.entries) {
      if (entry.value > votes[best]!) best = entry.key;
    }
    return best;
  }

  // --- kategori -----------------------------------------------------------------

  /// Ubah nama kategori; melempar bila nama sudah dipakai (unique).
  Future<void> renameCategory(int id, String name) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(name: Value(name.trim())),
    );
  }

  /// Hapus kategori: transaksinya dipindah ke kategori [fallbackId]
  /// (biasanya "Lainnya"), alokasinya ikut terhapus, dan filter kategori
  /// pada scope batas ikut dibersihkan.
  ///
  /// Audit C-1: keempat langkah harus atomik — crash di tengah jalan
  /// (mis. transaksi sudah pindah tapi kategori masih ada) meninggalkan
  /// data konsisten-parsial.
  Future<void> deleteCategory(int id, {required int fallbackId}) {
    if (id == fallbackId) throw ArgumentError('tidak boleh hapus fallback');
    return _db.transaction(() async {
      await (_db.update(_db.transactions)
            ..where((t) => t.categoryId.equals(id)))
          .write(TransactionsCompanion(categoryId: Value(fallbackId)));
      await (_db.delete(
        _db.budgets,
      )..where((b) => b.categoryId.equals(id))).go();
      await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
      await _removeCategoryFromLimitScopes(id);
    });
  }
}
