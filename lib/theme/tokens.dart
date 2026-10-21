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
  static const double card = 22;

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

  // ── Netral (dari burlap & tali Pochy) ──────────────────────────
  /// Latar app — burlap terang dicerahkan.
  static const Color bg = Color(0xFFFBF5EC);

  /// Kartu/sheet — putih hangat hue burlap.
  static const Color surface = Color(0xFFFFFDF9);

  /// Tint lembut: chip, track bar, zona sekunder.
  static const Color surface2 = Color(0xFFF6E9DA);

  /// Garis sekunder halus — bukan border kartu.
  static const Color line = Color(0xFFEDE0CE);

  /// Teks utama — tali/mata #3E2214 dicerahkan.
  static const Color ink = Color(0xFF5B4433);

  /// Teks sekunder — lipatan bayang karung.
  static const Color muted = Color(0xFFAD9680);

  // ── Emas (dari koin #F1A23A + bintang kuning #FDF6BF) ──────────
  /// Gradien koin: terang.
  static const Color honeyBright = Color(0xFFF9DCA8);

  /// Gradien koin: ujung gelap; aksen brand/CTA utama.
  static const Color honey = Color(0xFFE8B36B);

  /// Ujung lebih pekat untuk gradien & aksen tegas.
  static const Color honeyDeep = Color(0xFFDE9F55);

  /// Emas diperdalam — teks tautan/emphasize di area netral.
  static const Color honeyInk = Color(0xFFC08A3D);

  /// Tinta teks tombol utama di atas gradien emas.
  static const Color honeyText = Color(0xFF6B4A1E);

  /// Tint emas paling terang — hero gradien awal, zona lembut.
  static const Color honey50 = Color(0xFFFBE7BE);

  /// Emas sedang — hero gradien tengah.
  static const Color honey100 = Color(0xFFF3CD8F);

  // ── Mint aksen (dari syal teal + bintang mint) ─────────────────
  /// Aksen netral-aktif: status tenang, piutang, tint segmen.
  static const Color mint = Color(0xFFA4D1C9);

  /// Mint diperdalam — sel segmented aktif, aksen berisi.
  static const Color mintDeep = Color(0xFF7FBDB1);

  /// Mint untuk teks di atas tint terang.
  static const Color mintInk = Color(0xFF3E7A6D);

  /// Tint mint: chip streak, status baik.
  static const Color mintTint = Color(0xFFE6F2EF);

  // ── Semantik arah ──────────────────────────────────────────────
  /// Masuk / aman — mint diperdalam (menggantikan hijau lama; ADR-010).
  static const Color incoming = Color(0xFF4A8C7E);

  /// Keluar / OVER — merah mulut menangis disiram.
  static const Color outgoing = Color(0xFFB05530);

  /// Tint semantik (chip status).
  static const Color incomingTint = Color(0xFFE3F0EC);
  static const Color outgoingTint = Color(0xFFF7E4DA);

  /// Netral finansial lama — kini merujuk mint (aksen tenang).
  static const Color seed = mintDeep;

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
