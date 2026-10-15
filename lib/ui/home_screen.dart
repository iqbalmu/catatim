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
    QuestDestination(icon: Icons.home_rounded, label: 'Beranda'),
    QuestDestination(icon: Icons.bar_chart_rounded, label: 'Rekap'),
    QuestDestination(icon: Icons.track_changes_rounded, label: 'Rencana'),
    QuestDestination(icon: Icons.handshake_outlined, label: 'Bon'),
  ];

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  /// Kunci layar Rencana untuk memicu aksi tombol + tengah navbar.
  final _rencanaKey = GlobalKey<RencanaScreenState>();

  /// Deep-link Beranda (BatasCard/strip) → Rencana·Batas.
  void _openRencanaBatas() => setState(() => _tab = 2);

  /// Aksi tombol + tengah navbar — dinamis per tab.
  void _primaryAction() {
    switch (_tab) {
      case 3:
        BonSheet.show(context, widget.repository);
      case 2:
        _rencanaKey.currentState?.openPrimaryAction();
      default:
        TransactionSheet.show(
          context,
          widget.repository,
          progress: widget.progress,
        );
    }
  }

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
                pipeline: widget.pipeline,
                progress: widget.progress,
                onOpenRekap: () => setState(() => _tab = 1),
                onOpenRencanaBatas: _openRencanaBatas,
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
                key: _rencanaKey,
                repository: widget.repository,
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
        // Tombol + di tengah navbar, dinamis per tab.
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
              centerAction: (
                tooltip: _tab == 2
                    ? 'Jenis'
                    : _tab == 3
                        ? 'Catat bon'
                        : 'Catat transaksi',
                onTap: _primaryAction,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Mark logo Bukuduit: squircle madu dua rona.
class _BukuduitMark extends StatelessWidget {
  const _BukuduitMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: SeedColors.honey100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: SeedColors.honeyDeep,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: SeedColors.honeyDeep,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lonceng capture log. Future izin listener di-hoist ke [initState]
/// agar tidak dibuat ulang tiap build (bebas loop rebuild).
class _CaptureBell extends StatefulWidget {
  const _CaptureBell({required this.repository, required this.pipeline});

  final LedgerRepository repository;
  final CapturePipeline pipeline;

  @override
  State<_CaptureBell> createState() => _CaptureBellState();
}

class _CaptureBellState extends State<_CaptureBell> {
  late final Future<bool> _listenerEnabled = widget.pipeline.channel
      .isListenerEnabled();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
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
    );
  }
}

/// Menu ⋯: Kelola akun, Rencana·Batas, Backup, Aturan capture.
class _HomeMenu extends StatelessWidget {
  const _HomeMenu({
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
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
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
                  AccountManageScreen(repository: repository),
            ),
          );
        } else if (value == 'budget') {
          onOpenRencana();
        } else if (value == 'backup') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BackupScreen(repository: repository),
            ),
          );
        } else if (value == 'rules') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RulesScreen(
                repository: repository,
                engine: pipeline.engine,
                progress: progress,
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
    );
  }
}

/// Lonceng + ⋯ dipakai ulang di tab selain Beranda.
class _GlobalActions extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CaptureBell(repository: repository, pipeline: pipeline),
        const SizedBox(width: Spacing.s),
        _HomeMenu(
          repository: repository,
          pipeline: pipeline,
          progress: progress,
          onOpenRencana: onOpenRencana,
        ),
      ],
    );
  }
}

String _todaySubtitle(DateTime now) => idFullDate(now);

/// Beranda ala mock pastel: hero saldo + kartu batas 3 kolom + dua kartu
/// arus + disiplin bulan berjalan + transaksi terbaru. Warna tetap palet
/// Quest; pencatatan via tombol + tengah navbar.
class _BerandaTab extends StatefulWidget {
  const _BerandaTab({
    required this.repository,
    required this.pipeline,
    required this.progress,
    required this.onOpenRekap,
    required this.onOpenRencanaBatas,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final ProgressService progress;
  final VoidCallback onOpenRekap;
  final VoidCallback onOpenRencanaBatas;

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
        leading: const _BukuduitMark(),
        actions: [
          _CaptureBell(
            repository: widget.repository,
            pipeline: widget.pipeline,
          ),
          const SizedBox(width: Spacing.s),
          _HomeMenu(
            repository: widget.repository,
            pipeline: widget.pipeline,
            progress: widget.progress,
            onOpenRencana: widget.onOpenRencanaBatas,
          ),
        ],
      ),
      // Tombol + tinggal di tengah navbar (dinamis per tab) — tanpa FAB
      // melayang di tab ini.
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.m + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          GameHeroCard(
            service: widget.progress,
            repository: widget.repository,
            onTapAccounts: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AccountManageScreen(repository: widget.repository),
              ),
            ),
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

              return BatasCard(
                dailyLimit: daily?.limit,
                dailyUsed: daily?.used ?? 0,
                weeklyLimit: weekly?.limit,
                weeklyUsed: weekly?.used ?? 0,
                monthlyLimit: monthly?.limit,
                monthlyUsed: monthly?.used ?? 0,
                onTap: widget.onOpenRencanaBatas,
              );
            },
          ),
          const SizedBox(height: Spacing.m),
          MiniInOut(service: widget.progress, onTap: widget.onOpenRekap),
          const SizedBox(height: Spacing.m),
          DisiplinCard(service: widget.progress),
          const SizedBox(height: Spacing.m),
          TransaksiTerbaruCard(
            repository: widget.repository,
            progress: widget.progress,
            onSeeAll: widget.onOpenRekap,
          ),
          // Clearance navbar melayang di atas konten (extendBody).
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}
