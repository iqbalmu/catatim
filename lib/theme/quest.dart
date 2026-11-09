import 'package:flutter/material.dart';

import '../core/money.dart';
import 'tokens.dart';

/// Palet identitas "Mainan Hangat" v2.1 — hangat, empuk, dari piksel
/// Pochy (ADR-010). Satu tema; tanpa dark mode. Semua widget custom
/// membaca warna dari sini, bukan dari default Material, supaya
/// identitas tidak bocor ke mana-mana.
class QuestPalette {
  const QuestPalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.body,
    required this.muted,
    required this.good,
    required this.warn,
    required this.warnTint,
    required this.bad,
    required this.honey,
    required this.honeyInk,
    required this.primary,
    required this.primaryDeep,
    required this.primaryLight,
    required this.violet,
    required this.shadow,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color text;
  final Color body;
  final Color muted;
  final Color good;
  final Color warn;
  final Color warnTint;
  final Color bad;
  final Color honey;
  final Color honeyInk;
  final Color primary;
  final Color primaryDeep;
  final Color primaryLight;
  final Color violet;
  final Color shadow;

  static const light = QuestPalette(
    bg: SeedColors.bg,
    surface: SeedColors.surface,
    surface2: SeedColors.surface2,
    line: SeedColors.line,
    text: SeedColors.ink,
    body: SeedColors.body,
    muted: SeedColors.muted,
    good: SeedColors.incoming,
    warn: SeedColors.warn,
    warnTint: SeedColors.warnTint,
    bad: SeedColors.outgoing,
    honey: SeedColors.honey,
    honeyInk: SeedColors.honeyInk,
    primary: SeedColors.primary,
    primaryDeep: SeedColors.primaryDeep,
    primaryLight: SeedColors.primaryLight,
    violet: SeedColors.violet,
    shadow: Color(0x080F172A),
  );

  /// Aksen mint (syal Pochy) — netral-aktif: segmented on, status tenang.
  static const mint = SeedColors.mintDeep;
  static const mintTint = SeedColors.mintTint;
  static const mintInk = SeedColors.mintInk;
}
/// Akses cepat palet + tipografi khas Quest dari BuildContext.
extension QuestTheme on BuildContext {
  /// Palet tunggal (tanpa dark mode — ADR-010).
  QuestPalette get q => QuestPalette.light;

  /// Angka display besar, tabular agar digit sejajar.
  TextStyle qDisplay([double size = 40]) {
    return TextStyle(
      fontSize: size,
      height: 1.05,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.5,
      color: q.text,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  TextStyle qTitle([double size = 17]) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: q.text,
    );
  }

  TextStyle qBody([double size = 14]) {
    return TextStyle(
      fontSize: size,
      color: q.body,
      height: 1.45,
      fontWeight: FontWeight.w500,
    );
  }

  TextStyle qSmall([double size = 12]) {
    return TextStyle(
      fontSize: size,
      color: q.muted,
      height: 1.4,
      fontWeight: FontWeight.w500,
    );
  }

  /// Label kecil caps dengan spasi lebar, untuk eyebrow/section.
  TextStyle qEyebrow([double size = 11]) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
      color: q.muted,
    );
  }

  TextStyle qAmount(double size, {required bool incoming}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: incoming ? q.good : q.bad,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

/// Durasi + kurva baku. Interaksi sering: hanya umpan balik tipis
/// (press scale, QuestSwap) — tanpa animasi penuh; sisanya < 300ms,
/// keluar selalu ease-out.
class QuestMotion {
  QuestMotion._();

  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 220);
  static const sheet = Duration(milliseconds: 320);
  static const enter = Duration(milliseconds: 320);
  static const staggerStep = Duration(milliseconds: 65);
  static const grow = Duration(milliseconds: 620);

  static const easeOut = Cubic(0.23, 1, 0.32, 1);
  static const progressCurve = Curves.easeOutCubic;
  static const drawer = Cubic(0.32, 0.72, 0, 1);

  /// Skala umpan-balik tekan, khas tombol game.
  static const double pressScale = 0.96;

  /// Curve spring untuk press/FAB — kenyal, konsisten bob maskot
  /// (bounce ~6%; ADR-010, DESIGN.md v2.1).
  static const Cubic spring = Cubic(0.34, 1.56, 0.64, 1);
}

