import 'package:flutter/foundation.dart';

import '../core/money.dart';
import '../models.dart';
import '../storage/repository.dart';
import 'notify_channel.dart';

/// Penjadwal notifikasi lokal (Tahap A): menghitung jadwal pengingat harian
/// dan jatuh tempo bon saat aplikasi dibuka atau pengaturan/bon berubah,
/// lalu mendaftarkannya ke AlarmManager via [NotifyChannel].
class ReminderScheduler {
  ReminderScheduler({
    required LedgerRepository repository,
    NotifyChannel? channel,
    DateTime Function()? now,
  }) : _repo = repository,
       _channel = channel ?? const NotifyChannel(),
       _now = now ?? DateTime.now;

  static const dailyReminderId = 3001;
  static const bonReminderIdBase = 40000;

  final LedgerRepository _repo;
  final NotifyChannel _channel;
  final DateTime Function() _now;

  /// Sinkronkan seluruh jadwal pengingat (harian + jatuh tempo bon) dengan
  /// state terbaru di database. Aman dipanggil berulang kali.
  Future<void> sync() async {
    try {
      final now = _now();
      await _syncDaily(now);
      await _syncBons(now);
    } on Exception catch (e) {
      debugPrint('ReminderScheduler.sync: $e');
    }
  }

  Future<void> _syncDaily(DateTime now) async {
    final enabled = await _repo.dailyReminderEnabled();
    if (!enabled) {
      await _channel.cancelNotification(dailyReminderId);
      return;
    }

    final minutes = await _repo.dailyReminderMinutes();
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }

    final draftCount = (await _repo.watchDrafts().first).length;
    final body = draftCount > 0
        ? 'Ada $draftCount draf menunggu di inbox — yuk cek sebentar.'
        : 'Sudah catat pengeluaran hari ini? Ketuk untuk buka CatatIM.';

    await _channel.scheduleNotification(
      id: dailyReminderId,
      scheduledAt: target,
      title: 'Waktunya cek catatan hari ini',
      body: body,
    );
  }

  Future<void> _syncBons(DateTime now) async {
    final prevIds = await _repo.scheduledBonReminderIds();
    final enabled = await _repo.bonReminderEnabled();
    if (!enabled) {
      for (final id in prevIds) {
        await _channel.cancelNotification(id);
      }
      if (prevIds.isNotEmpty) {
        await _repo.setScheduledBonReminderIds(const []);
      }
      return;
    }

    final bons = await _repo.getBons();
    final activeIds = <int>[];

    for (final bon in bons) {
      if (bon.settledAt != null || bon.dueDate == null) continue;
      final due = bon.dueDate!;
      final dueMorning = DateTime(due.year, due.month, due.day, 9);
      final dayBefore = dueMorning.subtract(const Duration(days: 1));

      DateTime? trigger;
      var isDayBefore = false;
      if (dayBefore.isAfter(now)) {
        trigger = dayBefore;
        isDayBefore = true;
      } else if (dueMorning.isAfter(now)) {
        trigger = dueMorning;
      }
      if (trigger == null) continue;

      final notifId = bonReminderIdBase + bon.id;
      activeIds.add(notifId);

      final kindLabel = bon.direction == BonDirection.lent
          ? 'Piutang'
          : 'Utang';
      final title = isDayBefore
          ? 'Besok jatuh tempo: ${bon.person}'
          : 'Hari ini jatuh tempo: ${bon.person}';
      final body = bon.amount > 0
          ? '$kindLabel ${Money.format(bon.amount)}'
          : '$kindLabel dengan ${bon.person}';

      await _channel.scheduleNotification(
        id: notifId,
        scheduledAt: trigger,
        title: title,
        body: body,
      );
    }

    final activeSet = activeIds.toSet();
    for (final oldId in prevIds) {
      if (!activeSet.contains(oldId)) {
        await _channel.cancelNotification(oldId);
      }
    }
    await _repo.setScheduledBonReminderIds(activeIds);
  }
}
