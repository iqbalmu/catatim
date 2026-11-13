import 'package:flutter/services.dart';

/// Jembatan ke lapisan native Android (MainActivity.kt →
/// BudgetNotifier): menampilkan notifikasi lokal peringatan batas.
/// Native hanya transport (ADR-012) — keputusan kirim ada di
/// BudgetAlertService.
class NotifyChannel {
  const NotifyChannel();

  static const _method = MethodChannel('catatim/notify');

  /// Notifikasi boleh tampil: izin app aktif dan channel tidak
  /// dimatikan user. Plugin belum terdaftar (mis. hot restart) → false.
  Future<bool> canPost() async {
    try {
      return await _method.invokeMethod<bool>('canPost') ?? false;
    } on Exception {
      return false;
    }
  }

  /// True bila butuh dialog runtime POST_NOTIFICATIONS (Android 13+).
  Future<bool> needsRuntimePermission() async {
    try {
      return await _method.invokeMethod<bool>('needsRuntimePermission') ??
          false;
    } on Exception {
      return false;
    }
  }

  /// Minta izin tampil notifikasi; resolve true bila diberikan.
  Future<bool> requestPermission() async {
    try {
      return await _method.invokeMethod<bool>('requestPermission') ?? false;
    } on Exception {
      return false;
    }
  }

  /// Buka pengaturan notifikasi app — jalur pemulihan saat user menolak
  /// permanen atau mematikan channel.
  Future<void> openAppNotificationSettings() async {
    try {
      await _method.invokeMethod<void>('openAppNotificationSettings');
    } on Exception {
      // Perangkat tanpa layar ini (jarang) — cukup diam.
    }
  }

  /// Tampilkan notifikasi peringatan batas. Satu id tetap → peringatan
  /// baru menggantikan yang lama di tray, tidak menumpuk. Gagal tampil
  /// tidak boleh menggagalkan pencatatan transaksi.
  Future<void> showBudgetAlert({
    required String title,
    required String body,
  }) async {
    try {
      await _method.invokeMethod<void>('show', {
        'title': title,
        'body': body,
      });
    } on Exception {
      // Diam.
    }
  }
}