/// Transisi pindah screen khas Quest: slide penuh dari kanan dengan
/// parallax mundur pada screen di bawahnya + bayangan tepi berdimensi;
/// saat pop kembali meluncur keluar ke kanan.
class QuestPageTransitionsBuilder extends PageTransitionsBuilder {
  const QuestPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slideIn = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).chain(CurveTween(curve: QuestMotion.easeOut));

    final parallaxOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.25, 0),
    ).chain(CurveTween(curve: QuestMotion.easeOut));

    final edgeShadow = DecoratedBoxTransition(
      decoration: DecorationTween(
        begin: const BoxDecoration(),
        end: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x180F172A),
              blurRadius: 24,
              offset: Offset(-6, 0),
            ),
          ],
        ),
      ).animate(
        CurvedAnimation(parent: animation, curve: QuestMotion.easeOut),
      ),
      child: child,
    );

    return SlideTransition(
      position: secondaryAnimation.drive(parallaxOut),
      child: SlideTransition(
        position: animation.drive(slideIn),
        child: edgeShadow,
      ),
    );
  }
}

/// Ganti nilai yang berubah karena aksi user (saldo, jumlah draf) dengan
/// transisi tipis: fade + geser kecil naik, kurva dan durasi QuestMotion.
/// Anak wajib berganti key agar animasi terpicu.
class QuestSwap extends StatelessWidget {
  const QuestSwap({super.key, required this.child, this.slide = true});

  final Widget child;

  /// False = fade saja (untuk elemen kecil agar layout tak bergoyang).
  final bool slide;

  @override
  Widget build(BuildContext context) {
    // Reduced motion: ganti langsung tanpa transisi (DESIGN.md Motion).
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return child;
    }
    return AnimatedSwitcher(
      duration: QuestMotion.medium,
      switchInCurve: QuestMotion.easeOut,
      switchOutCurve: QuestMotion.easeOut,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: slide
            ? SlideTransition(
                position: anim.drive(
                  Tween(begin: const Offset(0, 0.18), end: Offset.zero),
                ),
                child: child,
              )
            : child,
      ),
      child: child,
    );
  }
}

/// Konteks jeda bertingkat dari [QuestEnter] / [QuestTabEnter] agar bar progres
/// dan grafik di dalam kartu baru mulai tumbuh dari 0 tepat saat kartunya
/// tampil di layar, bukan selesai diam-diam ketika kartu masih transparan.
class QuestEnterScope extends InheritedWidget {
  const QuestEnterScope({
    super.key,
    required this.delayMs,
    required super.child,
  });

  final int delayMs;

  static int delayOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<QuestEnterScope>()?.delayMs ?? 0;

  @override
  bool updateShouldNotify(QuestEnterScope oldWidget) =>
      delayMs != oldWidget.delayMs;
}

/// Isi halaman route / sheet yang menetas satu-per-satu secara bertingkat
/// mengikuti urutan [index]: fade + geser naik halus setelah transisi layar
/// mulai mendarat, termasuk untuk komponen yang dimuat lewat StreamBuilder.
class QuestEnter extends StatefulWidget {
  const QuestEnter({
    super.key,
    required this.child,
    this.index = 0,
    this.replayKey,
  });

  final Widget child;
  final int index;
  final Object? replayKey;

  @override
  State<QuestEnter> createState() => _QuestEnterState();
}

