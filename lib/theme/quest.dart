import 'package:flutter/material.dart';

import '../core/money.dart';
import 'tokens.dart';

/// Palet "Petrol Teal CatatIn" (2026-11-13) — dua tema, light/dark;
/// pasangan solid/onPrimary lolos WCAG AA. Semua widget custom membaca
/// warna dari sini, bukan default Material, supaya identitas tidak bocor.
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
    required this.primary,
    required this.primaryDeep,
    required this.primaryLight,
    required this.accent,
    required this.hint,
    required this.primarySolid,
    required this.onPrimary,
    required this.primaryText,
    required this.primaryGradientEnd,
    required this.shadow,
    required this.brandShadow,
    this.incomingTint = SeedColors.incomingTint,
    this.outgoingTint = SeedColors.outgoingTint,
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

  final Color primary;
  final Color primaryDeep;
  final Color primaryLight;
  final Color accent;

  /// Teks di atas isian `surface2` (hint/label input, segmen tak aktif) —
  /// teal-slate; `muted` gagal 4,5:1 di surface2.
  final Color hint;

  /// Isian brand yang lolos kontras WCAG AA untuk kontennya (audit
  /// 2026-11-13): light teal deep + putih (7,9:1), dark teal terang +
  /// tinta gelap (6,8:1).
  final Color primarySolid;

  /// Teks/ikon di atas [primarySolid] / gradien brand.
  final Color onPrimary;

  /// Teks berwarna brand (link, label CTA inline) — light teal deep,
  /// dark teal terang; `primary` murni gagal 4,5:1 sebagai teks kecil.
  final Color primaryText;

  /// Ujung kedua gradien CTA — teal lebih gelap (light) / lebih terang (dark).
  final Color primaryGradientEnd;

  final Color shadow;

  /// Bayangan elemen brand (tombol + nav): di light tetap teal pekat agar
  /// tombol terangkat dari latar terang; di dark hitam netral.
  final Color brandShadow;

  /// Elevasi kartu — offset/blur tetap, warna mengikuti [shadow]:
  /// light 3% slate (halus), dark 32% hitam di atas graphite. Menggantikan
  /// AppShadows statis yang tak pernah flip di dark (audit T-01).
  List<BoxShadow> get cardShadow => [
        BoxShadow(offset: const Offset(0, 4), blurRadius: 16, color: shadow),
      ];

  List<BoxShadow> get elevatedShadow => [
        BoxShadow(offset: const Offset(0, 8), blurRadius: 24, color: shadow),
      ];
  final Color incomingTint;
  final Color outgoingTint;

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

    primary: SeedColors.primary,
    primaryDeep: SeedColors.primaryDeep,
    primaryLight: SeedColors.primaryLight,
    accent: SeedColors.accent,
    hint: Color(0xFF3E5D5A),
    primarySolid: SeedColors.primaryDeep,
    onPrimary: Colors.white,
    primaryText: SeedColors.primaryDeep,
    primaryGradientEnd: Color(0xFF164E48),
    shadow: Color(0x0A10393D),
    brandShadow: Color(0x401F5A53),
    incomingTint: SeedColors.incomingTint,
    outgoingTint: SeedColors.outgoingTint,
  );

  static const dark = QuestPalette(
    bg: DarkColors.bg,
    surface: DarkColors.surface,
    surface2: DarkColors.surface2,
    line: DarkColors.line,
    text: DarkColors.ink,
    body: DarkColors.body,
    muted: DarkColors.muted,
    good: DarkColors.incoming,
    warn: DarkColors.warn,
    warnTint: DarkColors.warnTint,
    bad: DarkColors.outgoing,

    primary: DarkColors.primary,
    primaryDeep: DarkColors.primaryDeep,
    primaryLight: DarkColors.primaryLight,
    accent: DarkColors.accent,
    hint: Color(0xFFA9B9B7),
    primarySolid: Color(0xFF4FAA9B),
    onPrimary: DarkColors.bg,
    primaryText: Color(0xFF7FD1C2),
    primaryGradientEnd: Color(0xFF77C9BA),
    shadow: Color(0x52000000),
    brandShadow: Color(0x59000000),
    incomingTint: DarkColors.incomingTint,
    outgoingTint: DarkColors.outgoingTint,
  );


}
/// Akses cepat palet + tipografi khas Quest dari BuildContext.
extension QuestTheme on BuildContext {
  /// Palet dinamis mengikuti tema sistem (light/dark).
  QuestPalette get q => Theme.of(this).brightness == Brightness.dark
      ? QuestPalette.dark
      : QuestPalette.light;

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
    // Reduce Motion (audit M-01): potong instan tanpa slide/parallax —
    // satu-satunya gerak layar-penuh yang belum tergated.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return child;
    }
    final slideIn = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).chain(CurveTween(curve: QuestMotion.easeOut));

    final parallaxOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.25, 0),
    ).chain(CurveTween(curve: QuestMotion.easeOut));

    // Bayangan tepi route: di light nyaris transparan; di dark latar sudah
    // gelap, jadi pakai hitam lebih pekat agar tepi layar tetap terbaca.
    final edgeColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0x66000000)
        : const Color(0x180B2E33);

    final edgeShadow = DecoratedBoxTransition(
      decoration: DecorationTween(
        begin: const BoxDecoration(),
        end: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: edgeColor,
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

/// Perlakuan visual tanda arah (+/−) pada nominal.
///
/// Tanda **minimalis**: bukan lagi sejajar berat dengan angka, melainkan
/// marker subordinat di sampingnya — angka tetap jadi fokus
/// ("Angka adalah Raja", docs/DESIGN.md).
///
/// Angka & bobot diturunkan dari metrik Nunito yang dipakai app:
/// center vertikal digit `0` = +0.3525 em, center `−` U+2212 = +0.2870 em,
/// center `+` = +0.2840 em. Karena `−` duduk sedikit di bawah tengah
/// digit, tanda dinaikkan agar tetap pas di tengah tinggi angka.
class QuestSignStyle {
  const QuestSignStyle._();

  /// Di bawah ukuran ini (em) perlakuan dibuat lebih ringan: bar tanda
  /// akan thinner dari 1px dan hilang kalau diterjemahkan opacity.
  static const double smallThreshold = 16;

  /// Rasio ukuran tanda terhadap ukuran angka, nominal besar.
  static const double largeRatio = 0.62;

  /// Rasio ukuran tanda terhadap ukuran angka, nominal kecil.
  static const double smallRatio = 0.80;

  /// Opasitas tanda terhadap warna angka, nominal besar.
  static const double largeOpacity = 0.55;

  /// Opasitas tanda terhadap warna angka, nominal kecil.
  static const double smallOpacity = 0.65;

  /// Jarak tipis antara tanda dan angka (em).
  static const double gapEm = 0.05;

  /// Center vertikal digit `0` di Nunito (em dari baseline).
  static const double _digitCenterEm = 0.3525;

  /// Center vertikal glyph tanda `−` & `+` di Nunito (em dari baseline).
  static const double _signCenterEm = 0.2855;

  /// Tangga bobot yang benar-benar dibundel (w500 & w900 tidak ada —
  /// ExtraBold terdaftar sebagai w800).
  static const List<FontWeight> _ladder = [
    FontWeight.w400,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
  ];

  /// Rasio ukuran tanda untuk angka seukuran [baseSize].
  static double ratioFor(double baseSize) =>
      baseSize >= smallThreshold ? largeRatio : smallRatio;

  /// Opasitas tanda untuk angka seukuran [baseSize].
  static double opacityFor(double baseSize) =>
      baseSize >= smallThreshold ? largeOpacity : smallOpacity;

  /// Bobot tanda: satu tingkat lebih ringan di tangga bobot bundel.
  ///
  /// w500 & w900 tidak ada di bundel — dinormalkan ke tetangga terdekat
  /// supaya pilihan font-nya deterministik.
  static FontWeight weightFor(FontWeight? weight) {
    final normalized = switch (weight ?? FontWeight.w400) {
      FontWeight.w900 => FontWeight.w800,
      FontWeight.w500 => FontWeight.w400,
      final w => w,
    };
    final i = _ladder.indexOf(normalized);
    if (i <= 0) return FontWeight.w400;
    return _ladder[i - 1];
  }

  /// Kompensasi optik (em) agar center tanda = center digit.
  static double riseEmFor(double ratio) =>
      _digitCenterEm - _signCenterEm * ratio;

  /// Gaya tanda untuk nominal berukuran [base] seukuran [baseSize].
  static TextStyle styleFor(TextStyle base, double baseSize) {
    final ratio = ratioFor(baseSize);
    final color = base.color;
    final sign = base.copyWith(
      fontSize: baseSize * ratio,
      fontWeight: weightFor(base.fontWeight),
      letterSpacing: 0,
    );
    if (color == null) return sign;
    return sign.copyWith(
      color: color.withValues(alpha: color.a * opacityFor(baseSize)),
    );
  }
}

/// Tampilan nominal Rupiah dengan angka tabular langsung tanpa animasi
/// count-up dari 0.
///
/// Tanda arah digambar terpisah dari angka sebagai marker subordinat
/// (lihat [QuestSignStyle]): `−`/`+` kecil, lebih tipis, dan transparan.
class QuestMoney extends StatelessWidget {
  const QuestMoney({
    super.key,
    required this.amount,
    this.style,
    this.tone,
    this.prefix = '',
    this.suffix = '',
    this.alignment = Alignment.centerLeft,
    this.replayKey,
    this.duration,
  });

  final int amount;
  final TextStyle? style;

  /// Arah tampilan nominal. Null → tanda mengikuti tanda nilai [amount]
  /// (negatif = `−`, selain itu tanpa tanda).
  final MoneyTone? tone;

  /// Teks biasa sebelum nominal — bukan tanda arah.
  final String prefix;

  /// Teks biasa setelah nominal — bukan tanda arah.
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
    final sign = Money.signOf(amount, tone);
    final baseSize = effectiveStyle.fontSize ?? 16;

    return Align(
      alignment: alignment,
      widthFactor: 1.0,
      heightFactor: 1.0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (prefix.isNotEmpty)
            Text(prefix, maxLines: 1, style: effectiveStyle),
          if (sign != null) ...[
            Transform.translate(
              offset: Offset(
                0,
                -baseSize * QuestSignStyle.riseEmFor(
                  QuestSignStyle.ratioFor(baseSize),
                ),
              ),
              child: Text(
                sign,
                maxLines: 1,
                style: QuestSignStyle.styleFor(effectiveStyle, baseSize),
              ),
            ),
            SizedBox(width: baseSize * QuestSignStyle.gapEm),
          ],
          Text(
            '${Money.formatAbs(amount)}$suffix',
            maxLines: 1,
            style: effectiveStyle,
          ),
        ],
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
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  int _seenToken = -1;
  bool _initialized = false;
  int _delayMs = 0;
  int _animMs = QuestMotion.enter.inMilliseconds;

  void _restart({bool animate = true}) {
    if (!animate) {
      _controller.value = 1.0;
      _opacity = const AlwaysStoppedAnimation<double>(1.0);
      _slide = const AlwaysStoppedAnimation<Offset>(Offset.zero);
      return;
    }
    _delayMs =
        widget.index.clamp(0, 20) * QuestMotion.staggerStep.inMilliseconds;
    _animMs = QuestMotion.enter.inMilliseconds;
    _controller.duration = Duration(milliseconds: _delayMs + _animMs);
    final totalMs = _delayMs + _animMs;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stage = QuestStage.ofOrNull(context);
    final position = Scrollable.maybeOf(context)?.position;
    final isScrolled =
        position != null && position.hasPixels && position.pixels > 0.0;

    if (!_initialized) {
      _initialized = true;
      _seenToken = stage?.token ?? -1;
      _restart(animate: !isScrolled);
      return;
    }
    if (stage != null && _seenToken != stage.token) {
      _seenToken = stage.token;
      _restart(animate: !isScrolled);
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

/// Skema Material yang diturunkan dari palet Quest — dipakai sebagai fondasi
/// agar sisa widget bawaan (menu, picker, dsb.) tetap selaras identitas.
class QuestSchemes {
  QuestSchemes._();

  static ThemeData light() => _base(QuestPalette.light, Brightness.light);
  static ThemeData dark() => _base(QuestPalette.dark, Brightness.dark);

  static ThemeData _base(QuestPalette p, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.good,
      onSecondary: p.onPrimary,
      error: p.bad,
      onError: p.onPrimary,
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
        labelStyle: TextStyle(color: p.hint, fontSize: 13),
        hintStyle: TextStyle(color: p.hint, fontSize: 13),
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
      // switchTheme dihapus (audit T-03): app memakai QuestSwitch custom
      // di seluruh layar; Material Switch tak pernah dirender.
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
