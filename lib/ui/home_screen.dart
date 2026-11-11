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
import 'ocr_screen.dart';
import 'quest.dart';
import 'rencana_screen.dart';
import 'transaction_sheet.dart';
import 'transaksi_screen.dart';

/// Shell utama: Beranda | Transaksi | Bon | Laporan.
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
    QuestDestination(icon: Icons.handshake_outlined, label: 'Bon'),
    QuestDestination(icon: Icons.bar_chart_rounded, label: 'Laporan'),
  ];

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  /// Jeda refresh setelah pindah tab: sedikit lebih lama dari durasi
  /// slide agar rebuild data terjadi setelah animasi mendarat.
  static const _refreshSettle = Duration(milliseconds: 300);

  /// Badge bon disematkan sekali agar rebuild tak subscribe ulang (anti-kedip).
  late final Stream<List<Bon>> _bonsWatch;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bonsWatch = widget.repository.watchBons();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSharedPayload();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSharedPayload();
    }
  }

  Future<void> _checkSharedPayload() async {
    final payload = await widget.pipeline.channel.consumeSharedPayload();
    if (payload == null || !mounted) return;

    if (payload.type == 'text' &&
        payload.text != null &&
        payload.text!.trim().isNotEmpty) {
      final ok = await widget.pipeline.submitPastedText(
        payload.text!,
        sourceLabel: 'Dibagikan',
      );
      if (!mounted) return;
      questSnack(
        context,
        ok
            ? 'Teks dibagikan berhasil diproses menjadi draf!'
            : 'Gagal memproses teks dibagikan.',
        icon: ok
            ? Icons.check_circle_outline_rounded
            : Icons.info_outline_rounded,
      );
    } else if (payload.type == 'image' && payload.path != null) {
      await OcrScreen.start(
        context,
        pipeline: widget.pipeline,
        imagePath: payload.path,
      );
    }
  }

  int _tab = 0;

  /// Token panggung per-tab: hanya tab TUJUAN yang dinaikkan saat berpindah
  /// agar komponen di tab aktif menetas satu-per-satu & bar tumbuh dari 0.
  final List<int> _tabTokens = [0, 0, 0, 0];

  void _switchTab(int target) {
    if (target == _tab) return;
    HapticFeedback.selectionClick();
    setState(() {
      _tab = target;
      _tabTokens[target]++;
    });
    if (target == 0) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer(_refreshSettle, () {
        if (mounted) widget.progress.refresh();
      });
    }
  }

  void _openAnggaran() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RencanaScreen(
          repository: widget.repository,
          progress: widget.progress,
        ),
      ),
    );
  }

  void _openTransaksi() => _switchTab(1);
  void _openBon() => _switchTab(2);

  /// Aksi tombol + tengah navbar: Langsung catat transaksi 1-tap.
  void _primaryAction() {
    HapticFeedback.lightImpact();
    TransactionSheet.show(
      context,
      widget.repository,
      progress: widget.progress,
      pipeline: widget.pipeline,
      ruleSet: widget.ruleSet,
    );
  }

  ({String tooltip, VoidCallback onTap, IconData? icon}) _getCenterAction() {
    if (_tab == 2) {
      return (
        tooltip: 'Catat bon baru',
        onTap: () {
          HapticFeedback.lightImpact();
          BonSheet.show(context, widget.repository);
        },
        icon: Icons.handshake_outlined,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_tab != 0) _switchTab(0);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Edge-to-edge (audit A-03): ikon status bar kontras dengan tema.
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark, // Android
          statusBarBrightness:
              isDark ? Brightness.dark : Brightness.light, // iOS
        ),
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
                  repository: widget.repository,
                  progress: widget.progress,
                  pipeline: widget.pipeline,
                  ruleSet: widget.ruleSet,
                ),
              ),
            ),
            QuestStage(
              token: _tabTokens[2],
              child: TickerMode(
                enabled: _tab == 2,
                child: BonScreen(
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
                  showBack: false,
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
              badges: hasOld ? const {2} : const <int>{},
              centerAction: _getCenterAction(),
            );
          },
        ),
      ),
      ),
    );
  }
}

/// Beranda: ringkasan saldo & kartu akun, batas anggaran, dan transaksi terbaru.
/// Pencatatan via tombol + tengah navbar.
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
              child: StackedHeroCards(
                progress: widget.progress,
                repository: widget.repository,
                pipeline: widget.pipeline,
                ruleSet: widget.ruleSet,
                onOpenAnggaran: widget.onOpenAnggaran,
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
