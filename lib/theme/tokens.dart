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

  /// Warna kategori — diindeks via Categories.colorIndex.
  static const List<Color> categoryPalette = [
    Color(0xFFE07A5F), // Makanan
    Color(0xFF3D8AA8), // Transportasi
    Color(0xFF8A6FBF), // Tagihan
    Color(0xFF4E9A6F), // Belanja
    Color(0xFFD4A017), // Hiburan
    Color(0xFFC75B6E), // Kesehatan
    Color(0xFF2E8B74), // Gaji
    Color(0xFF6B7FA3), // Transfer
    Color(0xFF8D8D8D), // Lainnya
  ];

  static Color categoryColor(int index) =>
      categoryPalette[index % categoryPalette.length];
}
