import 'package:flutter/material.dart';

/// Token desain — satu sumber kebenaran untuk spacing, radius, dan warna.
///
/// Palet v3.0 "Slate-Indigo Clean": bersih, tenang, berbobot finansial —
/// lihat docs/DESIGN.md. Dua tema (light/dark); aksen semantik light
/// memakai varian 700 agar lolos WCAG AA (audit 2026-11-11).
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

/// Elevasi kini hidup di QuestPalette (`cardShadow`/`elevatedShadow`) —
/// warna shadow ikut tema (light 3% slate / dark 48% hitam), menggantikan
/// AppShadows statis yang tak pernah flip di dark (audit T-01).

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


  // ── Emas & Amber ───────────────────────────────────────────────
  static const Color honeyBright = Color(0xFFFDE68A);

  static const Color honeyDeep = Color(0xFFD97706);

  static const Color honey100 = Color(0xFFFEF3C7);


  // ── Semantik arah & status ──────────────────────────────────────
  /// Masuk / aman — Emerald 700 (WCAG AA on surface & tint, audit
  /// 2026-11-11: Emerald 500 hanya 2,54:1 di putih).
  static const Color incoming = Color(0xFF047857);

  /// Keluar / OVER — Rose 700 (Rose 500 hanya 3,76:1, Rose 600 4,41 di tint).
  static const Color outgoing = Color(0xFFB91C1C);

  /// Peringatan / mendekati batas (75-99%) — Amber 700 (Amber 500
  /// hanya 1,93:1 di warnTint).
  static const Color warn = Color(0xFFB45309);
  static const Color warnTint = Color(0xFFFEF3C7);

  /// Tint semantik (chip status).
  static const Color incomingTint = Color(0xFFECFDF5);
  static const Color outgoingTint = Color(0xFFFEF2F2);


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

class DarkColors {
  DarkColors._();

  /// Latar app — Slate 900.
  static const Color bg = Color(0xFF0F172A);

  /// Kartu/sheet — Slate 800.
  static const Color surface = Color(0xFF1E293B);

  /// Tint latar sekunder / strip — Slate 700.
  static const Color surface2 = Color(0xFF334155);

  /// Garis sekunder & border hairline — Slate 700.
  static const Color line = Color(0xFF334155);
  static const Color border = Color(0xFF334155);

  /// Teks utama — Slate 50.
  static const Color ink = Color(0xFFF8FAFC);

  /// Teks body — Slate 200.
  static const Color body = Color(0xFFE2E8F0);

  /// Teks sekunder/muted — Slate 400.
  static const Color muted = Color(0xFF94A3B8);

  /// Brand Primary Indigo 400.
  static const Color primary = Color(0xFF818CF8);
  static const Color primaryDeep = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF312E81);
  static const Color violet = Color(0xFFA78BFA);

  /// Semantik
  static const Color incoming = Color(0xFF34D399); // Emerald 400
  static const Color incomingTint = Color(0xFF064E3B);
  static const Color outgoing = Color(0xFFF87171); // Rose 400
  static const Color outgoingTint = Color(0xFF450A0A);
  static const Color warn = Color(0xFFFBBF24); // Amber 400
  static const Color warnTint = Color(0xFF451A03);
}
