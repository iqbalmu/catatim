import 'package:flutter/material.dart';

import '../capture/pipeline.dart';
import '../core/budget.dart';
import '../game/progress.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'bon_screen.dart';
import 'capture_log_screen.dart';
import 'quest.dart';

/// Satu item perhatian di layar Notifikasi.
class _NotifItem {
  const _NotifItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

/// Layar Notifikasi: daftar hal yang perlu perhatianmu SAAT INI —
/// bukan arsip riwayat. Semua item dihitung dari data yang sudah ada
/// (ADR-007: cermin kondisi nyata), tanpa tabel/persistensi baru.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.progress,
    required this.onOpenRencana,
    required this.onOpenBon,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final ProgressService progress;

  /// Tutup layar ini lalu alih ke tab Rencana / Bon.
  final VoidCallback onOpenRencana;
  final VoidCallback onOpenBon;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late final Future<bool> _listenerEnabled =
      widget.pipeline.channel.isListenerEnabled();

  void _openCaptureLog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaptureLogScreen(
          repository: widget.repository,
          channel: widget.pipeline.channel,
          engine: widget.pipeline.engine,
        ),
      ),
    );
  }

  void _goTo(VoidCallback navigate) {
    Navigator.pop(context);
    navigate();
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Scaffold(
      backgroundColor: q.bg,
      appBar: const QuestHeader(
        title: 'Notifikasi',
        subtitle: 'Yang perlu perhatianmu',
        showBack: true,
      ),
      body: FutureBuilder<bool>(
        future: _listenerEnabled,
        builder: (context, listenerSnap) {
          final enabled = listenerSnap.data ?? false;
          return StreamBuilder<List<CaptureLog>>(
            stream: widget.repository.watchCaptureLog(),
            builder: (context, logSnap) {
              final logs = logSnap.data ?? const <CaptureLog>[];
              final failed = logs.where((l) => !l.parsed).length;
              return StreamBuilder<List<Bon>>(
                stream: widget.repository.watchBons(),
                builder: (context, bonSnap) {
                  final bons = bonSnap.data ?? const <Bon>[];
                  final aging = bons
                      .where((b) =>
                          b.settledAt == null &&
                          bonNeedsBadge(b.occurredAt))
                      .length;
                  final summary = widget.progress.latest;
                  final level = summary?.snapshot.worstLevel;
                  final critical = summary?.snapshot.criticalLine;
                  final items = [
                    if (!enabled)
                      _NotifItem(
                        icon: Icons.notifications_off_rounded,
                        color: q.bad,
                        title: 'Izin notifikasi belum aktif',
                        subtitle:
                            'Berikan akses agar transaksi bank tertangkap '
                            'otomatis',
                        onTap: _openCaptureLog,
                      ),
                    if (failed > 0)
                      _NotifItem(
                        icon: Icons.tune_rounded,
                        color: q.bad,
                        title: '$failed notifikasi gagal diparse',
                        subtitle: 'Perbaiki aturan agar tertangkap',
                        onTap: _openCaptureLog,
                      ),
                    if (level == BudgetLevel.over)
                      _NotifItem(
                        icon: Icons.warning_amber_rounded,
                        color: q.bad,
                        title:
                            'Batas ${critical?.label ?? 'harian'} terlampaui',
                        subtitle: 'Lihat papan batas untuk evaluasi',
                        onTap: () => _goTo(widget.onOpenRencana),
                      )
                    else if (level == BudgetLevel.warning)
                      _NotifItem(
                        icon: Icons.error_outline_rounded,
                        color: SeedColors.honeyDeep,
                        title: 'Batas ${critical?.label ?? 'harian'} '
                            'mendekati plafon',
                        subtitle: 'Lihat papan batas untuk evaluasi',
                        onTap: () => _goTo(widget.onOpenRencana),
                      ),
                    if (aging > 0)
                      _NotifItem(
                        icon: Icons.handshake_outlined,
                        color: q.bad,
                        title: '$aging bon >30 hari belum lunas',
                        subtitle: 'Ingatkan dirimu atau tandai lunas',
                        onTap: () => _goTo(widget.onOpenBon),
                      ),
                  ];
                  if (items.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(Spacing.m),
                      children: [
                        QuestEmpty(
                          title: 'Tidak ada notifikasi',
                          hint: 'Semua aman — lanjutkan aktivitasmu ✓',
                        ),
                      ],
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.m,
                      Spacing.s,
                      Spacing.m,
                      Spacing.m,
                    ),
                    children: [
                      for (final item in items)
                        QuestPress(
                          onTap: item.onTap,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: Spacing.s),
                            padding: Insets.tile,
                            decoration: BoxDecoration(
                              color: q.surface,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.tile),
                              boxShadow: [
                                BoxShadow(
                                  color: q.shadow,
                                  offset: const Offset(0, 6),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: item.color.withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(item.icon,
                                      size: 19, color: item.color),
                                ),
                                const SizedBox(width: Spacing.s),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: context.qTitle(14),
                                      ),
                                      Text(
                                        item.subtitle,
                                        style: context.qSmall(11),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    size: 18, color: q.muted),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
