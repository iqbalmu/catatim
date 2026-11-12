part of '../home_cards.dart';

/// Tinggi bibir kartu bawah yang mengintip di bawah kartu utama.
const double _kPeekLipHeight = 42.0;

/// Jarak turun & skala kartu saat berada di tumpukan belakang.
const double _kBackCardOffsetY = 10.0;
const double _kBackCardScale = 0.95;

/// Wadah Hero Beranda Bertumpuk (Stacked Cards):
/// Menampilkan 2 kartu utama ([DailyPaceHeroCard] dan [TotalBalanceCard]) secara tumpang tindih.
/// Kedua kartu tetap ter-mount secara permanen di dalam render tree ([_StackedDeckLayout])
/// dengan [RepaintBoundary] masing-masing agar tidak pernah mengalami remount/flicker
/// ("ngedip-ngedip") saat di-geser maupun saat bertukar posisi.
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

  late final AnimationController _animController;
  final ValueNotifier<double> _dragDxNotifier = ValueNotifier<double>(0.0);
  late final Listenable _motionListenable;

  late Stream<Map<int, int>> _balancesStream;

  bool _isDragging = false;
  bool _isSwitching = false;
  bool _isSnappingBack = false;

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
    _balancesStream = widget.repository.watchAccountBalances();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addStatusListener(_onAnimStatus);
    _motionListenable = Listenable.merge([_animController, _dragDxNotifier]);
  }

  @override
  void didUpdateWidget(covariant StackedHeroCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _balancesStream = widget.repository.watchAccountBalances();
    }
  }

  @override
  void dispose() {
    _animController.removeStatusListener(_onAnimStatus);
    _animController.dispose();
    _dragDxNotifier.dispose();
    super.dispose();
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    if (_isSwitching || _isSnappingBack) {
      setState(() {
        _isSwitching = false;
        _isSnappingBack = false;
        _outgoingCard = null;
        _dragDxNotifier.value = 0.0;
      });
      _animController.reset();
    }
  }

  double _progressForDx(double dx) => (dx.abs() / 150.0).clamp(0.0, 1.0);

  void _onDragStart(DragStartDetails details) {
    if (_isSwitching) {
      // Jika user menyentuh lagi saat animasi tukar hampir selesai, selesaikan segera
      _animController.stop();
      setState(() {
        _isSwitching = false;
        _outgoingCard = null;
        _isDragging = true;
        _dragDxNotifier.value = 0.0;
      });
      return;
    }
    if (_isSnappingBack) {
      final t = Curves.easeOutCubic.transform(_animController.value);
      final currentDx = _startDx * (1.0 - t);
      _animController.stop();
      _animController.reset();
      setState(() {
        _isSnappingBack = false;
        _isDragging = true;
        _dragDxNotifier.value = currentDx;
      });
      return;
    }
    _isDragging = true;
    _dragDxNotifier.value = 0.0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final delta = details.primaryDelta ?? 0.0;
    final current = _dragDxNotifier.value;
    final factor = current.abs() > 140 ? 0.58 : 0.94;
    // Memperbarui ValueNotifier tanpa memanggil setState agar kartu tidak rebuild
    _dragDxNotifier.value = current + delta * factor;
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    final dx = _dragDxNotifier.value;
    final velocity = details.primaryVelocity ?? 0.0;
    final shouldSwitch = dx.abs() > 34.0 || velocity.abs() > 130.0;

    if (shouldSwitch) {
      final dir = dx.abs() > 10.0
          ? (dx >= 0 ? 1.0 : -1.0)
          : (velocity >= 0 ? 1.0 : -1.0);
      _commitSwitch(dir, velocity: velocity.abs());
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    final dx = _dragDxNotifier.value;
    if (dx.abs() < 0.5) {
      _isDragging = false;
      _dragDxNotifier.value = 0.0;
      return;
    }
    _startDx = dx;
    _startProgress = _progressForDx(dx);
    _isDragging = false;
    _isSnappingBack = true;
    _animController.duration = const Duration(milliseconds: 200);
    _animController.forward(from: 0.0);
  }

  void _commitSwitch(double direction, {double velocity = 0.0}) {
    if (_isSwitching) return;
    HapticFeedback.mediumImpact();

    final currentDx = _dragDxNotifier.value;
    final fastSwipe = velocity > 650.0;

    setState(() {
      _outgoingCard = _activeCard;
      _startDx = currentDx;
      _startProgress = _progressForDx(currentDx);
      _swipeDirection = direction >= 0 ? 1.0 : -1.0;
      _activeCard = _activeCard == 0 ? 1 : 0;
      _isDragging = false;
      _isSnappingBack = false;
      _isSwitching = true;
      _dragDxNotifier.value = 0.0;
    });

    _animController.duration = Duration(milliseconds: fastSwipe ? 210 : 260);
    _animController.forward(from: 0.0);
  }

  Widget _buildStaticCardShell(Widget card) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: card,
      ),
    );
  }

  Widget _buildTransformedSlot({
    required Key key,
    required _CardPose pose,
    required Widget child,
  }) {
    // Selalu pertahankan struktur widget Transform yang identik (baik saat diam
    // maupun bergerak) agar Element anak di bawahnya tidak pernah di-remount.
    return Transform.translate(
      key: key,
      offset: Offset(pose.dx, pose.dy),
      child: Transform.rotate(
        angle: pose.angle,
        child: Transform.scale(
          scale: pose.scale,
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int backCardIndex = _activeCard == 0 ? 1 : 0;
    final double screenWidth = MediaQuery.sizeOf(context).width;

    // Ketiga komponen utama di-build di luar AnimatedBuilder dan dibungkus
    // RepaintBoundary sehingga tidak pernah di-rebuild ataupun di-repaint
    // ulang pada setiap frame geseran jari.
    final Widget peekWidget = RepaintBoundary(
      child: _BackCardPeek(
        backCardIndex: backCardIndex,
        activeCardIndex: _activeCard,
        progress: widget.progress,
        balancesStream: _balancesStream,
        balanceObscured: _balanceObscured,
        onTap: () => _commitSwitch(-1.0),
      ),
    );

    final Widget card0Widget = _buildStaticCardShell(
      DailyPaceHeroCard(
        key: const ValueKey<int>(0),
        progress: widget.progress,
        onTap: widget.onOpenAnggaran,
        margin: EdgeInsets.zero,
      ),
    );

    final Widget card1Widget = _buildStaticCardShell(
      TotalBalanceCard(
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
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.sm, Spacing.m, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: AnimatedBuilder(
          animation: _motionListenable,
          builder: (context, _) {
            late final _CardPose pose0;
            late final _CardPose pose1;
            late final int topCardIndex;
            late final double heightLerp;
            final bool isIdle =
                !_isDragging &&
                !_isSwitching &&
                !_isSnappingBack &&
                _dragDxNotifier.value == 0.0;

            if (_isSwitching && _outgoingCard != null) {
              // KASUS A: Animasi pertukaran kartu (kontinu dari posisi lepas jari)
              final int outIdx = _outgoingCard!;
              final int inIdx = _activeCard;
              final double easeT = Curves.easeOutCubic.transform(
                _animController.value,
              );

              // Kartu yang keluar meluncur mulus hingga melewati tepi layar
              final double targetDx = _swipeDirection * (screenWidth + 24.0);
              final double outDx = _startDx + (targetDx - _startDx) * easeT;
              final double outAngle = (outDx * 0.0003).clamp(-0.045, 0.045);
              final outPose = _CardPose(
                dx: outDx,
                dy: 0.0,
                scale: 1.0,
                angle: outAngle,
              );

              // Kartu yang masuk naik mulus dari posisi belakang ke posisi depan
              final double p = _startProgress + (1.0 - _startProgress) * easeT;
              final inPose = _CardPose(
                dx: 0.0,
                dy: _kBackCardOffsetY * (1.0 - p),
                scale: _kBackCardScale + (1.0 - _kBackCardScale) * p,
                angle: 0.0,
              );

              pose0 = outIdx == 0 ? outPose : inPose;
              pose1 = outIdx == 1 ? outPose : inPose;
              topCardIndex = outIdx;
              heightLerp = inIdx == 1 ? p : (1.0 - p);
            } else if (_isSnappingBack) {
              // KASUS B: Batal geser (kembali ke tengah dengan mulus)
              final double easeT = Curves.easeOutCubic.transform(
                _animController.value,
              );
              final double dx = _startDx * (1.0 - easeT);
              final double p = _startProgress * (1.0 - easeT);
              final double angle = (dx * 0.0003).clamp(-0.045, 0.045);

              final frontPose = _CardPose(
                dx: dx,
                dy: 0.0,
                scale: 1.0,
                angle: angle,
              );
              final backPose = _CardPose(
                dx: 0.0,
                dy: _kBackCardOffsetY * (1.0 - p),
                scale: _kBackCardScale + (1.0 - _kBackCardScale) * p,
                angle: 0.0,
              );

              pose0 = _activeCard == 0 ? frontPose : backPose;
              pose1 = _activeCard == 1 ? frontPose : backPose;
              topCardIndex = _activeCard;
              heightLerp = _activeCard == 0 ? (p * 0.5) : (1.0 - p * 0.5);
            } else {
              // KASUS C: Sedang ditarik jari atau diam (idle)
              final double dx = _dragDxNotifier.value;
              final double p = _progressForDx(dx);
              final double angle = (dx * 0.0003).clamp(-0.045, 0.045);

              final frontPose = _CardPose(
                dx: dx,
                dy: 0.0,
                scale: 1.0,
                angle: angle,
              );
              final backPose = _CardPose(
                dx: 0.0,
                dy: _kBackCardOffsetY * (1.0 - p),
                scale: _kBackCardScale + (1.0 - _kBackCardScale) * p,
                angle: 0.0,
              );

              pose0 = _activeCard == 0 ? frontPose : backPose;
              pose1 = _activeCard == 1 ? frontPose : backPose;
              topCardIndex = _activeCard;
              heightLerp = _activeCard == 0 ? (p * 0.5) : (1.0 - p * 0.5);
            }

            return _StackedDeckLayout(
              topCardIndex: topCardIndex,
              interactiveCardIndex: _activeCard,
              heightLerp: heightLerp,
              isIdle: isIdle,
              children: [
                peekWidget,
                _buildTransformedSlot(
                  key: const ValueKey<String>('slot-0'),
                  pose: pose0,
                  child: card0Widget,
                ),
                _buildTransformedSlot(
                  key: const ValueKey<String>('slot-1'),
                  pose: pose1,
                  child: card1Widget,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CardPose {
  const _CardPose({
    required this.dx,
    required this.dy,
    required this.scale,
    required this.angle,
  });

  final double dx;
  final double dy;
  final double scale;
  final double angle;
}

class _StackedDeckParentData extends ContainerBoxParentData<RenderBox> {}

/// Custom MultiChildRenderObjectWidget yang menjaga [peek, card0, card1]
/// tetap berada pada slot yang sama selamanya tanpa pernah meng-unmount
/// atau mengubah urutan Element anak saat z-order berganti.
class _StackedDeckLayout extends MultiChildRenderObjectWidget {
  const _StackedDeckLayout({
    required this.topCardIndex,
    required this.interactiveCardIndex,
    required this.heightLerp,
    required this.isIdle,
    required super.children,
  }) : assert(children.length == 3);

  final int topCardIndex;
  final int interactiveCardIndex;
  final double heightLerp;
  final bool isIdle;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderStackedDeck(
      topCardIndex: topCardIndex,
      interactiveCardIndex: interactiveCardIndex,
      heightLerp: heightLerp,
      isIdle: isIdle,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderStackedDeck renderObject,
  ) {
    renderObject
      ..topCardIndex = topCardIndex
      ..interactiveCardIndex = interactiveCardIndex
      ..heightLerp = heightLerp
      ..isIdle = isIdle;
  }
}

class _RenderStackedDeck extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _StackedDeckParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _StackedDeckParentData> {
  _RenderStackedDeck({
    required this._topCardIndex,
    required this._interactiveCardIndex,
    required this._heightLerp,
    required this._isIdle,
  });

  int _topCardIndex;
  int get topCardIndex => _topCardIndex;
  set topCardIndex(int value) {
    if (_topCardIndex == value) return;
    _topCardIndex = value;
    markNeedsPaint();
  }

  int _interactiveCardIndex;
  int get interactiveCardIndex => _interactiveCardIndex;
  set interactiveCardIndex(int value) {
    if (_interactiveCardIndex == value) return;
    _interactiveCardIndex = value;
    markNeedsSemanticsUpdate();
  }

  double _heightLerp;
  double get heightLerp => _heightLerp;
  set heightLerp(double value) {
    if ((_heightLerp - value).abs() < 0.0005) return;
    _heightLerp = value;
    markNeedsLayout();
  }

  bool _isIdle;
  bool get isIdle => _isIdle;
  set isIdle(bool value) {
    if (_isIdle == value) return;
    _isIdle = value;
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _StackedDeckParentData) {
      child.parentData = _StackedDeckParentData();
    }
  }

  @override
  void performLayout() {
    final RenderBox? peek = firstChild;
    if (peek == null) {
      size = constraints.smallest;
      return;
    }
    final RenderBox card0 = childAfter(peek)!;
    final RenderBox card1 = childAfter(card0)!;

    final double maxWidth = constraints.maxWidth;
    final BoxConstraints cardConstraints = BoxConstraints(
      minWidth: maxWidth,
      maxWidth: maxWidth,
    );

    card0.layout(cardConstraints, parentUsesSize: true);
    card1.layout(cardConstraints, parentUsesSize: true);

    final double h0 = card0.size.height;
    final double h1 = card1.size.height;
    final double activeCardHeight =
        lerpDouble(h0, h1, _heightLerp.clamp(0.0, 1.0)) ?? h0;
    final double totalHeight = activeCardHeight + _kPeekLipHeight;

    final double peekWidth = (maxWidth - 16.0).clamp(0.0, double.infinity);
    final double peekHeight =
        (totalHeight - 14.0).clamp(_kPeekLipHeight, double.infinity);

    peek.layout(
      BoxConstraints.tightFor(width: peekWidth, height: peekHeight),
      parentUsesSize: false,
    );

    (peek.parentData! as _StackedDeckParentData).offset =
        const Offset(8.0, 14.0);
    (card0.parentData! as _StackedDeckParentData).offset = Offset.zero;
    (card1.parentData! as _StackedDeckParentData).offset = Offset.zero;

    size = constraints.constrain(Size(maxWidth, totalHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? peek = firstChild;
    if (peek == null) return;
    final RenderBox card0 = childAfter(peek)!;
    final RenderBox card1 = childAfter(card0)!;

    // 1. Gambar bibir kartu belakang (_BackCardPeek) terlebih dahulu
    final Offset peekOffset =
        (peek.parentData! as _StackedDeckParentData).offset;
    context.paintChild(peek, offset + peekOffset);

    final RenderBox topCard = _topCardIndex == 0 ? card0 : card1;
    final RenderBox bottomCard = _topCardIndex == 0 ? card1 : card0;
    final double activeCardHeight =
        (size.height - _kPeekLipHeight).clamp(0.0, double.infinity);

    // 2. Gambar kartu bawah (tetap di dalam scene graph agar layer GPU hangat,
    //    namun dipotong agar tidak pernah menembus bibir _BackCardPeek)
    final Rect clipRect = _isIdle
        ? Rect.fromLTWH(
            16.0,
            16.0,
            (size.width - 32.0).clamp(0.0, double.infinity),
            (activeCardHeight - 32.0).clamp(0.0, double.infinity),
          )
        : Rect.fromLTRB(
            -size.width,
            -40.0,
            size.width * 2,
            activeCardHeight,
          );

    context.pushClipRect(
      needsCompositing,
      offset,
      clipRect,
      (PaintingContext ctx, Offset ofs) {
        ctx.paintChild(bottomCard, ofs);
      },
    );

    // 3. Gambar kartu paling atas (solid penuh, tanpa Opacity saveLayer)
    context.paintChild(topCard, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? peek = firstChild;
    if (peek == null) return false;
    final RenderBox card0 = childAfter(peek)!;
    final RenderBox card1 = childAfter(card0)!;

    // Hanya kartu aktif yang menerima interaksi sentuhan
    final RenderBox activeCard = _interactiveCardIndex == 0 ? card0 : card1;
    if (activeCard.hitTest(result, position: position)) {
      return true;
    }

    // Jika tidak mengenai kartu aktif, teruskan ke bibir _BackCardPeek di bawah
    final Offset peekOffset =
        (peek.parentData! as _StackedDeckParentData).offset;
    return result.addWithPaintOffset(
      offset: peekOffset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        return peek.hitTest(result, position: transformed);
      },
    );
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final RenderBox? peek = firstChild;
    if (peek == null) return;
    final RenderBox card0 = childAfter(peek)!;
    final RenderBox card1 = childAfter(card0)!;
    final RenderBox activeCard = _interactiveCardIndex == 0 ? card0 : card1;
    visitor(activeCard);
    visitor(peek);
  }
}

/// Visual kartu bagian bawah yang mengintip dari balik kartu aktif.
/// Menampilkan ikon, nama kartu di belakang, dan ringkasan nilainya agar user
/// selalu tahu kartu apa yang ada di belakang tumpukan.
class _BackCardPeek extends StatefulWidget {
  const _BackCardPeek({
    required this.backCardIndex,
    required this.activeCardIndex,
    required this.progress,
    required this.balancesStream,
    required this.balanceObscured,
    required this.onTap,
  });

  final int backCardIndex;
  final int activeCardIndex;
  final ProgressService progress;
  final Stream<Map<int, int>> balancesStream;
  final bool balanceObscured;
  final VoidCallback onTap;

  @override
  State<_BackCardPeek> createState() => _BackCardPeekState();
}

class _BackCardPeekState extends State<_BackCardPeek> {
  Map<int, int> _cachedBalances = const {};

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return Semantics(
      button: true,
      label: widget.backCardIndex == 1
          ? 'Kartu di belakang: Total Saldo. Ketuk atau geser untuk menampilkan.'
          : 'Kartu di belakang: Pace Harian. Ketuk atau geser untuk menampilkan.',
      child: GestureDetector(
        onTap: widget.onTap,
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
              child: StreamBuilder<Map<int, int>>(
                stream: widget.balancesStream,
                builder: (context, snap) {
                  if (snap.hasData) {
                    _cachedBalances = snap.data!;
                  }
                  final total = _cachedBalances.values.fold<int>(
                    0,
                    (sum, val) => sum + val,
                  );

                  return AnimatedBuilder(
                    animation: widget.progress,
                    builder: (context, _) {
                      return Row(
                        children: [
                          // ── Identitas Kartu Belakang (Ikon + Nama + Ringkasan) ──
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              layoutBuilder: (currentChild, previousChildren) =>
                                  Stack(
                                    alignment: Alignment.centerLeft,
                                    children: <Widget>[
                                      ...previousChildren,
                                      ?currentChild,
                                    ],
                                  ),
                              child: widget.backCardIndex == 1
                                  ? _buildBalancePeekInfo(context, q, total)
                                  : _buildPacePeekInfo(context, q),
                            ),
                          ),
                          const SizedBox(width: Spacing.xs),

                          // ── Indikator Tumpukan & Petunjuk Geser ──
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: widget.activeCardIndex == 0 ? 12 : 5,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: widget.activeCardIndex == 0
                                      ? q.primary
                                      : q.muted.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Container(
                                width: widget.activeCardIndex == 1 ? 12 : 5,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: widget.activeCardIndex == 1
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
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalancePeekInfo(
    BuildContext context,
    QuestPalette q,
    int total,
  ) {
    final mutedStyle = context.qSmall(11.5).copyWith(
      color: q.muted,
      fontWeight: FontWeight.w600,
    );

    return Row(
      key: const ValueKey<String>('peek-balance'),
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
            color: q.primaryText,
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'Total Saldo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.qSmall(11.5).copyWith(
                        color: q.text,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Text('  ·  ', style: mutedStyle),
              if (widget.balanceObscured)
                Text('••••••', style: mutedStyle)
              else
                QuestMoney(amount: total, style: mutedStyle),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPacePeekInfo(BuildContext context, QuestPalette q) {
    final summary = widget.progress.latest;
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
      key: const ValueKey<String>('peek-pace'),
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
            color: q.primaryText,
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
  }
}
