import 'package:flutter/material.dart';

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
    bad: SeedColors.outgoing,
    honey: SeedColors.primary,
    honeyInk: SeedColors.primaryDeep,
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

  /// Curve spring untuk press/FAB — kenyal, konsisten bob maskot
  /// (bounce ~6%; ADR-010, DESIGN.md v2.1).
  static const Cubic spring = Cubic(0.34, 1.56, 0.64, 1);
}

/// Transisi pindah screen khas Quest: slide penuh dari kanan — feel
/// navigasi maju; saat pop kembali ke kanan.
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
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(curved),
      child: child,
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
