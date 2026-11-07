import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../core/budget.dart';
import '../game/progress.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'bank_accounts_screen.dart';
import 'bon_screen.dart';
import 'draft_inbox_sheet.dart';
import 'quest.dart';
import 'unparsed_logs_sheet.dart';

/// Satu item perhatian di layar Notifikasi.
class _NotifItem {
  const _NotifItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;
}

/// Layar Notifikasi dengan 2 Tab:
/// 1. Peringatan (Batas anggaran, bon jatuh tempo, status izin sistem)
/// 2. Tangkapan Bank (Draf transaksi tertangkap dari SMS / notifikasi m-banking)
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
    this.progress,
    this.onOpenAnggaran,
    this.onOpenBon,
    this.initialTab = 0,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final ProgressService? progress;
  final RuleSet ruleSet;

  /// Tab awal: 0 = Peringatan, 1 = Tangkapan Bank.
  final int initialTab;

  /// Navigasi ke tab Rencana / Bon.
  final VoidCallback? onOpenAnggaran;
  final VoidCallback? onOpenBon;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late int _selectedTab = widget.initialTab;

  late final Future<bool> _listenerEnabled =
      widget.pipeline.channel.isListenerEnabled();

  LedgerRepository get _repo => widget.repository;

  void _openBankAccounts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BankAccountsScreen(
          repository: _repo,
          pipeline: widget.pipeline,
          ruleSet: widget.ruleSet,
        ),
      ),
    );
  }

  void _goTo(VoidCallback? navigate) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    navigate?.call();
  }

  Future<void> _handleUnread(int count, Set<String> connected) async {
    await UnparsedLogsSheet.show(
      context,
      repository: _repo,
      pipeline: widget.pipeline,
      ruleSet: widget.ruleSet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return Scaffold(
      backgroundColor: q.bg,
      appBar: QuestHeader(
        title: 'Notifikasi',
        subtitle: _selectedTab == 0
            ? 'Pusat perhatian & pengingat'
            : 'Tangkapan transaksi bank',
        showBack: true,
      ),
      body: FutureBuilder<bool>(
        future: _listenerEnabled,
        builder: (context, listenerSnap) {
          final enabled = listenerSnap.data ?? false;

          return StreamBuilder<Set<String>>(
            stream: _repo.watchConnectedBanks(),
            builder: (context, connSnap) {
              final connected = connSnap.data ?? const <String>{};

              return StreamBuilder<List<Draft>>(
                stream: _repo.watchDrafts(),
                builder: (context, draftSnap) {
                  final drafts = draftSnap.data ?? const <Draft>[];

                  return StreamBuilder<List<CaptureLog>>(
                    stream: _repo.watchCaptureLog(),
                    builder: (context, logSnap) {
                      final unread = (logSnap.data ?? const <CaptureLog>[])
                          .where((l) => !l.parsed)
                          .length;

                      return StreamBuilder<List<Bon>>(
                        stream: _repo.watchBons(),
                        builder: (context, bonSnap) {
                          final bons = bonSnap.data ?? const <Bon>[];
                          final aging = bons
                              .where(
                                (b) =>
                                    b.settledAt == null &&
                                    bonNeedsBadge(b.occurredAt),
                              )
                              .length;

                          final summary = widget.progress?.latest;
                          final level = summary?.snapshot.worstLevel;
                          final critical = summary?.snapshot.criticalLine;

                          final items = [
                            if (connected.isNotEmpty && !enabled)
                              _NotifItem(
                                icon: Icons.notifications_off_rounded,
                                color: q.bad,
                                title: 'Izin baca notifikasi belum nyala',
                                subtitle:
                                    'Nyalakan agar draf transaksi otomatis masuk',
                                actionLabel: 'Nyalakan',
                                onTap: _openBankAccounts,
                              ),
                            if (unread > 0)
                              _NotifItem(
                                icon: Icons.help_outline_rounded,
                                color: q.warn,
                                title:
                                    '$unread notifikasi belum dikenali formatnya',
                                subtitle:
                                    'Ketuk untuk melatih pola bank atau catat manual',
                                actionLabel: 'Periksa',
                                onTap: () => _handleUnread(unread, connected),
                              ),
                            if (level == BudgetLevel.over)
                              _NotifItem(
                                icon: Icons.warning_amber_rounded,
                                color: q.bad,
                                title:
                                    'Batas ${critical?.label ?? 'harian'} terlampaui',
                                subtitle:
                                    'Yuk cek batas pengeluaranmu di Anggaran',
                                actionLabel: 'Anggaran',
                                onTap: () => _goTo(widget.onOpenAnggaran),
                              )
                            else if (level == BudgetLevel.warning)
                              _NotifItem(
                                icon: Icons.error_outline_rounded,
                                color: q.warn,
                                title:
                                    'Batas ${critical?.label ?? 'harian'} '
                                    'mendekati plafon',
                                subtitle:
                                    'Yuk cek batas pengeluaranmu di Anggaran',
                                actionLabel: 'Anggaran',
                                onTap: () => _goTo(widget.onOpenAnggaran),
                              ),
                            if (aging > 0)
                              _NotifItem(
                                icon: Icons.handshake_outlined,
                                color: q.bad,
                                title:
                                    '$aging bon lebih dari 30 hari belum lunas',
                                subtitle: 'Ingatkan dirimu atau tandai lunas',
                                actionLabel: 'Lihat Bon',
                                onTap: () => _goTo(widget.onOpenBon),
                              ),
                          ];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Tab Selector Segmen
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  Spacing.m,
                                  0,
                                  Spacing.m,
                                  Spacing.s,
                                ),
                                child: QuestSegmented<int>(
                                  options: [
                                    (
                                      value: 0,
                                      label: items.isEmpty
                                          ? 'Peringatan'
                                          : 'Peringatan (${items.length})',
                                      icon: Icons.notifications_none_rounded,
                                    ),
                                    (
                                      value: 1,
                                      label: drafts.isEmpty
                                          ? 'Tangkapan Bank'
                                          : 'Tangkapan Bank (${drafts.length})',
                                      icon: Icons.inbox_outlined,
                                    ),
                                  ],
                                  selected: _selectedTab,
                                  onChanged: (val) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedTab = val);
                                  },
                                ),
                              ),

                              // Tab Content
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: QuestMotion.fast,
                                  child: _selectedTab == 0
                                      ? _buildPeringatanView(context, items)
                                      : DraftInboxView(
                                          key: const ValueKey('drafts-tab'),
                                          repository: widget.repository,
                                          pipeline: widget.pipeline,
                                          ruleSet: widget.ruleSet,
                                          progress: widget.progress,
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
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPeringatanView(BuildContext context, List<_NotifItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.l),
          child: QuestEmpty(
            title: 'Tidak ada peringatan',
            hint:
                'Semua aman — anggaran terkendali, bon lancar, dan izin capture aktif.',
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.m,
        Spacing.xs,
        Spacing.m,
        Spacing.m,
      ),
      children: [
        for (var i = 0; i < items.length; i++)
          QuestEnter(
            index: i,
            child: _AttentionTile(item: items[i]),
          ),
      ],
    );
  }
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile({required this.item});

  final _NotifItem item;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.s),
      decoration: BoxDecoration(
        color: q.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: q.line.withValues(alpha: 0.6)),
      ),
      child: QuestPress(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.m,
            vertical: 12,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 19, color: item.color),
              ),
              const SizedBox(width: Spacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: context.qTitle(14)),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: context.qSmall(11.5).copyWith(color: q.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.actionLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: item.color,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: item.color,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
