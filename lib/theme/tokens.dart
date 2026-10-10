import 'package:flutter/material.dart';

/// Token desain — satu sumber kebenaran untuk spacing, radius, dan warna.
class Spacing {
  Spacing._();

  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
}

class AppRadius {
  AppRadius._();

  static const double card = 16;
  static const double sheet = 24;
}

class SeedColors {
  SeedColors._();

  /// Teal gelap — netral finansial, kontras baik di light & dark.
  static const Color seed = Color(0xFF006A60);

  static const Color incoming = Color(0xFF1B873B);
  static const Color outgoing = Color(0xFFB3392E);
}
