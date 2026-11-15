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
import 'bon_screen.dart';
import 'capture_settings/permission_onboarding_sheet.dart';
import 'draft_inbox_sheet.dart';
import 'quest.dart';

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

class _NotificationScreenState extends State<NotificationScreen>
    with WidgetsBindingObserver {
  late int _selectedTab = widget.initialTab;

  bool _listenerEnabled = false;

  LedgerRepository get _repo => widget.repository;

  late Stream<List<Draft>> _draftsStream;
  late Stream<Set<String>> _connectedBanksStream;
  late Stream<List<Bon>> _bonsStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkListener();
    _draftsStream = _repo.watchDrafts();
    _connectedBanksStream = _repo.watchConnectedBanks();
    _bonsStream = _repo.watchBons();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkListener();
    }
  }

  Future<void> _checkListener() async {
    final enabled = await widget.pipeline.channel.isListenerEnabled();
    if (!mounted) return;
    setState(() => _listenerEnabled = enabled);
  }

  @override
  void didUpdateWidget(covariant NotificationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _draftsStream = _repo.watchDrafts();
      _connectedBanksStream = _repo.watchConnectedBanks();
      _bonsStream = _repo.watchBons();
    }
  }

  Future<void> _requestPermission() async {
    final granted = await NotificationPermissionSheet.show(
      context,
      channel: widget.pipeline.channel,
    );
    await _checkListener();
    if (granted && mounted) {
      questSnack(
        context,
        'Izin akses notifikasi aktif! Capture siap berjalan.',
        icon: Icons.check_circle_outline_rounded,
      );
    }
  }

  Future<void> _discardAllDrafts(List<Draft> drafts) async {
    final sure = await showQuestDialog<bool>(
      context,
      title: 'Abaikan semua tangkapan?',
      content: Text(
        'Ada ${drafts.length} tangkapan bank yang belum dicatat. Semuanya bakal dihapus dari daftar.',
        style: context.qBody(13),
      ),
      actions: [
        QuestButton(
          label: 'Abaikan Semua',
          tone: QuestTone.danger,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (sure == true && mounted) {
      await _repo.discardDrafts(drafts.map((d) => d.id));
      if (mounted) {
        questSnack(context, '${drafts.length} tangkapan udah diabaikan.');
      }
    }
  }

  void _goTo(VoidCallback? navigate) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    navigate?.call();
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return StreamBuilder<List<Draft>>(
      stream: _draftsStream,
      builder: (context, draftSnap) {
        final drafts = draftSnap.data ?? const <Draft>[];

        return Scaffold(
          backgroundColor: q.bg,
          appBar: QuestHeader(
            textScale: MediaQuery.textScalerOf(context).scale(1.0),
            title: 'Notifikasi',
            subtitle: _selectedTab == 0
                ? 'Pusat perhatian & pengingat'
                : 'Tangkapan transaksi bank',
            showBack: true,
            actions: [
              if (_selectedTab == 1 && drafts.length > 1)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: q.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: q.line),
                    boxShadow: q.cardShadow,
                  ),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.delete_sweep_outlined,
                      color: q.bad,
                      size: 20,
                    ),
                    tooltip: 'Abaikan Semua',
                    onPressed: () => _discardAllDrafts(drafts),
                  ),
                ),
            ],
          ),
          body: StreamBuilder<Set<String>>(
            stream: _connectedBanksStream,
            builder: (context, connSnap) {
              final connected = connSnap.data ?? const <String>{};

              return StreamBuilder<List<Bon>>(
                stream: _bonsStream,
                builder: (context, bonSnap) {
                  final bons = bonSnap.data ?? const <Bon>[];
                  final aging = bons.where(bonNeedsBadge).length;

                  final summary = widget.progress?.latest;
                  final level = summary?.snapshot.worstLevel;
                  final critical = summary?.snapshot.criticalLine;

                  final items = [
                    if (connected.isNotEmpty && !_listenerEnabled)
                      _NotifItem(
                        icon: Icons.notifications_off_rounded,
                        color: q.bad,
                        title: 'Izin baca notifikasi belum nyala',
                        subtitle: 'Nyalakan agar draf transaksi otomatis masuk',
                        actionLabel: 'Nyalakan',
                        onTap: _requestPermission,
                      ),
                    if (level == BudgetLevel.over)
                      _NotifItem(
                        icon: Icons.warning_amber_rounded,
                        color: q.bad,
                        title:
                            'Batas ${critical?.label.toLowerCase() ?? 'harian'} sudah terlewati',
                        subtitle:
                            'Pengeluaranmu sudah melebihi batas yang ditentukan',
                        actionLabel: 'Lihat Anggaran',
                        onTap: () => _goTo(widget.onOpenAnggaran),
                      )
                    else if (level == BudgetLevel.warning)
                      _NotifItem(
                        icon: Icons.error_outline_rounded,
                        color: q.warn,
                        title:
                            'Batas ${critical?.label.toLowerCase() ?? 'harian'} hampir habis',
                        subtitle:
                            'Pengeluaranmu sudah mendekati batas yang ditentukan',
                        actionLabel: 'Lihat Anggaran',
                        onTap: () => _goTo(widget.onOpenAnggaran),
                      ),
                    if (aging > 0)
                      _NotifItem(
                        icon: Icons.handshake_outlined,
                        color: q.bad,
                        title: '$aging bon belum lunas lewat batas',
                        subtitle:
                            'Jatuh tempo terlewat atau sudah lebih dari 30 hari',
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
          ),
        );
      },
    );
  }

  Widget _buildPeringatanView(BuildContext context, List<_NotifItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(Spacing.l),
          child: QuestEmpty(
            title: 'Belum ada peringatan',
            hint:
                'Semua aman: anggaran terkendali, bon lancar, dan izin capture aktif.',
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
