import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Jembatan ke AppWidgetProvider Android (`catatim/widget`): memperbarui
/// tampilan ringkas di home screen dan membaca aksi tombol cepat `+ Catat`.
class WidgetChannel {
  const WidgetChannel();

  static const _method = MethodChannel('catatim/widget');

  Future<void> updateWidget({
    required String headline,
    required String primaryAmount,
    required String secondaryInfo,
    String mood = 'happy',
    bool isOver = false,
  }) async {
    try {
      await _method.invokeMethod<void>('updateWidget', {
        'headline': headline,
        'primaryAmount': primaryAmount,
        'secondaryInfo': secondaryInfo,
        'mood': mood,
        'isOver': isOver,
      });
    } on Exception catch (e) {
      if (e is! MissingPluginException) {
        debugPrint('WidgetChannel.updateWidget: $e');
      }
    }
  }

  Future<String?> consumePendingAction() async {
    try {
      return await _method.invokeMethod<String>('consumePendingAction');
    } on Exception {
      return null;
    }
  }
}
