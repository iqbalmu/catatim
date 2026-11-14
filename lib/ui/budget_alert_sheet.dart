import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../notify/notify_channel.dart';
import '../storage/repository.dart';
import 'quest.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';

/// Lembar pengaturan peringatan batas pengeluaran: aktif/nonaktif,
/// persen ambang, dan status izin notifikasi (POST_NOTIFICATIONS,
/// Android 13+). Satu tempat kecil — tile di Profil & Pengaturan
/// cukup membuka ini.
class BudgetAlertSheet extends StatefulWidget {
  const BudgetAlertSheet({super.key, required this.repository});

  final LedgerRepository repository;

  static Future<void> show(
    BuildContext context,
    LedgerRepository repository,
  ) {
    return showQuestSheet<void>(
      context,
      (ctx) => BudgetAlertSheet(repository: repository),
    );
  }

  @override
  State<BudgetAlertSheet> createState() => _BudgetAlertSheetState();
}

class _BudgetAlertSheetState extends State<BudgetAlertSheet> {
  static const _channel = NotifyChannel();
  static const _percentOptions = [50, 60, 70, 80, 90];

  bool _loading = true;
  bool _enabled = false;
  bool _canPost = true;
  int _threshold = LedgerRepository.defaultBudgetAlertThreshold;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await widget.repository.budgetAlertsEnabled();
    final threshold = await widget.repository.budgetAlertThreshold();
    final canPost = await _channel.canPost();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _threshold = threshold;
      _canPost = canPost;
      _loading = false;
    });
  }

  Future<void> _toggle(bool on) async {
    unawaited(HapticFeedback.selectionClick());
    await widget.repository.setBudgetAlertsEnabled(on);
    setState(() => _enabled = on);
    if (!on) return;
    // Izin diperiksa saat dinyalakan — bukan saat app mulai — supaya
    // dialog sistem hanya muncul dalam konteks yang jelas bagi user.
    var granted = await _channel.canPost();
    if (!granted) {
      granted = await _channel.requestPermission();
    }
    if (mounted) setState(() => _canPost = granted);
  }

  Future<void> _pickPercent(int percent) async {
    unawaited(HapticFeedback.selectionClick());
    await widget.repository.setBudgetAlertThreshold(percent);
    if (mounted) setState(() => _threshold = percent);
  }

  /// Kirim contoh notifikasi: sekaligus menguji izin/channel tanpa
  /// harus menunggu pengeluaran nyata menyentuh ambang. Contoh jelas
  /// berlabel agar tak disangka peringatan sungguhan.
  Future<void> _sendTest() async {
    unawaited(HapticFeedback.selectionClick());
    var granted = await _channel.canPost();
    if (!granted) {
      granted = await _channel.requestPermission();
    }
    if (!mounted) return;
    setState(() => _canPost = granted);
    if (!granted) return; // baris peringatan izin yang tampil.
    await _channel.showBudgetAlert(
      title: 'Contoh peringatan batas',
      body: 'Harian: Rp80.000 dari Rp100.000 — sisa Rp20.000',
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(Spacing.xl),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.m,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Peringatan Batas', style: context.qTitle(18)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text(
              'Notifikasi Android saat pengeluaran menyentuh persen batas '
              'harian, mingguan, atau bulanan.',
              style: context.qSmall().copyWith(color: q.muted),
            ),
            const SizedBox(height: Spacing.m),
            QuestCard(
              padding: EdgeInsets.zero,
              child: QuestListTile(
                leading: Icon(
                  Icons.notification_important_rounded,
                  color: q.primary,
                ),
                title: Text('Aktifkan peringatan', style: context.qTitle(14.5)),
                subtitle: Text(
                  'Bunyi sekali per garis batas per periode.',
                  style: context.qSmall(11.5).copyWith(color: q.muted),
                ),
                trailing: QuestSwitch(
                  value: _enabled,
                  label: 'Aktifkan peringatan',
                  onChanged: _toggle,
                ),
              ),
            ),
            if (_enabled && !_canPost) ...[
              const SizedBox(height: Spacing.s),
              Container(
                padding: const EdgeInsets.all(Spacing.m),
                decoration: BoxDecoration(
                  color: q.warnTint,
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_off_rounded, color: q.warn),
                    const SizedBox(width: Spacing.s),
                    Expanded(
                      child: Text(
                        'Izin notifikasi belum aktif — peringatan tidak '
                        'bisa tampil.',
                        style: context.qSmall(
                          
                        ).copyWith(color: q.text, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: Spacing.s),
                    TextButton(
                      onPressed: () => _channel.openAppNotificationSettings(),
                      child: const Text('Buka Pengaturan'),
                    ),
                  ],
                ),
              ),
            ],
            if (_enabled) ...[
              const SizedBox(height: Spacing.m),
              Text('Ambang persen', style: context.qBody(13)),
              const SizedBox(height: Spacing.s),
              QuestSegmented(
                options: [
                  for (final p in _percentOptions)
                    (value: p, label: '$p%', icon: null),
                ],
                selected: _threshold,
                onChanged: _pickPercent,
              ),
              const SizedBox(height: Spacing.s),
              Text(
                'Peringatan bunyi saat terpakai $_threshold% atau lebih. '
                'Lewat 100% juga tetap dikabari sekali, '
                'terpisah dari ambang ini.',
                style: context.qSmall(11.5).copyWith(color: q.muted),
              ),
            ],
            const SizedBox(height: Spacing.m),
            QuestCard(
              padding: EdgeInsets.zero,
              child: QuestListTile(
                leading: Icon(
                  Icons.notifications_none_rounded,
                  color: q.primary,
                ),
                title: Text(
                  'Kirim contoh notifikasi',
                  style: context.qTitle(14.5),
                ),
                subtitle: Text(
                  'Coba izin & tampilannya langsung, tanpa nunggu transaksi.',
                  style: context.qSmall(11.5).copyWith(color: q.muted),
                ),
                onTap: _sendTest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
