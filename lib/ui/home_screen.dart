import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../core/dates_id.dart';
import '../game/hero_card.dart';
import '../game/progress.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'account_manage_screen.dart';
import 'backup_screen.dart';
import 'bon_screen.dart';
import 'capture_log_screen.dart';
import 'home_cards.dart';
import 'quest.dart';
import 'rekap_screen.dart';
import 'rencana_screen.dart';
import 'rules_screen.dart';
import 'transaction_sheet.dart';

/// Bon tua: belum lunas dan umur kalender (today − occurredAt) > 30 hari.
/// "Hari ini" dihitung dari tanggal kalender lokal, bukan selisih jam.
bool bonNeedsBadge(DateTime occurredAt, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
  return today.difference(day).inDays > 30;
}

/// Shell utama: Beranda | Rekap | Rencana | Bon.
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
    QuestDestination(icon: Icons.receipt_long_rounded, label: 'Rekap'),
    QuestDestination(icon: Icons.savings_rounded, label: 'Rencana'),
    QuestDestination(icon: Icons.handshake_outlined, label: 'Bon'),
  ];

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  /// Segmen Rencana yang sedang aktif — dimiliki shell agar deep-link
  /// Beranda → Rencana·Batas selalu sinkron via [RencanaScreen].
  RencanaSegment _rencanaSegment = RencanaSegment.batas;

  /// Deep-link Beranda (LimitCard/strip) → Rencana·Batas.
  void _openRencanaBatas() => setState(() {
    _rencanaSegment = RencanaSegment.batas;
    _tab = 2;
  });

  void _onTabChanged(int i) {
    setState(() => _tab = i);
    // Kembali ke Beranda setelah ubah batas di Rencana: hero pace/streak
    // dihitung dari limit terbaru.
    if (i == 0) unawaited(widget.progress.refresh());
  }

  /// Aksi header global (lonceng + ⋯) — satu instance dipakai keempat tab.
  late final List<Widget> _globalActions = [
    _GlobalActions(
      repository: widget.repository,
      pipeline: widget.pipeline,
      progress: widget.progress,
      onOpenRencana: _openRencanaBatas,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        // Back di tab non-Beranda kembali ke Beranda; di Beranda keluar.
        if (!didPop && _tab != 0) setState(() => _tab = 0);
      },
      child: Scaffold(
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
                progress: widget.progress,
                headerActions: _globalActions,
                onOpenRekap: () => setState(() => _tab = 1),
                onOpenRencanaBatas: _openRencanaBatas,
                onOpenBon: () => setState(() => _tab = 3),
              ),
            ),
            TickerMode(
              enabled: _tab == 1,
              child: RekapScreen(
                repository: widget.repository,
                progress: widget.progress,
                headerActions: _globalActions,
              ),
            ),
            TickerMode(
              enabled: _tab == 2,
              child: RencanaScreen(
                repository: widget.repository,
                progress: widget.progress,
                initialSegment: _rencanaSegment,
                onSegmentChanged: (s) => _rencanaSegment = s,
                headerActions: _globalActions,
              ),
            ),
            TickerMode(
              enabled: _tab == 3,
              child: BonTab(
                repository: widget.repository,
                headerActions: _globalActions,
              ),
            ),
          ],
        ),
        // Shell hanya navigasi — tiap tab punya FAB sendiri.
        bottomNavigationBar: StreamBuilder<List<Bon>>(
          stream: widget.repository.watchBons(),
          builder: (context, snapshot) {
            final hasOld = (snapshot.data ?? const <Bon>[]).any(
              (b) => b.settledAt == null && bonNeedsBadge(b.occurredAt),
            );
            return QuestBottomNav(
              index: _tab,
              onChanged: _onTabChanged,
              destinations: HomeScreen._destinations,
              badges: hasOld ? const {3} : const <int>{},
            );
          },
        ),
      ),
    );
  }
}

