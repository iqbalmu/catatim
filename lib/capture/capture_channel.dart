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

  /// Buka pengaturan optimisasi baterai (penting untuk vendor agresif
  /// seperti vivo/Funtouch yang mematikan listener latar belakang).
  Future<void> openBatterySettings() async {
    await _method.invokeMethod<void>('openBatterySettings');
  }

  /// Ambil notifikasi yang tertangkap saat app tidak berjalan, lalu
  /// antrian native dikosongkan.
  Future<List<RawCapture>> drainQueue() async {
    try {
      final lines = await _method.invokeMethod<List<dynamic>>('drainQueue');
      return [
        for (final line in lines ?? const <dynamic>[]) RawCapture.fromLine(line as String),
      ];
    } on PlatformException {
      return const [];
    }
  }

  /// Notifikasi baru secara live (JSON line dari native).
  Stream<RawCapture> stream() => _events
      .receiveBroadcastStream()
      .map((event) => RawCapture.fromLine(event as String));
}

/// encode JSON line — dipakai native; util ini untuk test.
String encodeCaptureLine(RawCapture capture) => jsonEncode({
      'packageName': capture.packageName,
      'title': capture.title,
      'body': capture.body,
      'postedAt': capture.postedAt.millisecondsSinceEpoch,
    });
