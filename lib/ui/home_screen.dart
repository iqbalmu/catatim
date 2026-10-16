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
import 'bon_screen.dart';
import 'capture_log_screen.dart';
import 'home_cards.dart';
import 'menu_screen.dart';
import 'quest.dart';
import 'rekap_screen.dart';
import 'rencana_screen.dart';
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
        body: _DirectionalTabView(
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
          stream: _bonsWatch,
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
        borderRadius: BorderRadius.circular(AppRadius.tile),
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
                  topRight: Radius.circular(AppRadius.tile),
                  bottomLeft: Radius.circular(AppRadius.cell),
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
                  topLeft: Radius.circular(AppRadius.cell),
                  bottomRight: Radius.circular(AppRadius.cell),
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

/// Tombol ⋯: buka layar Menu (Kelola akun, Rencana·Batas, Backup, Aturan
/// capture).
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
    return QuestIconButton(
      icon: Icons.more_horiz_rounded,
      tooltip: 'Menu',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MenuScreen(
            repository: repository,
            engine: pipeline.engine,
            progress: progress,
            onOpenRencana: onOpenRencana,
          ),
        ),
      ),
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
