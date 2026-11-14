import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:catatim/game/mascot.dart';
import 'package:catatim/theme/quest.dart';

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
}
