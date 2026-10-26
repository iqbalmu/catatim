import 'package:flutter/material.dart';

/// Token desain — satu sumber kebenaran untuk spacing, radius, dan warna.
///
/// Nilai warna = palet v2.1 "Pastel Pochy", 100% diturunkan dari piksel
/// maskot (tubuh burlap, koin, syal teal, mulut, bintang pastel) —
/// lihat docs/DESIGN.md + ADR-010. Satu tema; tanpa dark mode.
class Spacing {
  Spacing._();

  /// Micro-gap pasangan teks rapat (judul → subjudul, ikon → label nav).
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double sm = 12;
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
  static const double tile = 14;

  /// Bingkai kontrol: segmented, bottom nav.
  static const double frame = 18;

  /// Sel kecil padat: picker bulan, legenda donat, sel kalender.
  static const double cell = 12;

  /// Permukaan hero: kartu utama home, dialog, sheet.
  static const double sheet = 24;

  /// Frame navigasi bawah.
  static const double nav = 28;

  /// Bentuk pil: chip, tombol, bar progres, switch.
  static const double pill = 999;
}

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      offset: Offset(0, 4),
      blurRadius: 16,
      color: Color(0x080F172A),
    ),
  ];
  static const List<BoxShadow> raised = [
    BoxShadow(
      offset: Offset(0, 6),
      blurRadius: 18,
      color: Color(0x0C0F172A),
    ),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(
      offset: Offset(0, 8),
      blurRadius: 24,
      color: Color(0x0D0F172A),
    ),
  ];
}

class SeedColors {

  // ── Netral Slate ───────────────────────────────────────────────
  /// Latar app — Slate 50 ultra-clean.
  static const Color bg = Color(0xFFF8FAFC);

  /// Kartu/sheet — putih murni.
  static const Color surface = Color(0xFFFFFFFF);

  /// Tint lembut: chip, track bar, zona sekunder — Slate 100.
  static const Color surface2 = Color(0xFFF1F5F9);

  /// Garis sekunder & border hairline — Slate 100.
  static const Color line = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFF1F5F9);

  /// Teks utama — Obsidian Slate 900.
  static const Color ink = Color(0xFF0F172A);

  /// Teks body — Slate 700.
  static const Color body = Color(0xFF334155);

  /// Teks sekunder/muted — Slate 500.
  static const Color muted = Color(0xFF64748B);

  // ── Brand Primary & Aksen ──────────────────────────────────────
  static const Color primary = Color(0xFF6366F1); // Indigo 500
  static const Color primaryDeep = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryLight = Color(0xFFEEF2FF); // Indigo 50
  static const Color violet = Color(0xFF8B5CF6); // Violet 500
  static const Color lilacBg = Color(0xFFF3E8FF);
  static const Color lilacText = Color(0xFF7E22CE);

  // ── Emas & Amber ───────────────────────────────────────────────
  static const Color honeyBright = Color(0xFFFDE68A);
  static const Color honey = Color(0xFFF59E0B);
  static const Color honeyDeep = Color(0xFFD97706);
  static const Color honeyInk = Color(0xFFB45309);
  static const Color honeyText = Color(0xFF78350F);
  static const Color honey50 = Color(0xFFFFFBEB);
  static const Color honey100 = Color(0xFFFEF3C7);

  // ── Mint / Cyan ────────────────────────────────────────────────
  static const Color mint = Color(0xFF06B6D4);
  static const Color mintDeep = Color(0xFF0891B2);
  static const Color mintInk = Color(0xFF0E7490);
  static const Color mintTint = Color(0xFFECFEFF);

  // ── Semantik arah & status ──────────────────────────────────────
  /// Masuk / aman — Emerald 500.
  static const Color incoming = Color(0xFF10B981);

  /// Keluar / OVER — Rose/Red 500.
  static const Color outgoing = Color(0xFFEF4444);

  /// Peringatan / mendekati batas (75-99%) — Amber 500.
  static const Color warn = Color(0xFFF59E0B);
  static const Color warnTint = Color(0xFFFEF3C7);

  /// Tint semantik (chip status).
  static const Color incomingTint = Color(0xFFECFDF5);
  static const Color outgoingTint = Color(0xFFFEF2F2);
  /// Netral finansial lama.
  static const Color seed = primary;

  /// Warna kategori — BAHASA DATA (ADR-010): diindeks via
  /// Categories.colorIndex, tidak berubah, tidak dipakai di luar
  /// konteks kategorinya.
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
