import 'package:flutter/material.dart';

/// Token desain — satu sumber kebenaran untuk spacing, radius, dan warna.
class Spacing {
  Spacing._();

  /// Micro-gap pasangan teks rapat (judul → subjudul, ikon → label nav).
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
}

/// Inset berulang berbasis peran. Pakai ini, jangan nilai hardcoded.
class Insets {
  Insets._();

  /// Baris kartu kecil: item bon, log capture, tile transaksi, input.
  static const EdgeInsets tile =
      EdgeInsets.symmetric(horizontal: 14, vertical: 12);

  /// Pil/badge mini: chip delta, badge status, pil tanggal.
  static const EdgeInsets chip =
      EdgeInsets.symmetric(horizontal: 10, vertical: 5);
}

class AppRadius {
  AppRadius._();

  /// Kartu standar — QuestCard & Container kartu permukaan.
  static const double card = 20;

  /// Tile/baris di dalam halaman atau kartu, sel kontrol dalam bingkai.
  static const double tile = 18;

  /// Bingkai kontrol: segmented, bottom nav.
  static const double frame = 22;

  /// Sel kecil padat: picker bulan, legenda donat, sel kalender.
  static const double cell = 12;

  /// Permukaan hero: kartu utama home, dialog, sheet.
  static const double sheet = 24;

  /// Bentuk pil: chip, tombol, bar progres, switch.
  static const double pill = 999;
}

class SeedColors {
  SeedColors._();

  /// Teal gelap — netral finansial, kontras baik di light & dark.
  static const Color seed = Color(0xFF006A60);

  static const Color incoming = Color(0xFF1B873B);
  static const Color outgoing = Color(0xFFB3392E);

  /// Warna Bukuduit Quest.
  static const Color honey = Color(0xFFFFB33E);
  static const Color honey50 = Color(0xFFFFF3DC);
  static const Color honey100 = Color(0xFFFFE7B8);
  static const Color honeyBright = Color(0xFFFFD97A);
  static const Color honeyDeep = Color(0xFFFFA726);
  static const Color honeyInk = Color(0xFF8A6420);
  static const Color ink = Color(0xFF3B3630);

  /// Garis sekunder halus — bukan border kartu.
  static const Color line = Color(0xFFEFE6D4);

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
