import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../notify/notify_channel.dart';
import '../notify/reminder_scheduler.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Lembar pengaturan pengingat terjadwal: pengingat catat harian (jam bisa
/// dipilih) dan pengingat jatuh tempo bon (H-1 / hari-H pukul 09:00).
class ReminderSheet extends StatefulWidget {
  const ReminderSheet({super.key, required this.repository});

  final LedgerRepository repository;

  static Future<void> show(BuildContext context, LedgerRepository repository) {
    return showQuestSheet<void>(
      context,
      (ctx) => ReminderSheet(repository: repository),
    );
  }

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  static const _channel = NotifyChannel();

  bool _loading = true;
  bool _dailyEnabled = false;
  bool _bonEnabled = true;
  bool _canPost = true;
  int _dailyMinutes = LedgerRepository.defaultDailyReminderMinutes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final daily = await widget.repository.dailyReminderEnabled();
    final minutes = await widget.repository.dailyReminderMinutes();
    final bon = await widget.repository.bonReminderEnabled();
    final canPost = await _channel.canPost();
    if (!mounted) return;
    setState(() {
      _dailyEnabled = daily;
      _dailyMinutes = minutes;
      _bonEnabled = bon;
      _canPost = canPost;
      _loading = false;
    });
  }

  Future<void> _ensurePermissionIfNeeded(bool on) async {
    if (!on) return;
    var granted = await _channel.canPost();
    if (!granted) {
      granted = await _channel.requestPermission();
    }
    if (mounted) setState(() => _canPost = granted);
  }

  Future<void> _sync() => ReminderScheduler(repository: widget.repository).sync();

  Future<void> _toggleDaily(bool on) async {
    unawaited(HapticFeedback.selectionClick());
    await widget.repository.setDailyReminderEnabled(on);
    if (mounted) setState(() => _dailyEnabled = on);
    await _ensurePermissionIfNeeded(on);
    await _sync();
  }

  Future<void> _toggleBon(bool on) async {
    unawaited(HapticFeedback.selectionClick());
    await widget.repository.setBonReminderEnabled(on);
    if (mounted) setState(() => _bonEnabled = on);
    await _ensurePermissionIfNeeded(on);
    await _sync();
  }

  Future<void> _pickTime() async {
    final initial = TimeOfDay(
      hour: _dailyMinutes ~/ 60,
      minute: _dailyMinutes % 60,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    await widget.repository.setDailyReminderMinutes(minutes);
    if (mounted) setState(() => _dailyMinutes = minutes);
    await _sync();
  }

  String _formatTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.m,
        ),
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pengingat Terjadwal',
                          style: context.qTitle(18),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Text(
                    'Jadwal dihitung lokal saat aplikasi dibuka.',
                    style: context.qSmall().copyWith(color: q.muted),
                  ),
                  const SizedBox(height: Spacing.m),
                  QuestCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        QuestListTile(
                          leading: Icon(
                            Icons.alarm_rounded,
                            color: q.primary,
                          ),
                          title: Text(
                            'Pengingat catat harian',
                            style: context.qTitle(14.5),
                          ),
                          subtitle: Text(
                            'Ingatkan cek catatan & draf tiap hari.',
                            style: context.qSmall(11.5).copyWith(
                              color: q.muted,
                            ),
                          ),
                          trailing: QuestSwitch(
                            value: _dailyEnabled,
                            label: 'Pengingat catat harian',
                            onChanged: _toggleDaily,
                          ),
                        ),
                        if (_dailyEnabled) ...[
                          Divider(height: 1, color: q.line),
                          QuestListTile(
                            leading: Icon(
                              Icons.schedule_rounded,
                              color: q.muted,
                            ),
                            title: Text(
                              'Jam pengingat',
                              style: context.qBody(),
                            ),
                            trailing: Row(
                              children: [
                                Text(
                                  _formatTime(_dailyMinutes),
                                  style: context.qTitle(14).copyWith(
                                    color: q.primary,
                                  ),
                                ),
                                const SizedBox(width: Spacing.xs),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: q.muted,
                                ),
                              ],
                            ),
                            onTap: _pickTime,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.s),
                  QuestCard(
                    padding: EdgeInsets.zero,
                    child: QuestListTile(
                      leading: Icon(
                        Icons.event_note_rounded,
                        color: q.primary,
                      ),
                      title: Text(
                        'Jatuh tempo bon',
                        style: context.qTitle(14.5),
                      ),
                      subtitle: Text(
                        'Notifikasi H-1 atau hari-H pukul 09:00.',
                        style: context.qSmall(11.5).copyWith(color: q.muted),
                      ),
                      trailing: QuestSwitch(
                        value: _bonEnabled,
                        label: 'Jatuh tempo bon',
                        onChanged: _toggleBon,
                      ),
                    ),
                  ),
                  if ((_dailyEnabled || _bonEnabled) && !_canPost) ...[
                    const SizedBox(height: Spacing.s),
                    Container(
                      padding: const EdgeInsets.all(Spacing.m),
                      decoration: BoxDecoration(
                        color: q.warnTint,
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Izin notifikasi belum aktif',
                            style: context.qTitle(14),
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            'Pengingat tidak bisa muncul sebelum izin notifikasi '
                            'diaktifkan di pengaturan Android.',
                            style: context.qSmall(),
                          ),
                          const SizedBox(height: Spacing.s),
                          QuestButton(
                            label: 'Buka Pengaturan Izin',
                            tone: QuestTone.secondary,
                            onPressed: _channel.openAppNotificationSettings,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
