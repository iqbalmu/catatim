import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catatim/theme/quest.dart';
import 'package:catatim/theme/tokens.dart';

/// Regresi kontras WCAG untuk token semantik & brand (audit 2026-11-11).
///
/// P1 saat itu: Emerald/Rose/Amber 500 sebagai teks hanya 1,93–3,76:1 di
/// light mode; putih di atas Indigo 400 (CTA dark) 2,98:1. Token kini memakai
/// varian 700 (light) / pasangan onPrimary yang lolos AA. Test ini gagal
/// jika ada token yang digeser kembali ke nilai yang gagal kontras.
int _channel8(Color c, double channel) =>
    (channel * 255.0).round().clamp(0, 255);

double _lin(int v) {
  final s = v / 255;
  return s <= 0.04045
      ? s / 12.92
      : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

double _lum(Color c) {
  return 0.2126 * _lin(_channel8(c, c.r)) +
      0.7152 * _lin(_channel8(c, c.g)) +
      0.0722 * _lin(_channel8(c, c.b));
}

double contrast(Color a, Color b) {
  final la = _lum(a);
  final lb = _lum(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void expectText(String name, Color fg, Color bg) {
  final ratio = contrast(fg, bg);
  expect(
    ratio,
    greaterThanOrEqualTo(4.5),
    reason: '$name: $ratio < 4.5:1 (teks normal, WCAG SC 1.4.3)',
  );
}

void expectGraphic(String name, Color fg, Color bg) {
  final ratio = contrast(fg, bg);
  expect(
    ratio,
    greaterThanOrEqualTo(3.0),
    reason: '$name: $ratio < 3:1 (non-teks, WCAG SC 1.4.11)',
  );
}

typedef Pair = (String, Color, Color);

void checkAll(String group, List<Pair> pairs, void Function(String, Color, Color) check) {
  for (final (surface, fg, bg) in pairs) {
    test('$group @ $surface', () => check('$group @ $surface', fg, bg));
  }
}

void main() {
  group('light — semantik arah & status', () {
    final p = QuestPalette.light;

    checkAll('incoming', [
      ('white', p.good, Colors.white),
      ('bg', p.good, SeedColors.bg),
      ('surface2', p.good, SeedColors.surface2),
      ('incomingTint', p.good, SeedColors.incomingTint),
    ], expectText);

    checkAll('outgoing', [
      ('white', p.bad, Colors.white),
      ('bg', p.bad, SeedColors.bg),
      ('surface2', p.bad, SeedColors.surface2),
      ('outgoingTint', p.bad, SeedColors.outgoingTint),
    ], expectText);

    checkAll('warn', [
      ('white', p.warn, Colors.white),
      ('bg', p.warn, SeedColors.bg),
      ('surface2', p.warn, SeedColors.surface2),
      ('warnTint', p.warn, SeedColors.warnTint),
    ], expectText);

    // P2 re-audit: muted gagal 4,5:1 di surface2 (4,34) — hint menggantikan
    // untuk teks di atas isian surface2 (input & segmen tak aktif).
    checkAll('hint', [
      ('surface2', p.hint, SeedColors.surface2),
      ('white', p.hint, Colors.white),
    ], expectText);
  });

  group('brand — pasangan solid/onPrimary/primaryText', () {
    for (final (name, p) in [
      ('light', QuestPalette.light),
      ('dark', QuestPalette.dark),
    ]) {
      test('$name: onPrimary di atas primarySolid', () {
        expectText('$name onPrimary/primarySolid', p.onPrimary, p.primarySolid);
      });
      test('$name: onPrimary di atas ujung gradien', () {
        expectText(
          '$name onPrimary/primaryGradientEnd',
          p.onPrimary,
          p.primaryGradientEnd,
        );
      });
      test('$name: primaryText pada permukaan', () {
        expectText('$name primaryText/surface', p.primaryText, p.surface);
        expectText('$name primaryText/bg', p.primaryText, p.bg);
        expectText(
          '$name primaryText/primaryLight',
          p.primaryText,
          p.primaryLight,
        );
      });
    }
  });

  group('dark — semantik tidak berubah tetap lolos', () {
    final p = QuestPalette.dark;

    checkAll('incoming dark', [
      ('bg', p.good, DarkColors.bg),
      ('surface', p.good, DarkColors.surface),
      ('incomingTint', p.good, DarkColors.incomingTint),
    ], expectText);

    checkAll('outgoing dark', [
      ('bg', p.bad, DarkColors.bg),
      ('surface', p.bad, DarkColors.surface),
      ('outgoingTint', p.bad, DarkColors.outgoingTint),
    ], expectText);

    checkAll('warn dark', [
      ('bg', p.warn, DarkColors.bg),
      ('surface', p.warn, DarkColors.surface),
      ('warnTint', p.warn, DarkColors.warnTint),
    ], expectText);

    checkAll('hint dark', [
      ('surface2', p.hint, DarkColors.surface2),
      ('surface', p.hint, DarkColors.surface),
    ], expectText);
   });

  test('grafik: warna batang vs permukaan kartu (non-teks)', () {
    for (final (name, p) in [
      ('light', QuestPalette.light),
      ('dark', QuestPalette.dark),
    ]) {
      expectGraphic('$name good/surface', p.good, p.surface);
      expectGraphic('$name bad/surface', p.bad, p.surface);
    }
  });
}