class _QuestEnterState extends State<QuestEnter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  int _delayMs = 0;

  void _configureAndRun() {
    _delayMs = 110 + (widget.index.clamp(0, 10) * QuestMotion.staggerStep.inMilliseconds);
    final animMs = QuestMotion.enter.inMilliseconds;
    final totalMs = _delayMs + animMs;
    _controller.duration = Duration(milliseconds: totalMs);
    _opacity = _controller.drive(
      CurveTween(
        curve: Interval(
          (_delayMs / totalMs).clamp(0.0, 0.92),
          1.0,
          curve: QuestMotion.easeOut,
        ),
      ),
    );
    _slide = _opacity.drive(
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero),
    );
    _controller.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    _configureAndRun();
  }

  @override
  void didUpdateWidget(covariant QuestEnter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replayKey != oldWidget.replayKey) {
      _configureAndRun();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return widget.child;
    }
    return QuestEnterScope(
      delayMs: _delayMs,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Bar progres yang TUMBUH mulus dari nol ke state terakhir saat tampil di
/// panggung, terkoordinasi dengan kemunculan kartu induknya ([QuestEnterScope]).
/// Saat nilai berubah karena aksi user, bar meluncur dari posisi terakhirnya;
/// saat pindah tab / periode ([QuestStage] atau [replayKey]), tumbuh ulang dari 0.
class QuestProgressBar extends StatefulWidget {
  const QuestProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.backgroundColor,
    this.minHeight = 8,
    this.replayKey,
  });

  final double value;
  final Color color;
  final Color? backgroundColor;
  final double minHeight;
  final Object? replayKey;

  @override
  State<QuestProgressBar> createState() => _QuestProgressBarState();
}

