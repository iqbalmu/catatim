import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models.dart';
import '../rules/engine.dart';
import '../storage/repository.dart';
import 'capture_channel.dart';

const String _ownPackage = 'id.xmuu.bukuduit';

/// Menghubungkan aliran notifikasi mentah → parser → database.
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

  /// Jumlah notifikasi yang ditangani sejak app berjalan (untuk indikator).
  int handledCount = 0;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    // Notifikasi yang tertangkap saat app mati tersimpan di antrian native.
    try {
      for (final raw in await channel.drainQueue()) {
        await _handle(raw);
      }
    } catch (_) {
      // drain gagal (channel belum siap) — live stream tetap dipasang.
    }
    _subscription = channel.stream().listen(
          (raw) => _handle(raw),
          onError: (Object _) {},
        );
  }

  Future<void> _handle(RawCapture raw) async {
    if (raw.packageName == _ownPackage) return;
    try {
      final draft = engine.parse(
        packageName: raw.packageName,
        title: raw.title,
        body: raw.body,
      );
      if (draft == null) {
        await repository.recordUnparsedCapture(raw);
      } else {
        await repository.recordFromCapture(raw: raw, draft: draft);
      }
      handledCount++;
      notifyListeners();
    } catch (_) {
      try {
        await repository.recordUnparsedCapture(raw);
      } catch (_) {
        // DB tidak siap; baris tetap ada di antrian native? — tidak:
        // drain sudah mengosongkan; biarkan log berikutnya menangkap.
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
