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
    // Notifikasi yang tertangkap saat app mati tersimpan di antrian native.
    try {
      for (final raw in await channel.drainQueue()) {
        _submit(raw);
      }
      await _tail;
    } catch (_) {
      // drain gagal (channel belum siap) — live stream tetap dipasang.
    }
    _subscription = channel.stream().listen(
      _submit,
      onError: (Object _) {},
    );
  }

  /// Antrekan pemrosesan satu notifikasi — bergiliran, agar cek dedup
  /// lalu simpan tidak balapan dengan notifikasi lain.
  void _submit(RawCapture raw) {
    _tail = _tail.then((_) => _handle(raw));
  }

  Future<void> _handle(RawCapture raw) async {
    if (raw.packageName == _ownPackage) return;
    try {
      // Hanya bank terhubung yang dibaca — selebihnya diabaikan diam-diam.
      final connected = await repository.connectedBankIds();
      if (connected.isEmpty) return;
      final bank = _detectConnected(raw, connected);
      if (bank == null) return;

      final draft = engine.parse(
        packageName: raw.packageName,
        title: raw.title,
        body: raw.body,
      );
      if (draft == null) {
        // Bank terhubung tapi isinya bukan transaksi yang dikenali —
        // catat mentah agar layar Notifikasi bisa menawarkan "baca ulang".
        await repository.recordUnparsedCapture(raw);
      } else if (connected.contains(draft.bankId)) {
        await repository.addDraftFromCapture(raw: raw, draft: draft);
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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
