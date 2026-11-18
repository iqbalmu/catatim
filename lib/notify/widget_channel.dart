import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Jembatan ke AppWidgetProvider Android (`catatim/widget`): memperbarui
/// widget Companion ala Duolingo di home screen.
class WidgetChannel {
  const WidgetChannel();

  static const _method = MethodChannel('catatim/widget');

  Future<void> updateWidget({
    required String headline,
    required String compactHeadline,
    required String primaryAmount,
    required String secondaryInfo,
    required String draftChip,
    required String streakBadge,
    required int progressPercent,
    required String progressLabel,
    required bool hasProgress,
    String mood = 'happy',
    bool isOver = false,
  }) async {
    try {
      await _method.invokeMethod<void>('updateWidget', {
        'headline': headline,
        'compactHeadline': compactHeadline,
        'primaryAmount': primaryAmount,
        'secondaryInfo': secondaryInfo,
        'draftChip': draftChip,
        'streakBadge': streakBadge,
        'progressPercent': progressPercent,
        'progressLabel': progressLabel,
        'hasProgress': hasProgress,
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
