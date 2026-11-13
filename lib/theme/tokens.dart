import 'package:flutter/material.dart';

/// Token desain — satu sumber kebenaran untuk spacing, radius, dan warna.
///
/// Palet "Petrol Teal CatatIn" (2026-11-13): seluruh warna diturunkan
/// dari logo aplikasi (karung burlap, syal teal, koin emas, aksen koral)
/// di atas latar teal gelap #13454A. Dua tema (light/dark); aksen
/// semantik memakai varian gelap agar lolos WCAG AA di surface & tint-nya.
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

  // ── Netral teal (dari logo) ────────────────────────────────────
  /// Latar app — off-white ber-tint teal.
  static const Color bg = Color(0xFFF3F8F7);

  /// Kartu/sheet — putih murni.
  static const Color surface = Color(0xFFFFFFFF);

  /// Tint lembut: chip, track bar, zona sekunder.
  static const Color surface2 = Color(0xFFE7F0EE);

  /// Garis sekunder & border hairline.
  static const Color line = Color(0xFFE3EDEB);
  static const Color border = Color(0xFFE3EDEB);

  /// Teks utama — petrol ink (teal paling gelap dari logo).
  static const Color ink = Color(0xFF10393D);

  /// Teks body.
  static const Color body = Color(0xFF2C4B4D);

  /// Teks sekunder/muted.
  static const Color muted = Color(0xFF54716E);

  // ── Brand Primary & Aksen ──────────────────────────────────────
  /// Teal syal logo (#499B8F) digelapkan agar lolos AA 4,5:1 di putih.
  static const Color primary = Color(0xFF2A6F66);

  /// Teal lebih dalam — tombol solid/gradien CTA.
  static const Color primaryDeep = Color(0xFF1F5A53);

  /// Tint brand: chip terpilih, track aktif.
  static const Color primaryLight = Color(0xFFDCEEEA);

  /// Aksen kedua — orana strip syal logo (#EA732E), digelapkan
  /// agar tetap terbaca di surface.
  static const Color accent = Color(0xFFC75B1E);


  // ── Emas koin ──────────────────────────────────────────────────
  /// Koin "Rp" logo (#FAC750) — glow/garis badge gamifikasi.
  static const Color honeyBright = Color(0xFFFAC750);

  /// Ikon badge terbuka di atas tint emas (non-teks, ≥3:1).
  static const Color honeyDeep = Color(0xFF8A5F06);

  /// Tint emas: latar badge terbuka.
  static const Color honey100 = Color(0xFFFCF1D8);


  // ── Semantik arah & status ──────────────────────────────────────
  /// Masuk / aman — hijau daun logo (#9FB595) digelapkan; AA on
  /// surface & incomingTint.
  static const Color incoming = Color(0xFF266E48);

  /// Keluar / OVER — koral teks "In" logo (#F77168) digelapkan.
  static const Color outgoing = Color(0xFFB93A31);

  /// Peringatan / mendekati batas (75-99%) — emas koin digelapkan.
  static const Color warn = Color(0xFF8A5F06);
  static const Color warnTint = Color(0xFFFCF1D8);

  /// Tint semantik (chip status).
  static const Color incomingTint = Color(0xFFE8F4EE);
  static const Color outgoingTint = Color(0xFFFDEEEC);


  /// Warna kategori — BAHASA DATA (ADR-010): diindeks via
  /// Categories.colorIndex, tidak berubah, tidak dipakai di luar
  /// konteks kategorinya. Semua hue diambil dari keluarga warna logo.
  static const List<Color> categoryPalette = [
    Color(0xFFE4762F), // Makanan — orana syal
    Color(0xFF2A6F66), // Transportasi — teal brand
    Color(0xFF13454A), // Tagihan — teal latar logo
    Color(0xFF628F63), // Belanja — hijau daun
    Color(0xFFC9971C), // Hiburan — emas koin
    Color(0xFFD9574B), // Kesehatan — koral
    Color(0xFF3E9486), // Gaji — teal syal terang
    Color(0xFF54716E), // Transfer — slate teal
    Color(0xFF8D8D8D), // Lainnya
  ];

  static Color categoryColor(int index) =>
      categoryPalette[index % categoryPalette.length];
}

class DarkColors {
  DarkColors._();

  /// Latar app — teal gelap (sedikit lebih dalam dari latar logo).
  static const Color bg = Color(0xFF0B2E33);

  /// Kartu/sheet — latar teal logo #13454A.
  static const Color surface = Color(0xFF14434A);

  /// Tint latar sekunder / strip.
  static const Color surface2 = Color(0xFF1C5158);

  /// Garis sekunder & border hairline.
  static const Color line = Color(0xFF225B62);
  static const Color border = Color(0xFF225B62);

  /// Teks utama — putih kehijauan dari logo.
  static const Color ink = Color(0xFFEAFBFC);

  /// Teks body — abu teal muda dari logo.
  static const Color body = Color(0xFFCFE3E4);

  /// Teks sekunder/muted.
  static const Color muted = Color(0xFF9CC0BD);

  /// Brand teal syal logo diterangkan — teks/ikon di surface gelap.
  static const Color primary = Color(0xFF62B8AA);
  static const Color primaryDeep = Color(0xFF499B8F);
  static const Color primaryLight = Color(0xFF0F3D40);
  static const Color accent = Color(0xFFF08A47);

  /// Semantik
  static const Color incoming = Color(0xFF63D8A1);
  static const Color incomingTint = Color(0xFF0F3B2C);
  static const Color outgoing = Color(0xFFF98A82); // koral logo
  static const Color outgoingTint = Color(0xFF3F161A);
  static const Color warn = Color(0xFFFAC750); // emas koin logo
  static const Color warnTint = Color(0xFF3D2C07);
}
