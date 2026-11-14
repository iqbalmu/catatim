import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:catatim/game/mascot.dart';
import 'package:catatim/theme/quest.dart';
import 'package:catatim/theme/tokens.dart';

void main() {
  for (final mood in MascotMood.values) {
    testWidgets('Mascot mood ${mood.name} memuat asetnya tanpa error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          home: Scaffold(body: Center(child: Mascot(mood: mood))),
        ),
      );
      // AnimationController maskot repeat() tanpa henti — pumpAndSettle
      // mustahil settle. Pump secukupnya sampai decode aset selesai;
      // path salah akan muncul sebagai exception "Unable to load asset".
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Latar MascotStage mengikuti ekspresi', (tester) async {
    // Container latar punya gradient dengan stops; bayangan tanah tidak.
    Color? warnaLatar(WidgetTester tester) {
      final containers = tester.widgetList<Container>(
        find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration,
        ),
      );
      for (final c in containers) {
        final decoration = c.decoration! as BoxDecoration;
        final gradient = decoration.gradient as RadialGradient?;
        if (gradient?.stops != null) return gradient!.colors.first;
      }
      return null;
    }

    Widget stage(MascotMood mood) => MaterialApp(
          theme: QuestSchemes.light(),
          home: Scaffold(
            body: Center(child: MascotStage(mood: mood)),
          ),
        );

    final expected = {
      MascotMood.celebrate: SeedColors.honeyBright.withValues(alpha: 0.30),
      MascotMood.happy: SeedColors.incoming.withValues(alpha: 0.22),
      MascotMood.worried: SeedColors.warn.withValues(alpha: 0.22),
      MascotMood.broke: SeedColors.outgoing.withValues(alpha: 0.22),
      MascotMood.idle: SeedColors.surface.withValues(alpha: 0.40),
      MascotMood.sleepy: SeedColors.surface.withValues(alpha: 0.25),
    };

    for (final entry in expected.entries) {
      await tester.pumpWidget(stage(entry.key));
      await tester.pump();
      expect(
        warnaLatar(tester),
        entry.value,
        reason: 'latar mood ${entry.key.name} harus sesuai ekspresi',
      );
    }
  });
}
