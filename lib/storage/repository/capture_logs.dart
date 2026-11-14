part of '../repository.dart';

// SECTION: capture_logs.dart
extension CaptureLogsRepo on LedgerRepository {
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

  /// Tulis log mentah sekali — konten identik (paket+judul+isi) dalam
  /// jendela dedup tidak ditulis dua kali, melindungi dari pemrosesan
  /// ganda drain+stream. [ignoredDup] memisahkan jenis penanda.
  Future<void> _logCaptureOnce(
    RawCapture raw, {
    required bool parsed,
    bool ignoredDup = false,
  }) async {
    final from = raw.postedAt.subtract(LedgerRepository.dedupWindow);
    final to = raw.postedAt.add(LedgerRepository.dedupWindow);
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
}
