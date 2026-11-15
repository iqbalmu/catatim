import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models.dart';

/// Jembatan ke lapisan native Android (MainActivity.kt).
class CaptureChannel {
  const CaptureChannel();

  static const _method = MethodChannel('catatim/capture');
  static const _events = EventChannel('catatim/capture_events');

  /// Nilai default tetap dikembalikan; penyebabnya terlihat di console.
  /// MissingPluginException diabaikan (runner non-Android / unit test).
  static void _log(String where, Object error) {
    if (error is MissingPluginException) return;
    debugPrint('CaptureChannel.$where: $error');
  }

  /// Apakah user sudah memberi akses notifikasi untuk app ini.
  Future<bool> isListenerEnabled() async {
    try {
      return await _method.invokeMethod<bool>('isListenerEnabled') ?? false;
    } catch (e) {
      _log('isListenerEnabled', e);
      return false;
    }
  }

  /// Timestamp terakhir listener aktif / menangkap notifikasi (ms sejak epoch).
  Future<DateTime?> getLastCaptureHeartbeat() async {
    try {
      final ms = await _method.invokeMethod<num>('getLastCaptureHeartbeat');
      if (ms == null || ms <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms.toInt());
    } catch (e) {
      _log('getLastCaptureHeartbeat', e);
      return null;
    }
  }

  Future<void> openListenerSettings() async {
    await _method.invokeMethod<void>('openListenerSettings');
  }

  /// Daftar app terpasang yang bisa dibuka (paket + label) — untuk
  /// menghubungkan app apa pun di Mode Belajar.
  Future<List<({String package, String label})>> listLaunchableApps() async {
    try {
      final rows = await _method.invokeMethod<List<dynamic>>(
        'listLaunchableApps',
      );
      return [
        for (final row in rows ?? const <dynamic>[])
          if (row is Map && row['package'] is String)
            (
              package: row['package'] as String,
              label: (row['label'] ?? '') as String,
            ),
      ];
    } catch (e) {
      _log('listLaunchableApps', e);
      return const [];
    }
  }

  /// Ambil notifikasi yang saat ini masih aktif/tayang di status bar Android.
  Future<List<RawCapture>> getActiveNotifications() async {
    try {
      final lines = await _method.invokeMethod<List<dynamic>>(
        'getActiveNotifications',
      );
      return parseCaptureLines([
        for (final line in lines ?? const <dynamic>[]) line as String,
      ]);
    } catch (e) {
      _log('getActiveNotifications', e);
      return const [];
    }
  }

  /// Ambil data teks atau file gambar yang dibagikan dari app lain (jika ada).
  Future<({String type, String? text, String? path})?>
  consumeSharedPayload() async {
    try {
      final map = await _method.invokeMapMethod<String, dynamic>(
        'consumeSharedPayload',
      );
      if (map == null) return null;
      final type = map['type'] as String?;
      if (type == null) return null;
      return (
        type: type,
        text: map['text'] as String?,
        path: map['path'] as String?,
      );
    } catch (e) {
      _log('consumeSharedPayload', e);
      return null;
    }
  }

  /// Kirim daftar paket bank terhubung — native hanya menulis notifikasi
  /// dari paket ini (plus paket yang sudah dipelajari) ke antrean disk.
  /// Gagal senyap: antrean kosong lebih aman daripada antrean bocor.
  Future<void> setAllowedPackages(Set<String> packages) async {
    try {
      await _method.invokeMethod<void>('setAllowedPackages', packages.toList());
    } catch (e) {
      // diabaikan — bukan platform yang didukung (_log memfilter
      // MissingPluginException); selain itu tercatat di debug console.
      _log('setAllowedPackages', e);
    }
  }

  /// Catat paket yang ternyata milik bank terhubung (dicocokkan lewat
  /// keyword) agar notifikasi paket ini ikut diantrikan di disk.
  Future<void> learnBankPackage(String packageName) async {
    try {
      await _method.invokeMethod<void>('learnBankPackage', packageName);
    } catch (e) {
      // diabaikan — bukan platform yang didukung (_log memfilter
      // MissingPluginException); selain itu tercatat di debug console.
      _log('learnBankPackage', e);
    }
  }

  /// Buka pengaturan optimisasi baterai (penting untuk vendor agresif
  /// seperti vivo/Funtouch yang mematikan listener latar belakang).
  Future<void> openBatterySettings() async {
    await _method.invokeMethod<void>('openBatterySettings');
  }

  /// Status riil pengecualian optimasi baterai dari PowerManager —
  /// bukan asumsi dari pernah membuka layar setting.
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _method
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
    } catch (e) {
      _log('isIgnoringBatteryOptimizations', e);
      return false;
    }
  }

  /// Dialog langsung Android "di luar optimasi baterai" untuk app ini —
  /// user tetap yang memutuskan di dialog sistem.
  Future<void> requestIgnoreBatteryOptimizations() async {
    await _method.invokeMethod<void>('requestIgnoreBatteryOptimizations');
  }

  /// Simulasikan notifikasi melalui lapisan native untuk pengujian end-to-end.
  Future<bool> simulateNotification({
    required String packageName,
    required String title,
    required String body,
    DateTime? postedAt,
  }) async {
    try {
      final res = await _method.invokeMethod<bool>('simulateNotification', {
        'packageName': packageName,
        'title': title,
        'body': body,
        'postedAt': (postedAt ?? DateTime.now()).millisecondsSinceEpoch,
      });
      return res ?? true;
    } catch (e) {
      _log('simulateNotification', e);
      return false;
    }
  }

  /// Ambil notifikasi yang tertangkap saat app tidak berjalan, lalu
  /// antrian native dikosongkan. Baris korup dilewati — satu baris
  /// rusak tidak boleh membuang seluruh antrean.
  Future<List<RawCapture>> drainQueue() async {
    try {
      final lines = await _method.invokeMethod<List<dynamic>>('drainQueue');
      return parseCaptureLines([
        for (final line in lines ?? const <dynamic>[]) line as String,
      ]);
    } catch (e) {
      _log('drainQueue', e);
      return const [];
    }
  }

  /// Notifikasi baru secara live (JSON line dari native). Baris korup
  /// dilewati diam-diam.
  Stream<RawCapture> stream() => _events
      .receiveBroadcastStream()
      .map((event) => tryParseCaptureLine(event as String))
      .where((c) => c != null)
      .cast<RawCapture>();
}

/// encode JSON line — dipakai native; util ini untuk test.
String encodeCaptureLine(RawCapture capture) => jsonEncode({
  'packageName': capture.packageName,
  'title': capture.title,
  'body': capture.body,
  'postedAt': capture.postedAt.millisecondsSinceEpoch,
});

/// Parse satu JSON line notifikasi; null bila korup (tercatat di console).
RawCapture? tryParseCaptureLine(String line) {
  try {
    return RawCapture.fromLine(line);
  } catch (e) {
    debugPrint('tryParseCaptureLine: baris korup dilewati: $e');
    return null;
  }
}

/// Parse semua baris antrean; baris korup dilewati, sisanya diproses.
List<RawCapture> parseCaptureLines(List<String> lines) => [
  for (final line in lines) ?tryParseCaptureLine(line),
];
