import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../game/duit_stage.dart';
import '../game/progress.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'bank_accounts_screen.dart';
import 'bon_screen.dart';
import 'home_cards.dart';
import 'menu_screen.dart';
import 'notif_screen.dart';
import 'quest.dart';
import 'rekap_screen.dart';
import 'rencana_screen.dart';
import 'transaction_sheet.dart';

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

  /// Kunci layar Rekap untuk deep-link bersegmen dari Beranda.
  final _rekapKey = GlobalKey<RekapScreenState>();

  /// Deep-link Beranda (BatasCard/strip) → Rencana·Batas.
  void _openRencanaBatas() => setState(() => _tab = 2);

  /// Deep-link Beranda → Rekap pada segmen tertentu, sesuai janji label.
  void _openRekap(RekapSegment segment) {
    setState(() => _tab = 1);
    _rekapKey.currentState?.openSegment(segment);
  }

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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        // Back di tab non-Beranda kembali ke Beranda; di Beranda keluar.
        if (!didPop && _tab != 0) setState(() => _tab = 0);
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: context.q.bg,
            // Konten mengalir di belakang navbar floating; tiap tab memberi
            // clearance lewat MediaQuery.padding.bottom yang disuntik
            // Scaffold.
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
                    onOpenRekap: () =>
                        _openRekap(RekapSegment.transaksi),
                    onOpenRencanaBatas: _openRencanaBatas,
                  ),
                ),
                TickerMode(
                  enabled: _tab == 1,
                  child: RekapScreen(
                    key: _rekapKey,
                    repository: widget.repository,
                    progress: widget.progress,
                  ),
                ),
                TickerMode(
                  enabled: _tab == 2,
                  child: RencanaScreen(
                    key: _rencanaKey,
                    repository: widget.repository,
                    progress: widget.progress,
                  ),
                ),
                TickerMode(
                  enabled: _tab == 3,
                  child: BonTab(repository: widget.repository),
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
          // Lonceng + ⋯ fix seperti navbar: hidup di shell (di atas
          // Scaffold), tidak ikut slide pindah tab. Posisi meniru tata
          // letak QuestHeader (SafeArea + padding s/m).
          Positioned(
            top: MediaQuery.paddingOf(context).top + Spacing.s,
            right: Spacing.m,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NotifBell(
                  repository: widget.repository,
                  pipeline: widget.pipeline,
                  progress: widget.progress,
                  ruleSet: widget.ruleSet,
                  onOpenRencana: _openRencanaBatas,
                  onOpenBon: () => setState(() => _tab = 3),
                ),
                const SizedBox(width: Spacing.s),
                _HomeMenu(
                  repository: widget.repository,
                  pipeline: widget.pipeline,
                  ruleSet: widget.ruleSet,
                ),
              ],
            ),
          ),
        ],
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


/// Lonceng notifikasi. Badge = ada item perhatian: draf menunggu
/// keputusan, izin belum aktif, entri tak terbaca, atau bon tua belum
/// lunas. Dihitung dari data yang sama dengan layar Notifikasi.
class _NotifBell extends StatefulWidget {
  const _NotifBell({
    required this.repository,
    required this.pipeline,
    required this.progress,
    required this.ruleSet,
    required this.onOpenRencana,
    required this.onOpenBon,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final ProgressService progress;
  final RuleSet ruleSet;
  final VoidCallback onOpenRencana;
  final VoidCallback onOpenBon;

  @override
  State<_NotifBell> createState() => _NotifBellState();
}

class _NotifBellState extends State<_NotifBell> {
  /// Izin listener di-hoist agar tidak dibuat ulang tiap build.
  late final Future<bool> _listenerEnabled =
      widget.pipeline.channel.isListenerEnabled();

  late final Stream<List<Bon>> _bons = widget.repository.watchBons();
  late final Stream<List<CaptureLog>> _logs =
      widget.repository.watchCaptureLog();
  late final Stream<List<Draft>> _drafts = widget.repository.watchDrafts();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _listenerEnabled,
      builder: (context, listenerSnap) {
        final enabled = listenerSnap.data ?? false;
        return StreamBuilder<List<Draft>>(
          stream: _drafts,
          builder: (context, draftSnap) {
            final draftCount = draftSnap.data?.length ?? 0;
            return StreamBuilder<List<CaptureLog>>(
              stream: _logs,
              builder: (context, logSnap) {
                final failed = (logSnap.data ?? const <CaptureLog>[])
                    .where((l) => !l.parsed)
                    .length;
                return StreamBuilder<List<Bon>>(
                  stream: _bons,
                  builder: (context, bonSnap) {
                    final aging = (bonSnap.data ?? const <Bon>[])
                        .where((b) =>
                            b.settledAt == null &&
                            bonNeedsBadge(b.occurredAt))
                        .length;
                    final hasAttention =
                        draftCount > 0 || !enabled || failed > 0 || aging > 0;
                    return QuestIconButton(
                      icon: Icons.notifications_active_outlined,
                      tooltip: 'Notifikasi',
                      badge: hasAttention,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotificationScreen(
                            repository: widget.repository,
                            pipeline: widget.pipeline,
                            progress: widget.progress,
                            ruleSet: widget.ruleSet,
                            onOpenRencana: widget.onOpenRencana,
                            onOpenBon: widget.onOpenBon,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Tombol ⋯: buka layar Menu (Catat otomatis, Bank & akun, Backup).
class _HomeMenu extends StatelessWidget {
  const _HomeMenu({
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;

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
            pipeline: pipeline,
            ruleSet: ruleSet,
          ),
        ),
      ),
    );
  }
}

/// Beranda ala mock pastel: panggung Duit di atas, lalu kartu uang, arus
/// bulan, insight 7 hari, dan transaksi terbaru. Warna tetap palet Quest;
/// pencatatan via tombol + tengah navbar.
class _BerandaTab extends StatefulWidget {
  const _BerandaTab({
    required this.repository,
    required this.pipeline,
    required this.progress,
    required this.ruleSet,
    required this.onOpenRekap,
    required this.onOpenRencanaBatas,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final ProgressService progress;
  final RuleSet ruleSet;
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
        // Puncak layar dipakai panggung Duit — header tinggal judul kecil
        // supaya bagian atas lapang (mockup L1).
        compact: true,
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
          // Panggung Duit: karakter di tengah, kalimatnya di bawah.
          DuitStage(service: widget.progress),
          const SizedBox(height: Spacing.m),
          UangCard(
            repository: widget.repository,
            progress: widget.progress,
            onTap: widget.onOpenRencanaBatas,
            onTapAccounts: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BankAccountsScreen(
                  repository: widget.repository,
                  pipeline: widget.pipeline,
                  ruleSet: widget.ruleSet,
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.m),
          ArusCard(service: widget.progress, onTap: widget.onOpenRekap),
          const SizedBox(height: Spacing.m),
          InsightTujuhHariCard(
            repository: widget.repository,
            onTap: widget.onOpenRekap,
          ),
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
