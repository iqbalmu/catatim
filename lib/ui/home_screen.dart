import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../game/progress.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'bon_screen.dart';
import 'home_cards.dart';
import 'laporan_screen.dart';
import 'quest.dart';
import 'rencana_batas.dart';
import 'rencana_screen.dart';
import 'transaction_sheet.dart';
import 'transaksi_screen.dart';
/// Shell utama: Beranda | Rekap | Rencana | Bon.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.progress,
    required this.ruleSet,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final ProgressService progress;
  final RuleSet ruleSet;

  static const _destinations = [
    QuestDestination(icon: Icons.dashboard_rounded, label: 'Beranda'),
    QuestDestination(icon: Icons.receipt_long_rounded, label: 'Transaksi'),
    QuestDestination(icon: Icons.pie_chart_outline_rounded, label: 'Anggaran'),
    QuestDestination(icon: Icons.bar_chart_rounded, label: 'Laporan'),
  ];

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Jeda refresh setelah pindah tab: sedikit lebih lama dari durasi
  /// slide agar rebuild data terjadi setelah animasi mendarat.
  static const _refreshSettle = Duration(milliseconds: 300);

  /// Badge bon disematkan sekali agar rebuild tak subscribe ulang (anti-kedip).
  late final Stream<List<Bon>> _bonsWatch;

  @override
  void initState() {
    super.initState();
    _bonsWatch = widget.repository.watchBons();
  }
  Timer? _refreshTimer;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  int _tab = 0;

  /// Token panggung per-tab: hanya tab TUJUAN yang dinaikkan saat berpindah
  /// agar komponen di tab aktif menetas satu-per-satu & bar tumbuh dari 0.
  final List<int> _tabTokens = [0, 0, 0, 0];
  bool _inBonView = false;

  /// Kunci layar Transaksi untuk mengelola sub-tampilan Bon & tombol Back.
  final _transaksiKey = GlobalKey<TransaksiScreenState>();

  void _switchTab(int target, {bool openBon = false}) {
    if (target == _tab) {
      if (target == 1 && !openBon && _inBonView) {
        _transaksiKey.currentState?.handleBack();
      } else if (target == 1 && openBon && !_inBonView) {
        setState(() => _inBonView = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _transaksiKey.currentState?.showBon();
        });
      }
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _tab = target;
      _tabTokens[target]++;
      if (target == 1 && openBon) {
        _inBonView = true;
      } else if (target != 1 && _inBonView) {
        _inBonView = false;
        _transaksiKey.currentState?.handleBack();
      }
    });
    if (target == 1 && openBon) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _transaksiKey.currentState?.showBon();
      });
    }
    if (target == 0) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer(_refreshSettle, () {
        if (mounted) widget.progress.refresh();
      });
    }
  }

  void _openTransaksi() => _switchTab(1);
  void _openAnggaran() => _switchTab(2);
  void _openBon() => _switchTab(1, openBon: true);
  /// Aksi tombol + tengah navbar: Langsung catat transaksi 1-tap.
  void _primaryAction() {
    HapticFeedback.lightImpact();
    TransactionSheet.show(
      context,
      widget.repository,
      progress: widget.progress,
    );
  }

  ({String tooltip, VoidCallback onTap, IconData? icon}) _getCenterAction() {
    if (_tab == 1 && _inBonView) {
      return (
        tooltip: 'Catat bon baru',
        onTap: () {
          HapticFeedback.lightImpact();
          BonSheet.show(context, widget.repository);
        },
        icon: Icons.handshake_outlined,
      );
    }
    if (_tab == 2) {
      return (
        tooltip: 'Tambah kategori',
        onTap: () {
          HapticFeedback.lightImpact();
          showAddCategoryFlow(context, widget.repository);
        },
        icon: Icons.playlist_add_rounded,
      );
    }
    return (
      tooltip: 'Catat transaksi',
      onTap: _primaryAction,
      icon: Icons.add_rounded,
    );
  }

  void _onTabChanged(int i) => _switchTab(i);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_tab == 1) {
          final handled = _transaksiKey.currentState?.handleBack() ?? false;
          if (handled) return;
        }
        if (_tab != 0) _switchTab(0);
      },
      child: Scaffold(
        backgroundColor: context.q.bg,
        extendBody: true,
        body: IndexedStack(
          index: _tab,
          children: [
            QuestStage(
              token: _tabTokens[0],
              child: TickerMode(
                enabled: _tab == 0,
                child: _BerandaTab(
                  repository: widget.repository,
                  pipeline: widget.pipeline,
                  progress: widget.progress,
                  ruleSet: widget.ruleSet,
                  onOpenTransaksi: _openTransaksi,
                  onOpenAnggaran: _openAnggaran,
                  onOpenBon: _openBon,
                ),
              ),
            ),
            QuestStage(
              token: _tabTokens[1],
              child: TickerMode(
                enabled: _tab == 1,
                child: TransaksiScreen(
                  key: _transaksiKey,
                  repository: widget.repository,
                  progress: widget.progress,
                  onBonViewChanged: (inBon) =>
                      setState(() => _inBonView = inBon),
                ),
              ),
            ),
            QuestStage(
              token: _tabTokens[2],
              child: TickerMode(
                enabled: _tab == 2,
                child: RencanaScreen(
                  repository: widget.repository,
                  progress: widget.progress,
                ),
              ),
            ),
            QuestStage(
              token: _tabTokens[3],
              child: TickerMode(
                enabled: _tab == 3,
                child: LaporanScreen(
                  repository: widget.repository,
                  progress: widget.progress,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: StreamBuilder<List<Bon>>(
          stream: _bonsWatch,
          builder: (context, snapshot) {
            final hasOld = (snapshot.data ?? const <Bon>[]).any(
              (b) => b.settledAt == null && bonNeedsBadge(b.occurredAt),
            );
            return QuestBottomNav(
              index: _tab,
              onChanged: _onTabChanged,
              destinations: HomeScreen._destinations,
              badges: hasOld ? const {1} : const <int>{},
              centerAction: _getCenterAction(),
            );
          },
        ),
      ),
    );
  }
}


/// Beranda: panggung maskot & saldo hero, belanja hari ini, streak,
/// dan transaksi terbaru. Pencatatan via tombol + tengah navbar.
class _BerandaTab extends StatefulWidget {
  const _BerandaTab({
    required this.repository,
    required this.pipeline,
    required this.progress,
    required this.ruleSet,
    required this.onOpenTransaksi,
    required this.onOpenAnggaran,
    required this.onOpenBon,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final ProgressService progress;
  final RuleSet ruleSet;
  final VoidCallback onOpenTransaksi;
  final VoidCallback onOpenAnggaran;
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
      body: SafeArea(
        bottom: false,
      child: ListView(
          padding: EdgeInsets.only(
            bottom: Spacing.m + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            QuestTabEnter(
              index: 0,
              child: HomeTopBar(
                progress: widget.progress,
                repository: widget.repository,
                pipeline: widget.pipeline,
                ruleSet: widget.ruleSet,
                onOpenAnggaran: widget.onOpenAnggaran,
                onOpenBon: widget.onOpenBon,
              ),
            ),
            QuestTabEnter(
              index: 1,
              child: DraftAttentionBanner(
                repository: widget.repository,
                ruleSet: widget.ruleSet,
                progress: widget.progress,
                pipeline: widget.pipeline,
                onOpenAnggaran: widget.onOpenAnggaran,
                onOpenBon: widget.onOpenBon,
              ),
            ),
            QuestTabEnter(
              index: 1,
              child: TotalBalanceCard(
                repository: widget.repository,
                pipeline: widget.pipeline,
                ruleSet: widget.ruleSet,
                progress: widget.progress,
              ),
            ),
            QuestTabEnter(
              index: 2,
              child: BudgetSummaryCard(
                progress: widget.progress,
                onTap: widget.onOpenAnggaran,
              ),
            ),
            RecentTransactionsCard(
              repository: widget.repository,
              progress: widget.progress,
              onSeeAll: widget.onOpenTransaksi,
            ),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}
