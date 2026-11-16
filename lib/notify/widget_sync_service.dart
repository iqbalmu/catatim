import 'package:flutter/foundation.dart';

import '../core/money.dart';
import '../storage/repository.dart';
import 'widget_channel.dart';

/// Menghitung sisa jatah hari ini, pengeluaran hari ini, ekspresi mood maskot,
/// dan jumlah draf lalu mengirimkannya ke widget home screen Android.
/// Tidak mengirim total saldo demi privasi di layar utama.
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
  }) async {
    try {
      final now = _now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final spentToday = await _repo.sumSpendBetween(start, end);

      final draftCount = (await _repo.watchDrafts().first).length;
      final draftSuffix = draftCount > 0 ? ' · $draftCount draf' : '';

      final String headline;
      final String primaryAmount;
      final String secondaryInfo;
      final bool isOver;

      if (safeToSpend != null) {
        isOver = safeToSpend < 0;
        headline = isOver
            ? 'Melebihi jatah · ${moodLine ?? 'Waspada'}'
            : (moodLine?.isNotEmpty == true ? moodLine! : 'Sisa jatah hari ini');
        primaryAmount = isOver
            ? '-${Money.format(safeToSpend.abs())}'
            : Money.format(safeToSpend);
        secondaryInfo = 'Keluar: ${Money.format(spentToday)}$draftSuffix';
      } else {
        isOver = false;
        headline = moodLine?.isNotEmpty == true ? moodLine! : 'Keluar hari ini';
        primaryAmount = Money.format(spentToday);
        secondaryInfo = 'Belum atur batas harian$draftSuffix';
      }

      await _channel.updateWidget(
        headline: headline,
        primaryAmount: primaryAmount,
        secondaryInfo: secondaryInfo,
        mood: mood,
        isOver: isOver,
      );
    } on Exception catch (e) {
      debugPrint('WidgetSyncService.sync: $e');
    }
  }
}
