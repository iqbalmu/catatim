import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../core/dates_id.dart';
import '../game/hero_card.dart';
import '../game/progress.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'account_manage_screen.dart';
import 'backup_screen.dart';
import 'bon_screen.dart';
import 'budget_screen.dart';
import 'capture_log_screen.dart';
import 'history_screen.dart';
import 'quest.dart';
import 'rules_screen.dart';
import 'report_screen.dart';
import 'transaction_sheet.dart';
import 'transaction_tile.dart';

String _todaySubtitle(DateTime now) => idFullDate(now);

/// Shell utama: Beranda | Riwayat | Laporan | Bon.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.progress,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final ProgressService progress;

  static const _destinations = [
    QuestDestination(
      icon: Icons.account_balance_wallet_rounded,
      label: 'Beranda',
    ),
    QuestDestination(icon: Icons.receipt_long_rounded, label: 'Riwayat'),
    QuestDestination(icon: Icons.insights_rounded, label: 'Laporan'),
    QuestDestination(icon: Icons.handshake_outlined, label: 'Bon'),
  ];

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  void _primaryAction() {
    if (_tab == 3) {
      BonSheet.show(context, widget.repository);
    } else {
      TransactionSheet.show(
        context,
        widget.repository,
        progress: widget.progress,
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      // Konten mengalir di belakang navbar floating; tiap tab memberi
      // clearance lewat MediaQuery.padding.bottom yang disuntik Scaffold.
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          TickerMode(
            enabled: _tab == 0,
            child: _BerandaTab(
              repository: widget.repository,
              pipeline: widget.pipeline,
              progress: widget.progress,
              onOpenHistory: () => setState(() => _tab = 1),
            ),
          ),
          TickerMode(
            enabled: _tab == 1,
            child: HistoryTab(
              repository: widget.repository,
              progress: widget.progress,
            ),
          ),
          TickerMode(
            enabled: _tab == 2,
            child: ReportTab(repository: widget.repository),
          ),
          TickerMode(
            enabled: _tab == 3,
            child: BonTab(repository: widget.repository),
          ),
        ],
      ),
      bottomNavigationBar: QuestBottomNav(
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
        destinations: HomeScreen._destinations,
        centerAction: (
          label: _tab == 3 ? 'Catat bon' : 'Catat transaksi',
          onTap: _primaryAction,
        ),
      ),
    );
  }
}

/// Beranda ringan: hero + pratinjau hari ini. Riwayat penuh di tab Riwayat.
class _BerandaTab extends StatefulWidget {
  const _BerandaTab({
    required this.repository,
    required this.pipeline,
    required this.progress,
    required this.onOpenHistory,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final ProgressService progress;
  final VoidCallback onOpenHistory;

  @override
  State<_BerandaTab> createState() => _BerandaTabState();
}

class _BerandaTabState extends State<_BerandaTab> {
  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_onProgressChanged);
    unawaited(widget.progress.refresh());
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onProgressChanged);
    super.dispose();
  }

  Future<void> _onProgressChanged() async {
    final alert = widget.progress.consumePendingAlert();
    if (alert != null && mounted) {
      HapticFeedback.mediumImpact();
      questSnack(
        context,
        alert,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }
    final recovery = await widget.progress.consumePendingRecovery();
    if (recovery != null && mounted) {
      HapticFeedback.lightImpact();
      questSnack(
        context,
        recovery,
        icon: Icons.emoji_emotions_rounded,
      );
      return;
    }
    final milestone = widget.progress.consumePendingMilestone();
    if (milestone != null && mounted) {
      HapticFeedback.lightImpact();
      questSnack(
        context,
        '$milestone hari beruntun mencatat — mantap!',
        icon: Icons.local_fire_department_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: QuestHeader(
        title: 'Bukuduit',
        subtitle: _todaySubtitle(DateTime.now()),
        actions: [
          FutureBuilder<bool>(
            future: widget.pipeline.channel.isListenerEnabled(),
            builder: (context, snapshot) {
              final enabled = snapshot.data ?? false;
              return QuestIconButton(
                icon: Icons.notifications_active_outlined,
                tooltip: 'Capture log',
                badge: !enabled,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CaptureLogScreen(
                      repository: widget.repository,
                      channel: widget.pipeline.channel,
                      engine: widget.pipeline.engine,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: Spacing.s),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            icon: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.q.surface,
                shape: BoxShape.circle,
                border: Border.all(color: context.q.line, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: context.q.shadow,
                    offset: const Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Icon(Icons.more_horiz_rounded, color: context.q.text),
            ),
            onSelected: (value) {
              if (value == 'accounts') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AccountManageScreen(repository: widget.repository),
                  ),
                );
              } else if (value == 'budget') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BudgetScreen(repository: widget.repository),
                  ),
                );
              } else if (value == 'backup') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BackupScreen(repository: widget.repository),
                  ),
                );
              } else if (value == 'rules') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RulesScreen(
                      repository: widget.repository,
                      engine: widget.pipeline.engine,
                      progress: widget.progress,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'accounts',
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: context.q.text,
                    ),
                    const SizedBox(width: Spacing.s),
                    const Text('Kelola akun'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'budget',
                child: Row(
                  children: [
                    Icon(Icons.savings_rounded, color: context.q.text),
                    const SizedBox(width: Spacing.s),
                    const Text('Anggaran'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.backup_outlined, color: context.q.text),
                    const SizedBox(width: Spacing.s),
                    const Text('Backup & pulihkan'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'rules',
                child: Row(
                  children: [
                    Icon(Icons.rule_rounded, color: context.q.text),
                    const SizedBox(width: Spacing.s),
                    const Text('Aturan capture'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.m + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          GameHeroCard(service: widget.progress, repository: widget.repository),
          const SizedBox(height: Spacing.s),
          StreamBuilder<List<TxWithCategory>>(
            stream: widget.repository.watchRecentWithCategory(limit: 60),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const QuestSkeleton();
              }
              final now = DateTime.now();
              final todayItems = [
                for (final r in snapshot.data ?? const <TxWithCategory>[])
                  if (r.tx.occurredAt.year == now.year &&
                      r.tx.occurredAt.month == now.month &&
                      r.tx.occurredAt.day == now.day)
                    r,
              ].take(4).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const QuestSectionHeader(title: 'Hari ini'),
                  if (todayItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.s),
                      child: Text(
                        'Belum ada catatan hari ini.',
                        style: context.qSmall(),
                      ),
                    ),
                  for (final item in todayItems)
                    TransactionTile(
                      item: item,
                      repository: widget.repository,
                      progress: widget.progress,
                    ),
                  const SizedBox(height: Spacing.s),
                  QuestButton(
                    label: 'Lihat semua',
                    icon: Icons.arrow_forward_rounded,
                    tone: QuestTone.secondary,
                    onPressed: widget.onOpenHistory,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