class _QuestProgressBarState extends State<QuestProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  double _begin = 0.0;
  double _end = 0.0;
  int _leadInMs = 0;
  int _growMs = QuestMotion.grow.inMilliseconds;
  int _seenToken = -1;
  bool _initialized = false;

  double get _currentValue {
    final totalMs = _leadInMs + _growMs;
    if (totalMs <= 0) return _end;
    final raw = ((_controller.value * totalMs - _leadInMs) / _growMs).clamp(
      0.0,
      1.0,
    );
    final eased = QuestMotion.progressCurve.transform(raw);
    return _begin + (_end - _begin) * eased;
  }

  void _startFromZero(int enterDelayMs) {
    _begin = 0.0;
    _end = widget.value.clamp(0.0, 1.0);
    _leadInMs = enterDelayMs > 0 ? enterDelayMs + 110 : 36;
    _growMs = QuestMotion.grow.inMilliseconds;
    _controller.duration = Duration(milliseconds: _leadInMs + _growMs);
    _controller.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stage = QuestStage.ofOrNull(context);
    final enterDelay = QuestEnterScope.delayOf(context);
    if (!_initialized) {
      _initialized = true;
      _seenToken = stage?.token ?? -1;
      _startFromZero(enterDelay);
      return;
    }
    if (stage != null && _seenToken != stage.token) {
      _seenToken = stage.token;
      _startFromZero(enterDelay);
    }
  }

  @override
  void didUpdateWidget(covariant QuestProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTarget = widget.value.clamp(0.0, 1.0);
    if (widget.replayKey != oldWidget.replayKey) {
      _startFromZero(0);
      return;
    }
    if ((newTarget - _end).abs() > 0.0001) {
      if (_begin == 0.0 && _end == 0.0 && _controller.isAnimating) {
        _end = newTarget;
        final elapsedMs = _controller.value * (_leadInMs + _growMs);
        if (elapsedMs > _leadInMs) {
          _startFromZero(0);
        }
      } else {
        _begin = _currentValue;
        _end = newTarget;
        _leadInMs = 0;
        _growMs = QuestMotion.grow.inMilliseconds;
        _controller.duration = Duration(milliseconds: _growMs);
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? context.q.surface2;
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: widget.minHeight,
          color: bg,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: widget.value.clamp(0.0, 1.0),
            child: SizedBox(
              height: widget.minHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final v = _currentValue.clamp(0.0, 1.0);
          return Container(
            height: widget.minHeight,
            color: bg,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v,
              child: AnimatedContainer(
                duration: QuestMotion.fast,
                curve: QuestMotion.easeOut,
                height: widget.minHeight,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Menghitung naik/turun nilai bilangan bulat secara halus dari 0 saat pertama
/// tampil atau saat panggung ([QuestStage]) / [replayKey] berganti, serta
/// Menampilkan angka [value] langsung tanpa animasi count-up dari 0.
class QuestCountUp extends StatelessWidget {
  const QuestCountUp({
    super.key,
    required this.value,
    required this.builder,
    this.replayKey,
    this.duration,
  });

  final int value;
  final Widget Function(BuildContext context, int current) builder;
  final Object? replayKey;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    return builder(context, value);
  }
}

/// Tampilan nominal Rupiah dengan angka tabular langsung tanpa animasi count-up dari 0.
class QuestMoney extends StatelessWidget {
  const QuestMoney({
    super.key,
    required this.amount,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.alignment = Alignment.centerLeft,
    this.replayKey,
    this.duration,
  });

  final int amount;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final AlignmentGeometry alignment;
  final Object? replayKey;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final baseStyle = DefaultTextStyle.of(context).style.merge(style);
    final effectiveStyle = baseStyle.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final finalText = '$prefix${Money.format(amount)}$suffix';

    return Align(
      alignment: alignment,
      widthFactor: 1.0,
      heightFactor: 1.0,
      child: Text(
        finalText,
        maxLines: 1,
        style: effectiveStyle,
      ),
    );
  }
}

/// Pengumuman panggung aktif per-tab / per-filter: [token] naik setiap kali
/// panggung menjadi aktif atau filter periode berubah.
class QuestStage extends InheritedWidget {
  const QuestStage({super.key, required this.token, required super.child});

  final int token;

  /// Null bila di luar shell (route biasa / sheet).
  static QuestStage? ofOrNull(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<QuestStage>();

  @override
  bool updateShouldNotify(QuestStage oldWidget) => token != oldWidget.token;
}

/// Menjalankan ulang animasi 0→1 setiap kali panggung ([QuestStage]) atau
/// [replayKey] berganti TANPA menghancurkan State anak (tanpa remount ValueKey),
/// serta menyelaraskan waktu mulai dengan [QuestEnterScope] induknya.
class QuestReplay extends StatefulWidget {
  const QuestReplay({
    super.key,
    required this.builder,
    this.duration,
    this.curve = QuestMotion.progressCurve,
    this.replayKey,
    this.syncWithEnter = true,
  });

  final Widget Function(BuildContext context, double t) builder;
  final Duration? duration;
  final Curve curve;
  final Object? replayKey;
  final bool syncWithEnter;

  @override
  State<QuestReplay> createState() => _QuestReplayState();
}

class _QuestReplayState extends State<QuestReplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  int _seenToken = -1;
  bool _initialized = false;
  int _leadInMs = 0;
  int _runMs = QuestMotion.grow.inMilliseconds;

  void _restart({required int enterDelayMs}) {
    final baseMs = (widget.duration ?? QuestMotion.grow).inMilliseconds;
    if (baseMs <= 0) {
      _leadInMs = 0;
      _runMs = 0;
      _controller.duration = Duration.zero;
      _controller.value = 1.0;
      return;
    }
    _leadInMs = widget.syncWithEnter && enterDelayMs > 0
        ? enterDelayMs + 110
        : (widget.syncWithEnter ? 36 : 0);
    _runMs = baseMs;
    _controller.duration = Duration(milliseconds: _leadInMs + _runMs);
    _controller.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stage = QuestStage.ofOrNull(context);
    final enterDelay = QuestEnterScope.delayOf(context);
    if (!_initialized) {
      _initialized = true;
      _seenToken = stage?.token ?? -1;
      _restart(enterDelayMs: enterDelay);
      return;
    }
    if (stage != null && _seenToken != stage.token) {
      _seenToken = stage.token;
      _restart(enterDelayMs: enterDelay);
    }
  }

  @override
  void didUpdateWidget(covariant QuestReplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replayKey != oldWidget.replayKey) {
      _restart(enterDelayMs: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final baseDuration = widget.duration ?? QuestMotion.grow;
    if (reduced || baseDuration == Duration.zero) {
      return widget.builder(context, 1.0);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final totalMs = _leadInMs + _runMs;
        if (totalMs <= 0) return widget.builder(context, 1.0);
        final raw = ((_controller.value * totalMs - _leadInMs) / _runMs).clamp(
          0.0,
          1.0,
        );
        final t = widget.curve.transform(raw);
        return widget.builder(context, t);
      },
    );
  }
}

/// Isi tab yang menetas satu-per-satu secara bertingkat ([index]) setiap kali
/// tab menjadi aktif: fade + geser naik halus tanpa me-reset State / Stream
/// komponen di dalamnya, serta meneruskan [QuestEnterScope] ke bar/grafik anak.
class QuestTabEnter extends StatefulWidget {
  const QuestTabEnter({
    super.key,
    required this.child,
    this.index = 0,
    this.replayKey,
  });

  final Widget child;
  final int index;
  final Object? replayKey;

  @override
  State<QuestTabEnter> createState() => _QuestTabEnterState();
}

class _QuestTabEnterState extends State<QuestTabEnter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  int _seenToken = -1;
  bool _initialized = false;
  int _delayMs = 0;
  int _animMs = QuestMotion.enter.inMilliseconds;

  void _restart() {
    _delayMs =
        widget.index.clamp(0, 10) * QuestMotion.staggerStep.inMilliseconds;
    _animMs = QuestMotion.enter.inMilliseconds;
    _controller.duration = Duration(milliseconds: _delayMs + _animMs);
    _controller.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stage = QuestStage.ofOrNull(context);
    if (!_initialized) {
      _initialized = true;
      _seenToken = stage?.token ?? -1;
      _restart();
      return;
    }
    if (stage != null && _seenToken != stage.token) {
      _seenToken = stage.token;
      _restart();
    }
  }

  @override
  void didUpdateWidget(covariant QuestTabEnter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replayKey != oldWidget.replayKey) {
      _restart();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return widget.child;
    }
    return QuestEnterScope(
      delayMs: _delayMs,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final totalMs = _delayMs + _animMs;
          final raw = ((_controller.value * totalMs - _delayMs) / _animMs)
              .clamp(0.0, 1.0);
          final eased = QuestMotion.easeOut.transform(raw);
          return Opacity(
            opacity: eased,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - eased)),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

/// Skema Material yang diturunkan dari palet Quest — dipakai sebagai fondasi
/// agar sisa widget bawaan (menu, picker, dsb.) tetap selaras identitas.
class QuestSchemes {
  QuestSchemes._();

  static ThemeData light() => _base(QuestPalette.light);

  static ThemeData _base(QuestPalette p) {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: p.honey,
      onPrimary: p.honeyInk,
      secondary: p.good,
      onSecondary: p.honeyInk,
      error: p.bad,
      onError: p.honeyInk,
      surface: p.surface,
      onSurface: p.text,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surface2,
      surfaceContainerHighest: p.surface2,
      outline: p.muted,
      outlineVariant: p.muted.withValues(alpha: 0.4),
    );
    return ThemeData(
      fontFamily: 'Nunito',
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      splashFactory: NoSplash.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: QuestPageTransitionsBuilder(),
          TargetPlatform.iOS: QuestPageTransitionsBuilder(),
          TargetPlatform.fuchsia: QuestPageTransitionsBuilder(),
          TargetPlatform.linux: QuestPageTransitionsBuilder(),
          TargetPlatform.macOS: QuestPageTransitionsBuilder(),
          TargetPlatform.windows: QuestPageTransitionsBuilder(),
        },
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: p.text,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: p.text),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: p.text),
        bodyLarge: TextStyle(color: p.text, height: 1.45),
        bodyMedium: TextStyle(color: p.text, height: 1.45),
        bodySmall: TextStyle(color: p.muted),
        labelLarge: TextStyle(fontWeight: FontWeight.w700, color: p.text),
        labelSmall: TextStyle(color: p.muted),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          side: BorderSide(color: p.line, width: 1),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          side: BorderSide(color: p.line, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
          side: BorderSide(color: p.line, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.text,
        contentTextStyle: TextStyle(color: p.bg, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.m,
          vertical: 14,
        ),
        labelStyle: TextStyle(color: p.muted, fontSize: 13),
        hintStyle: TextStyle(color: p.muted.withValues(alpha: 0.7), fontSize: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          borderSide: BorderSide(color: p.line, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          borderSide: BorderSide(color: p.bad, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          borderSide: BorderSide(color: p.bad, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface2,
        selectedColor: p.primaryLight,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: p.text, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: BorderSide(color: p.line, width: 1),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(p.surface),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return p.primary;
          }
          return p.muted.withValues(alpha: 0.4);
        }),
        trackOutlineColor: WidgetStatePropertyAll(p.line),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.surface2,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.zero,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: p.text,
          fontSize: 15,
        ),
        subtitleTextStyle: TextStyle(color: p.muted, fontSize: 12),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          side: BorderSide(color: p.line, width: 2),
        ),
      ),
    );
  }
}
