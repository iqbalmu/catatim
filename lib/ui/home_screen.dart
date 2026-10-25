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

  int _tab = 0;

  /// Kunci layar Transaksi untuk mengelola sub-tampilan Bon & tombol Back.
  final _transaksiKey = GlobalKey<TransaksiScreenState>();

  void _openTransaksi() => setState(() => _tab = 1);
  void _openAnggaran() => setState(() => _tab = 2);
  void _openBon() {
    setState(() => _tab = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _transaksiKey.currentState?.showBon();
    });
  }
  /// Aksi tombol + tengah navbar: Langsung catat transaksi 1-tap.
  void _primaryAction() {
    HapticFeedback.lightImpact();
    TransactionSheet.show(
      context,
      widget.repository,
      progress: widget.progress,
    );
  }

  void _onTabChanged(int i) {
    setState(() => _tab = i);
    // Kembali ke Beranda setelah ubah batas di Rencana: hero pace/streak
    // dihitung dari limit terbaru. Ditunda hingga slide mendarat agar
    // konten tidak berubah tepat di tengah animasi (kedip).
    if (i == 0) {
      unawaited(
        Future.delayed(_refreshSettle).then((_) {
          if (mounted) return widget.progress.refresh();
        }),
      );
    }
  }

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
        if (_tab != 0) setState(() => _tab = 0);
      },
      child: Scaffold(
        backgroundColor: context.q.bg,
        extendBody: true,
        body: _DirectionalTabView(
          index: _tab,
          children: [
            TickerMode(
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
            TickerMode(
              enabled: _tab == 1,
              child: TransaksiScreen(
                key: _transaksiKey,
                repository: widget.repository,
                progress: widget.progress,
              ),
            ),
            TickerMode(
              enabled: _tab == 2,
              child: RencanaScreen(
                repository: widget.repository,
                progress: widget.progress,
              ),
            ),
            TickerMode(
              enabled: _tab == 3,
              child: LaporanScreen(
                repository: widget.repository,
                progress: widget.progress,
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
              centerAction: (
                tooltip: 'Catat baru',
                onTap: _primaryAction,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Isi tab dengan slide berarah mengikuti urutan menu di navbar: pindah
/// ke tab di kanan (indeks lebih besar) meluncur masuk dari kanan, ke
/// tab di kiri masuk dari kiri. Berlaku untuk semua tab, termasuk
/// deep-link dan tombol back — karena semua lewat indeks tab yang sama.
///
/// Semua anak tetap hidup seperti IndexedStack (scroll dan state tidak
/// hilang): tab lama diam di bawah, tab baru yang hidup meluncur masuk
/// di atasnya. Tanpa bekuan citra — halaman dipindah hidup-hidup lewat
/// GlobalKey sehingga tidak tergantung baca piksel GPU.
class _DirectionalTabView extends StatefulWidget {
  const _DirectionalTabView({required this.index, required this.children});

  /// Indeks tab yang harus tampil.
  final int index;

  /// Keempat tab.
  final List<Widget> children;

  @override
  State<_DirectionalTabView> createState() => _DirectionalTabViewState();
}

class _DirectionalTabViewState extends State<_DirectionalTabView>
    with SingleTickerProviderStateMixin {
  static const _rest = AlwaysStoppedAnimation<Offset>(Offset.zero);

  /// Kunci stabil per posisi: state tiap tab bertahan saat anak dipindah
  /// antara IndexedStack (diam) dan Stack (terbang).
  late List<GlobalKey> _pageKeys;

  late final _slideController = AnimationController(
    vsync: this,
    duration: QuestMotion.medium,
  );

  /// Indeks yang tampil saat diam.
  var _shown = 0;

  /// Penerbangan berjalan (dari → ke); null saat diam.
  ({int from, int to})? _flight;

  Animation<Offset> _slide = _rest;

  @override
  void initState() {
    super.initState();
    _pageKeys = List<GlobalKey>.generate(
      widget.children.length,
      (_) => GlobalKey(),
    );
    _shown = widget.index;
    _slideController.addStatusListener(_onSlideStatus);
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _onSlideStatus(AnimationStatus status) {
    // Mendarat: kembali ke IndexedStack semua-anak-tetap-hidup.
    if (status == AnimationStatus.completed && mounted) {
      setState(() {
        final flight = _flight;
        if (flight != null) _shown = flight.to;
        _flight = null;
        _slide = _rest;
      });
    }
  }

  @override
  void didUpdateWidget(covariant _DirectionalTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      // Tunda ke luar fase build agar setState animasi aman.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = widget.index;
        if (target != (_flight?.to ?? _shown)) _goTo(target);
      });
    }
  }

  void _goTo(int to) {
    // Dari tab yang sedang menuju/ditampilkan — mengikuti posisi nyata.
    final from = _flight?.to ?? _shown;
    if (to == from || to < 0 || to >= widget.children.length) return;
    // Masih terbang: mendaratkan seketika dulu, lalu mulai yang baru.
    // (Hanya terasa sebagai sentakan kecil pada tap beruntun.)
    if (_flight != null && _slideController.isAnimating) {
      _slideController.value = 1;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _shown = to);
      return;
    }
    final curved = CurvedAnimation(
      parent: _slideController,
      curve: QuestMotion.easeOut,
    );
    setState(() {
      _flight = (from: from, to: to);
      _slide = Tween<Offset>(
        // Target di kanan navbar masuk dari kanan, di kiri dari kiri.
        begin: Offset(to > from ? 1 : -1, 0),
        end: Offset.zero,
      ).animate(curved);
    });
    _slideController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      for (var i = 0; i < widget.children.length; i++)
        KeyedSubtree(key: _pageKeys[i], child: widget.children[i]),
    ];
    final flight = _flight;
    if (flight == null) {
      return IndexedStack(index: _shown, children: pages);
    }
    // Tab lama diam di bawah (TickerMode dari parent sudah mematikannya),
    // tab baru yang hidup meluncur masuk di atasnya — tanpa bekuan citra.
    return Stack(
      children: [
        // Tiap lapisan di-cache raster sendiri: geser = komposit murah,
        // bukan repaint ulang seluruh halaman tiap frame.
        RepaintBoundary(child: pages[flight.from]),
        RepaintBoundary(
          child: SlideTransition(position: _slide, child: pages[flight.to]),
        ),
      ],
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
            HomeTopBar(
              progress: widget.progress,
              repository: widget.repository,
              pipeline: widget.pipeline,
              ruleSet: widget.ruleSet,
              onOpenAnggaran: widget.onOpenAnggaran,
              onOpenBon: widget.onOpenBon,
            ),
            DraftAttentionBanner(
              repository: widget.repository,
              ruleSet: widget.ruleSet,
              progress: widget.progress,
              pipeline: widget.pipeline,
              onOpenAnggaran: widget.onOpenAnggaran,
              onOpenBon: widget.onOpenBon,
            ),
            TotalBalanceCard(
              repository: widget.repository,
              pipeline: widget.pipeline,
              ruleSet: widget.ruleSet,
              progress: widget.progress,
            ),
            BudgetSummaryCard(
              progress: widget.progress,
              onTap: widget.onOpenAnggaran,
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
