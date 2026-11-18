import 'package:flutter/foundation.dart';

import '../core/money.dart';
import '../storage/repository.dart';
import 'widget_channel.dart';

/// Mengirim ringkasan sisa jatah, kalimat mood, progress bar jatah harian,
/// pengeluaran hari ini, streak, dan chip draf ke widget home screen Android.
class WidgetSyncService {
  WidgetSyncService({
    required LedgerRepository repository,
    WidgetChannel? channel,
    DateTime Function()? now,
  }) : _repo = repository,
       _channel = channel ?? const WidgetChannel(),
       _now = now ?? DateTime.now;

  final LedgerRepository _repo;
  final WidgetChannel _channel;
  final DateTime Function() _now;

  Future<void> sync({
    int? safeToSpend,
    String? moodLine,
    String mood = 'happy',
    int streakDays = 0,
  }) async {
    try {
      final now = _now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final spentToday = await _repo.sumSpendBetween(start, end);

      final draftCount = (await _repo.watchDrafts().first).length;
      final draftChip = draftCount > 0 ? '$draftCount draf' : '';
      final streakBadge = streakDays > 0 ? '🔥 $streakDays' : '';

      final String primaryAmount;
      final String headline;
      final String compactHeadline;
      final String secondaryInfo;
      final bool isOver;
      final bool hasProgress;
      final int progressPercent;
      final String progressLabel;

      if (safeToSpend != null) {
        isOver = safeToSpend < 0;
        hasProgress = true;
        final totalTodayBudget = spentToday + safeToSpend;
        final rawPercent = totalTodayBudget > 0
            ? ((spentToday * 100) / totalTodayBudget).round()
            : (spentToday > 0 ? 100 : 0);
        progressPercent = rawPercent.clamp(0, 100);
        progressLabel = '$rawPercent%';

        primaryAmount = isOver
            ? '-${Money.format(safeToSpend.abs())}'
            : Money.format(safeToSpend);
        headline = moodLine?.isNotEmpty == true
            ? moodLine!
            : (isOver ? 'Melebihi jatah!' : 'Masih aman terkendali!');
        compactHeadline = 'Keluar ${Money.format(spentToday)}';
        secondaryInfo = 'Keluar ${Money.format(spentToday)}';
      } else {
        isOver = false;
        hasProgress = false;
        progressPercent = 0;
        progressLabel = '0%';
        primaryAmount = Money.format(spentToday);
        headline = moodLine?.isNotEmpty == true
            ? moodLine!
            : 'Keluar hari ini';
        compactHeadline = 'Keluar hari ini';
        secondaryInfo = 'Belum atur batas harian';
      }

      await _channel.updateWidget(
        headline: headline,
        compactHeadline: compactHeadline,
        primaryAmount: primaryAmount,
        secondaryInfo: secondaryInfo,
        draftChip: draftChip,
        streakBadge: streakBadge,
        progressPercent: progressPercent,
        progressLabel: progressLabel,
        hasProgress: hasProgress,
        mood: mood,
        isOver: isOver,
      );
    } on Exception catch (e) {
      debugPrint('WidgetSyncService.sync: $e');
    }
  }
}
