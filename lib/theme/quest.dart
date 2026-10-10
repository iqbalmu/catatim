import 'package:flutter/material.dart';

import 'tokens.dart';

/// Palet identitas "Bukuduit Quest": kertas hangat di light, malam cozy di
/// dark. Semua widget custom membaca warna dari sini, bukan dari default
/// Material, supaya identitas tidak bocor ke mana-mana.
class QuestPalette {
  const QuestPalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.muted,
    required this.good,
    required this.bad,
    required this.honey,
    required this.honeyInk,
    required this.shadow,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color text;
  final Color muted;
  final Color good;
  final Color bad;
  final Color honey;
  final Color honeyInk;
  final Color shadow;

  static const light = QuestPalette(
    bg: Color(0xFFFDF6E9),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF7EEDC),
    line: SeedColors.ink,
    text: SeedColors.ink,
    muted: Color(0xFF6E6656),
    good: SeedColors.incoming,
    bad: SeedColors.outgoing,
    honey: SeedColors.honey,
    honeyInk: SeedColors.ink,
    shadow: Color(0x333B3630),
  );

  static const dark = QuestPalette(
    bg: Color(0xFF241F1C),
    surface: Color(0xFF2E2823),
    surface2: Color(0xFF3A322B),
    line: Color(0xFFF1E7D3),
    text: Color(0xFFF7EFE2),
    muted: Color(0xFFB9A98F),
    good: Color(0xFF3FD68F),
    bad: Color(0xFFFF7A7A),
    honey: SeedColors.honey,
    honeyInk: SeedColors.ink,
    shadow: Color(0x66000000),
  );
}

/// Akses cepat palet + tipografi khas Quest dari BuildContext.
extension QuestTheme on BuildContext {
  QuestPalette get q {
    return Theme.of(this).brightness == Brightness.dark
        ? QuestPalette.dark
        : QuestPalette.light;
  }

  /// Angka display besar, tabular agar digit sejajar.
  TextStyle qDisplay([double size = 40]) {
    return TextStyle(
      fontSize: size,
      height: 1.05,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: q.text,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  TextStyle qTitle([double size = 17]) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: q.text,
    );
  }

  TextStyle qBody([double size = 14]) {
    return TextStyle(fontSize: size, color: q.text, height: 1.45);
  }

  TextStyle qSmall([double size = 12]) {
    return TextStyle(fontSize: size, color: q.muted, height: 1.4);
  }

  /// Label kecil caps dengan spasi lebar, untuk eyebrow/section.
  TextStyle qEyebrow([double size = 11]) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
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

/// Durasi + kurva baku. Interaksi sering (< tens/day) tanpa animasi;
/// sisanya < 300ms, keluar selalu ease-out.
class QuestMotion {
  QuestMotion._();

  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 220);
  static const sheet = Duration(milliseconds: 320);

  static const easeOut = Cubic(0.23, 1, 0.32, 1);
  static const drawer = Cubic(0.32, 0.72, 0, 1);

  /// Skala umpan-balik tekan, khas tombol game.
  static const double pressScale = 0.96;
}

/// Transisi pindah screen khas Quest: geser tipis + fade, cepat di awal.
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
    final curved = CurvedAnimation(
      parent: animation,
      curve: QuestMotion.easeOut,
      reverseCurve: QuestMotion.easeOut,
    );
    return SlideTransition(
      position: Tween(
        begin: const Offset(0.08, 0.03),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(
        opacity: Tween(begin: 0.0, end: 1.0).animate(curved),
        child: child,
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
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      splashFactory: NoSplash.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: QuestPageTransitionsBuilder(),
          TargetPlatform.iOS: QuestPageTransitionsBuilder(),
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
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: p.line, width: 2),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: p.line, width: 2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: p.line, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.text,
        contentTextStyle: TextStyle(color: p.bg, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: TextStyle(color: p.muted),
        hintStyle: TextStyle(color: p.muted.withValues(alpha: 0.8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.line, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.honey, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.bad, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.bad, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface2,
        selectedColor: p.honey,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: p.text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: p.line, width: 2),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(p.surface),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.honey;
          return p.muted.withValues(alpha: 0.5);
        }),
        trackOutlineColor: WidgetStatePropertyAll(p.line),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.honey,
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
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: p.line, width: 2),
        ),
      ),
    );
  }
}
