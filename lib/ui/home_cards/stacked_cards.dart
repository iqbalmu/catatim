part of '../home_cards.dart';

/// Tinggi bibir kartu bawah yang mengintip di bawah kartu utama.
const double _kPeekLipHeight = 42.0;

/// Wadah Hero Beranda Bertumpuk (Stacked Cards):
/// Menampilkan 2 kartu utama ([DailyPaceHeroCard] dan [TotalBalanceCard]) secara tumpang tindih.
/// Kartu bagian bawah terlihat mengintip di bawah kartu utama lengkap dengan nama & ringkasan singkatnya.
/// Geser ke kiri maupun ke kanan secara interaktif akan saling menukar (switch) kedua kartu.
class StackedHeroCards extends StatefulWidget {
  const StackedHeroCards({
    super.key,
    required this.progress,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
    required this.onOpenAnggaran,
    this.initialCard = 0,
  });

  final ProgressService progress;
  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;
  final VoidCallback onOpenAnggaran;
  final int initialCard;

  @override
  State<StackedHeroCards> createState() => _StackedHeroCardsState();
}

class _StackedHeroCardsState extends State<StackedHeroCards>
    with SingleTickerProviderStateMixin {
  late int _activeCard;
  int? _outgoingCard;
  late AnimationController _animController;

  bool _isDragging = false;
  bool _isSwitching = false;
  bool _isSnappingBack = false;

  double _dragDx = 0.0;
  double _startDx = 0.0;
  double _startProgress = 0.0;
  double _swipeDirection = -1.0;

  /// Menyimpan status sembunyi saldo agar tetap konsisten saat kartu di-switch
  /// dan tidak bocor pada bibir kartu yang mengintip di belakang.
  bool _balanceObscured = false;

  @override
  void initState() {
    super.initState();
    _activeCard = widget.initialCard;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  double get _dragProgress => (_dragDx.abs() / 160.0).clamp(0.0, 1.0);

  void _onDragStart(DragStartDetails details) {
    if (_isSwitching || _isSnappingBack) return;
    setState(() {
      _isDragging = true;
      _dragDx = 0.0;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isSwitching) return;
    final delta = details.primaryDelta ?? 0.0;
    setState(() {
      // Berikan sedikit resistensi lembut saat ditarik jauh
      final factor = _dragDx.abs() > 140 ? 0.55 : 0.92;
      _dragDx += delta * factor;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging || _isSwitching) return;
    final velocity = details.primaryVelocity ?? 0.0;
    final shouldSwitch = _dragDx.abs() > 36.0 || velocity.abs() > 140.0;

    if (shouldSwitch) {
      final dir = _dragDx.abs() > 12.0
          ? (_dragDx >= 0 ? 1.0 : -1.0)
          : (velocity >= 0 ? 1.0 : -1.0);
      _commitSwitch(dir);
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    if (_dragDx == 0.0) {
      setState(() => _isDragging = false);
      return;
    }
    _startDx = _dragDx;
    _isDragging = false;
    _isSnappingBack = true;
    _animController.duration = const Duration(milliseconds: 200);
    _animController.forward(from: 0.0).then((_) {
      if (!mounted) return;
      setState(() {
        _isSnappingBack = false;
        _dragDx = 0.0;
      });
      _animController.reset();
    });
  }

  void _commitSwitch([double direction = -1.0]) {
    if (_isSwitching) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _outgoingCard = _activeCard;
      _startDx = _dragDx;
      _startProgress = _dragProgress;
      _swipeDirection = direction >= 0 ? 1.0 : -1.0;
      _activeCard = _activeCard == 0 ? 1 : 0;
      _isDragging = false;
      _isSnappingBack = false;
      _isSwitching = true;
      _dragDx = 0.0;
    });

    _animController.duration = const Duration(milliseconds: 320);
    _animController.forward(from: 0.0).then((_) {
      if (!mounted) return;
      setState(() {
        _isSwitching = false;
        _outgoingCard = null;
      });
      _animController.reset();
    });
  }

  Widget _buildCard(int index) {
    if (index == 0) {
      return DailyPaceHeroCard(
        key: const ValueKey<int>(0),
        progress: widget.progress,
        onTap: widget.onOpenAnggaran,
        margin: EdgeInsets.zero,
      );
    }
    return TotalBalanceCard(
      key: const ValueKey<int>(1),
      repository: widget.repository,
      pipeline: widget.pipeline,
      ruleSet: widget.ruleSet,
      progress: widget.progress,
      margin: EdgeInsets.zero,
      initialObscured: _balanceObscured,
      onObscuredChanged: (val) {
        if (mounted && _balanceObscured != val) {
          setState(() => _balanceObscured = val);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final int backCardIndex = _activeCard == 0 ? 1 : 0;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.xs, Spacing.m, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── 1. Kartu Bawah yang Mengintip (Menampilkan identitas kartu di belakang) ──
            Positioned(
              top: 14,
              left: 8,
              right: 8,
              bottom: 0,
              child: _BackCardPeek(
                backCardIndex: backCardIndex,
                activeCardIndex: _activeCard,
                progress: widget.progress,
                repository: widget.repository,
                balanceObscured: _balanceObscured,
                onTap: () => _commitSwitch(-1.0),
              ),
            ),

            // ── 2. Saat sedang di-drag, tampilkan preview kartu belakang yang ikut naik ──
            if (_isDragging && _dragDx.abs() > 2)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Transform.translate(
                    offset: Offset(0, 14.0 * (1.0 - _dragProgress)),
                    child: Transform.scale(
                      scale: 0.94 + (0.06 * _dragProgress),
                      alignment: Alignment.topCenter,
                      child: Opacity(
                        opacity: (0.65 + (0.35 * _dragProgress)).clamp(0.0, 1.0),
                        child: _buildCard(backCardIndex),
                      ),
                    ),
                  ),
                ),
              ),

            // ── 3. Kartu Utama (Sizing Child dengan AnimatedSize agar tinggi mulus) ──
            Padding(
              padding: const EdgeInsets.only(bottom: _kPeekLipHeight),
              child: AnimatedSize(
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    // KASUS A: Sedang animasi tukar kartu (child ini adalah kartu BARU yang naik ke depan)
                    if (_isSwitching) {
                      final t = Curves.easeOutCubic.transform(
                        _animController.value,
                      );
                      final p = _startProgress + (1.0 - _startProgress) * t;
                      final scale = 0.94 + (0.06 * p);
                      final dy = 14.0 * (1.0 - p);
                      final opacity = (0.72 + (0.28 * p)).clamp(0.0, 1.0);

                      return Transform.translate(
                        offset: Offset(0, dy),
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.topCenter,
                          child: Opacity(
                            opacity: opacity,
                            child: _ElevatedCardShell(
                              elevationProgress: p,
                              child: child!,
                            ),
                          ),
                        ),
                      );
                    }

                    // KASUS B: Sedang snap-back (batal drag)
                    if (_isSnappingBack) {
                      final t = Curves.easeOutBack.transform(
                        _animController.value,
                      );
                      final dx = _startDx * (1.0 - t);
                      final rot = (dx * 0.0004).clamp(-0.06, 0.06);
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: Transform.rotate(
                          angle: rot,
                          child: _ElevatedCardShell(
                            elevationProgress: 1.0,
                            child: child!,
                          ),
                        ),
                      );
                    }

                    // KASUS C: Sedang di-drag jari atau diam (idle)
                    final dx = _dragDx;
                    final rot = (dx * 0.0004).clamp(-0.06, 0.06);
                    final scale = 1.0 - (_dragProgress * 0.02);

                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: Transform.rotate(
                        angle: rot,
                        child: Transform.scale(
                          scale: scale,
                          child: _ElevatedCardShell(
                            elevationProgress: 1.0,
                            child: child!,
                          ),
                        ),
                      ),
                    );
                  },
                  child: _buildCard(_activeCard),
                ),
              ),
            ),

            // ── 4. Kartu Lama yang Meluncur Keluar saat Transisi Switch ──
            if (_isSwitching && _outgoingCard != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      final rawT = _animController.value;
                      final easeT = Curves.easeOutCubic.transform(rawT);
                      final targetDx = _swipeDirection * screenWidth * 0.88;
                      final currentDx = _startDx + (targetDx - _startDx) * easeT;
                      final dy = 8.0 * easeT;
                      final rot = (currentDx * 0.00045).clamp(-0.08, 0.08);
                      final scale = 0.98 - (0.04 * easeT);
                      final opacity = (1.0 - Curves.easeIn.transform(rawT))
                          .clamp(0.0, 1.0);

                      return Transform.translate(
                        offset: Offset(currentDx, dy),
                        child: Transform.rotate(
                          angle: rot,
                          child: Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: opacity,
                              child: _ElevatedCardShell(
                                elevationProgress: 1.0 - easeT,
                                child: child!,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: _buildCard(_outgoingCard!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pembungkus bayangan kartu depan agar tampak jelas melayang di atas kartu belakang.
class _ElevatedCardShell extends StatelessWidget {
  const _ElevatedCardShell({
    required this.child,
    required this.elevationProgress,
  });

  final Widget child;
  final double elevationProgress;

  @override
  Widget build(BuildContext context) {
    final alpha = (0.09 * elevationProgress).clamp(0.0, 0.12);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: alpha),
            blurRadius: 16 * elevationProgress,
            offset: Offset(0, 6 * elevationProgress),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Visual kartu bagian bawah yang mengintip dari balik kartu aktif.
/// Menampilkan ikon, nama kartu di belakang, dan ringkasan nilainya agar user
/// selalu tahu kartu apa yang ada di belakang tumpukan.
class _BackCardPeek extends StatelessWidget {
  const _BackCardPeek({
    required this.backCardIndex,
    required this.activeCardIndex,
    required this.progress,
    required this.repository,
    required this.balanceObscured,
    required this.onTap,
  });

  final int backCardIndex;
  final int activeCardIndex;
  final ProgressService progress;
  final LedgerRepository repository;
  final bool balanceObscured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return Semantics(
      button: true,
      label: backCardIndex == 1
          ? 'Kartu di belakang: Total Saldo. Ketuk atau geser untuk menampilkan.'
          : 'Kartu di belakang: Pace Harian. Ketuk atau geser untuk menampilkan.',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: q.surface2,
            borderRadius: BorderRadius.circular(AppRadius.sheet),
            border: Border.all(
              color: q.line,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: _kPeekLipHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  // ── Identitas Kartu Belakang (Ikon + Nama + Ringkasan) ──
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.centerLeft,
                        children: <Widget>[
                          ...previousChildren,
                          ?currentChild,
                        ],
                      ),
                      child: backCardIndex == 1
                          ? _buildBalancePeekInfo(context, q)
                          : _buildPacePeekInfo(context, q),
                    ),
                  ),
                  const SizedBox(width: Spacing.xs),

                  // ── Indikator Tumpukan & Petunjuk Geser ──
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: activeCardIndex == 0 ? 12 : 5,
                        height: 4,
                        decoration: BoxDecoration(
                          color: activeCardIndex == 0
                              ? q.primary
                              : q.muted.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Container(
                        width: activeCardIndex == 1 ? 12 : 5,
                        height: 4,
                        decoration: BoxDecoration(
                          color: activeCardIndex == 1
                              ? q.primary
                              : q.muted.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.swap_horiz_rounded,
                        size: 14,
                        color: q.muted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalancePeekInfo(BuildContext context, QuestPalette q) {
    return StreamBuilder<Map<int, int>>(
      key: const ValueKey<String>('peek-balance'),
      stream: repository.watchAccountBalances(),
      builder: (context, snap) {
        final balances = snap.data ?? const {};
        final total = balances.values.fold<int>(0, (sum, val) => sum + val);
        final valueText = balanceObscured ? '••••••' : Money.format(total);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: q.primaryLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 12,
                color: q.primary,
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Total Saldo',
                      style: context.qSmall(11.5).copyWith(
                            color: q.text,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    TextSpan(
                      text: '  ·  $valueText',
                      style: context.qSmall(11.5).copyWith(
                            color: q.muted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPacePeekInfo(BuildContext context, QuestPalette q) {
    return AnimatedBuilder(
      key: const ValueKey<String>('peek-pace'),
      animation: progress,
      builder: (context, _) {
        final summary = progress.latest;
        final safe = summary?.dailyPace?.safeToSpend;
        final String subtitle;
        final Color subtitleColor;

        if (safe == null) {
          subtitle = 'Belum diatur';
          subtitleColor = q.muted;
        } else if (safe < 0) {
          subtitle = 'Defisit ${Money.format(safe.abs())}';
          subtitleColor = q.bad;
        } else {
          subtitle = 'Sisa ${Money.format(safe)}/hr';
          subtitleColor = q.muted;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: q.primaryLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.speed_rounded,
                size: 12,
                color: q.primary,
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Pace Harian',
                      style: context.qSmall(11.5).copyWith(
                            color: q.text,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    TextSpan(
                      text: '  ·  $subtitle',
                      style: context.qSmall(11.5).copyWith(
                            color: subtitleColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
