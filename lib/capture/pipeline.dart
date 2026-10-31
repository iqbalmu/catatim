import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models.dart';
import '../rules/engine.dart';
import '../rules/rule_set.dart' show BankRules;
import '../storage/repository.dart';
import 'capture_channel.dart';

const String _ownPackage = 'id.xmuu.bukuduit';

/// Menghubungkan aliran notifikasi mentah → parser → draf.
///
/// Model "hubungkan bank": hanya notifikasi dari bank/e-wallet yang sedang
/// terhubung yang diproses; hasilnya disimpan sebagai DRAF menunggu
/// keputusan user — tidak pernah auto-catat. Sisanya diabaikan diam-diam.
class CapturePipeline extends ChangeNotifier {
  CapturePipeline({
    required this.channel,
    required this.engine,
    required this.repository,
  });

  final CaptureChannel channel;
  final RuleEngine engine;
  final LedgerRepository repository;

  StreamSubscription<RawCapture>? _subscription;
  bool _started = false;

  /// Antrean pemrosesan berurutan — notifikasi yang tiba nyaris
  /// bersamaan (drain + stream) tidak boleh balapan menulis DB.
  Future<void> _tail = Future<void>.value();

  /// Jumlah notifikasi yang ditangani sejak app berjalan (untuk indikator).
  int handledCount = 0;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    // Allowlist didorong lebih dulu: notifikasi non-bank yang tiba
    // setelah ini tidak lagi disimpan native ke disk.
    await syncAllowedPackages();
    // Notifikasi yang tertangkap saat app mati tersimpan di antrian native.
    try {
      for (final raw in await channel.drainQueue()) {
        _submit(raw);
      }
      await _tail;
    } catch (_) {
      // drain gagal (channel belum siap) — live stream tetap dipasang.
    }
    _subscription = channel.stream().listen(_submit, onError: (Object _) {});
  }

  /// Antrekan pemrosesan satu notifikasi — bergiliran, agar cek dedup
  /// lalu simpan tidak balapan dengan notifikasi lain.
  void _submit(RawCapture raw) {
    _tail = _tail.then((_) => _handle(raw));
  }

  Future<void> _handle(RawCapture raw) async {
    if (raw.packageName == _ownPackage) return;
    try {
      // Mode belajar: yang diproses = bank katalog terhubung ATAU app
      // custom yang dihubungkan user; selebihnya diabaikan diam-diam.
      final connected = await repository.connectedBankIds();
      final customs = await repository.customBanks();
      if (connected.isEmpty && customs.isEmpty) return;
      final bank = _detectConnected(raw, connected);
      String? customLabel;
      for (final c in customs) {
        if (c.package == raw.packageName) customLabel = c.label;
      }
      if (bank == null && customLabel == null) return;

      if (bank != null &&
          !engine.packageNamesFor(connected).contains(raw.packageName)) {
        // Bank terdeteksi lewat keyword tapi paketnya asing — pelajari
        // paketnya agar notifikasi berikutnya ikut diantrikan ke disk
        // saat app mati (mis. bank tanpa packageNames di katalog).
        await channel.learnBankPackage(raw.packageName);
      }

      ParsedDraft? draft;
      if (bank != null) {
        draft = engine.parse(
          packageName: raw.packageName,
          title: raw.title,
          body: raw.body,
        );
      }
      if (draft != null && connected.contains(draft.bankId)) {
        await repository.addDraftFromCapture(raw: raw, draft: draft);
      } else {
        // Format belum dikenal rule — TETAP jadi draf mentah yang
        // menunggu keputusan user (isi nominal/kategori saat konfirmasi),
        // baik dari bank katalog maupun app custom.
        final guess = engine.guess(raw.title, raw.body);
        await repository.addRawDraftFromCapture(
          raw: raw,
          bankId: draft?.bankId ?? bank?.id ?? 'app:${raw.packageName}',
          bankName: customLabel ?? bank?.displayName ?? '',
          amount: guess.amount ?? 0,
          direction: guess.direction,
        );
      }
      handledCount++;
      notifyListeners();
    } catch (_) {
      try {
        await repository.recordUnparsedCapture(raw);
      } catch (_) {
        // DB tidak siap; biarkan capture berikutnya menangkap.
      }
    }
  }

  /// Bank yang terhubung dan cocok dengan notifikasi ini (via package atau
  /// kata kunci), atau null bila tak relevan.
  BankRules? _detectConnected(RawCapture raw, Set<String> connected) {
    final lower = '${raw.title} ${raw.body}'.toLowerCase();
    return engine.bankFor(
      packageName: raw.packageName,
      lowerText: lower,
      onlyIds: connected,
    );
  }

  /// Susun dan dorong daftar paket yang boleh diantrikan native ke
  /// disk: paket katalog bank terhubung + app custom mode belajar
  /// (paket belajar keyword ditambahkan native sendiri dan bertahan
  /// antar proses). Dipanggil saat start dan setiap koneksi berubah.
  Future<void> syncAllowedPackages() async {
    final connected = await repository.connectedBankIds();
    final customs = await repository.customBanks();
    await channel.setAllowedPackages({
      ...engine.packageNamesFor(connected),
      for (final c in customs) c.package,
    });
  }

  /// Memproses teks manual (tempel notifikasi/SMS/email/OCR) menjadi draf.
  /// Mencoba parsing dengan engine; bila format tak dikenal, menjadi draf mentah.
  Future<bool> submitPastedText(String text, {String? sourceLabel}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    final lines = trimmed.split('\n');
    final title = lines.first.trim();
    final body = lines.length > 1 ? lines.skip(1).join(' ').trim() : title;

    final raw = RawCapture(
      packageName: 'manual.paste',
      title: title.isEmpty ? (sourceLabel ?? 'Tempelan') : title,
      body: body.isEmpty ? title : body,
      postedAt: DateTime.now(),
    );

    final draft = engine.parse(
      packageName: '',
      title: raw.title,
      body: raw.body,
    );

    if (draft != null) {
      await repository.addDraftFromCapture(raw: raw, draft: draft);
    } else {
      final guess = engine.guess(raw.title, raw.body);
      await repository.addRawDraftFromCapture(
        raw: raw,
        bankId: 'paste',
        bankName: sourceLabel ?? 'Tempelan / Struk',
        amount: guess.amount ?? 0,
        direction: guess.direction,
      );
    }
    handledCount++;
    notifyListeners();
    return true;
  }

  /// Tambahkan draf manual (mis. hasil konfirmasi OCR) dengan nominal & arah yang ditentukan.
  Future<bool> submitManualDraft({
    required String title,
    required String body,
    required int amount,
    required Direction direction,
    String? bankId,
    String? bankName,
  }) async {
    final raw = RawCapture(
      packageName: 'manual.ocr',
      title: title.isEmpty ? 'Struk / Bukti' : title,
      body: body.isEmpty ? title : body,
      postedAt: DateTime.now(),
    );
    await repository.addRawDraftFromCapture(
      raw: raw,
      bankId: bankId ?? 'paste',
      bankName: bankName ?? title,
      amount: amount,
      direction: direction,
    );
    handledCount++;
    notifyListeners();
    return true;
  }

  /// Tarik notifikasi yang saat ini masih aktif di status bar sistem Android.
  Future<int> pullActiveNotifications() async {
    try {
      final active = await channel.getActiveNotifications();
      if (active.isEmpty) return 0;
      for (final raw in active) {
        _submit(raw);
      }
      await _tail;
      return active.length;
    } catch (_) {
      return 0;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