/// Lonceng + ⋯ dipakai ulang di keempat tab. Future izin listener di-hoist
/// ke [initState] agar tidak dibuat ulang tiap build (bebas loop rebuild).
class _GlobalActions extends StatefulWidget {
  const _GlobalActions({
    required this.repository,
    required this.pipeline,
    required this.progress,
    required this.onOpenRencana,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final ProgressService progress;
  final VoidCallback onOpenRencana;

  @override
  State<_GlobalActions> createState() => _GlobalActionsState();
}

class _GlobalActionsState extends State<_GlobalActions> {
  late final Future<bool> _listenerEnabled = widget.pipeline.channel
      .isListenerEnabled();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FutureBuilder<bool>(
          future: _listenerEnabled,
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
              boxShadow: [
                BoxShadow(
                  color: context.q.shadow,
                  offset: const Offset(0, 4),
                  blurRadius: 12,
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
              widget.onOpenRencana();
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
                  const Text('Rencana · Batas'),
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
    );
  }
}

String _todaySubtitle(DateTime now) => idFullDate(now);

/// Beranda kilat: hero + strip peringatan + 3 kartu batas + mini
/// keluar/masuk + baris saldo. Tanpa daftar transaksi — pencatatan via
/// FAB "Catat transaksi", telaah di tab Rekap.
class _BerandaTab extends StatefulWidget {
  const _BerandaTab({
    required this.repository,
    required this.progress,
    required this.headerActions,
    required this.onOpenRekap,
    required this.onOpenRencanaBatas,
    required this.onOpenBon,
  });

  final LedgerRepository repository;
  final ProgressService progress;
  final List<Widget> headerActions;
  final VoidCallback onOpenRekap;
  final VoidCallback onOpenRencanaBatas;
  final VoidCallback onOpenBon;

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
      questSnack(context, alert, icon: Icons.warning_amber_rounded);
      return;
    }
    final recovery = await widget.progress.consumePendingRecovery();
    if (recovery != null && mounted) {
      HapticFeedback.lightImpact();
      questSnack(context, recovery, icon: Icons.emoji_emotions_rounded);
      return;
    }
    final milestone = await widget.progress.consumePendingMilestone();
    if (milestone != null && mounted) {
      HapticFeedback.lightImpact();
      questSnack(
        context,
        '$milestone hari disiplin — mantap!',
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
          ListenableBuilder(
            listenable: widget.progress,
            builder: (context, _) {
              final streak = widget.progress.latest?.streakDays ?? 0;
              final hasStreak = streak > 0;
              return Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: context.q.surface,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: context.q.shadow,
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 15,
                      color: hasStreak ? SeedColors.honeyDeep : context.q.muted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$streak',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: hasStreak ? context.q.text : context.q.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: Spacing.s),
          ...widget.headerActions,
        ],
      ),
      // FAB milik tab ini (bukan shell). Padding bawah agar melayang di
      // atas navbar floating.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: 72 + MediaQuery.paddingOf(context).bottom,
        ),
        child: QuestFab(
          label: 'Catat transaksi',
          icon: Icons.add_rounded,
          onTap: () => TransactionSheet.show(
            context,
            widget.repository,
            progress: widget.progress,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.m + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          GameHeroCard(service: widget.progress),
          AlertStrip(
            repository: widget.repository,
            service: widget.progress,
            onOpenBatas: widget.onOpenRencanaBatas,
          ),
          const SizedBox(height: Spacing.m),
          ListenableBuilder(
            listenable: widget.progress,
            builder: (context, _) {
              final lines = widget.progress.latest?.snapshot.lines;
              final daily = lines != null && lines.isNotEmpty ? lines[0] : null;
              final weekly = lines != null && lines.length > 1
                  ? lines[1]
                  : null;
              final monthly = lines != null && lines.length > 2
                  ? lines[2]
                  : null;
              final onOpenBatas = widget.onOpenRencanaBatas;

              return Column(
                children: [
                  LimitCard(
                    label: 'HARIAN',
                    limit: daily?.limit,
                    used: daily?.used ?? 0,
                    safe: (daily?.limit ?? 0) - (daily?.used ?? 0),
                    onTap: onOpenBatas,
                  ),
                  const SizedBox(height: Spacing.s),
                  LimitCard(
                    label: 'MINGGUAN',
                    limit: weekly?.limit,
                    used: weekly?.used ?? 0,
                    safe: (weekly?.limit ?? 0) - (weekly?.used ?? 0),
                    onTap: onOpenBatas,
                  ),
                  const SizedBox(height: Spacing.s),
                  LimitCard(
                    label: 'BULANAN',
                    limit: monthly?.limit,
                    used: monthly?.used ?? 0,
                    safe: (monthly?.limit ?? 0) - (monthly?.used ?? 0),
                    onTap: onOpenBatas,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: Spacing.m),
          MiniInOut(service: widget.progress, onTap: widget.onOpenRekap),
          const SizedBox(height: Spacing.m),
          SaldoRow(repository: widget.repository),
        ],
      ),
    );
  }
}
