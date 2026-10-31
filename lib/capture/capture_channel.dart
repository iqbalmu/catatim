import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../models.dart';

/// Jembatan ke lapisan native Android (MainActivity.kt).
class CaptureChannel {
  const CaptureChannel();

  static const _method = MethodChannel('bukuduit/capture');
  static const _events = EventChannel('bukuduit/capture_events');

  /// Apakah user sudah memberi akses notifikasi untuk app ini.
  Future<bool> isListenerEnabled() async {
    try {
      return await _method.invokeMethod<bool>('isListenerEnabled') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openListenerSettings() async {
    await _method.invokeMethod<void>('openListenerSettings');
  }
  /// Kirim daftar paket bank terhubung — native hanya menulis notifikasi
  /// dari paket ini (plus paket yang sudah dipelajari) ke antrean disk.
  /// Gagal senyap: antrean kosong lebih aman daripada antrean bocor.
  Future<void> setAllowedPackages(Set<String> packages) async {
    try {
      await _method.invokeMethod<void>(
        'setAllowedPackages',
        packages.toList(),
      );
    } on PlatformException {
      // diabaikan — bukan platform yang didukung
    }
  }

  /// Catat paket yang ternyata milik bank terhubung (dicocokkan lewat
  /// keyword) agar notifikasi paket ini ikut diantrikan di disk.
  Future<void> learnBankPackage(String packageName) async {
    try {
      await _method.invokeMethod<void>('learnBankPackage', packageName);
    } on PlatformException {
      // diabaikan — bukan platform yang didukung
    }
  }

  /// Buka pengaturan optimisasi baterai (penting untuk vendor agresif
  /// seperti vivo/Funtouch yang mematikan listener latar belakang).
  Future<void> openBatterySettings() async {
    await _method.invokeMethod<void>('openBatterySettings');
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
    } on PlatformException {
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

/// Parse satu JSON line notifikasi; null bila baris korup.
RawCapture? tryParseCaptureLine(String line) {
  try {
    return RawCapture.fromLine(line);
  } catch (_) {
    return null;
  }
}

/// Parse semua baris antrean; baris korup dilewati, sisanya diproses.
List<RawCapture> parseCaptureLines(List<String> lines) => [
      for (final line in lines) ?tryParseCaptureLine(line),
    ];
