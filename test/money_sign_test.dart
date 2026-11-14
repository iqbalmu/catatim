import 'package:catatim/core/money.dart';
import 'package:catatim/theme/quest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tanda arah (+/−) digambar sebagai marker subordinat: kecil, lebih
/// tipis, transparan, dan duduk di tengah tinggi digit.
void main() {
  Widget host(Widget child) {
    return MaterialApp(
      theme: QuestSchemes.light(),
      home: Scaffold(body: Center(child: child)),
    );
  }

  const heroStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: Color(0xFFB91C1C),
  );

  testWidgets('QuestMoney: tanda outgoing digambar terpisah dari nominal', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const QuestMoney(
          amount: 840000,
          tone: MoneyTone.outgoing,
          style: heroStyle,
        ),
      ),
    );
    await tester.pump();

    // Nominal tampil absolut (tanpa tanda di dalam string).
    expect(find.text('Rp840.000'), findsOneWidget);

    // Tanda `−` (U+2212) berdiri sendiri sebagai marker.
    final sign = tester.widget<Text>(find.text('−'));
    expect(sign.style?.fontSize, closeTo(28 * QuestSignStyle.largeRatio, 0.01));
    expect(sign.style?.fontWeight, FontWeight.w700);
    final color = sign.style?.color;
    expect(color, isNotNull);
    expect(color!.a, closeTo(QuestSignStyle.largeOpacity, 0.01));
  });

  testWidgets('QuestMoney: nominal negatif tanpa tone tetap memakai tanda', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const QuestMoney(amount: -840000, style: heroStyle)),
    );
    await tester.pump();

    expect(find.text('−'), findsOneWidget);
    expect(find.text('Rp840.000'), findsOneWidget);
  });

  testWidgets('QuestMoney: tone incoming memakai tanda plus', (tester) async {
    await tester.pumpWidget(
      host(
        const QuestMoney(
          amount: 840000,
          tone: MoneyTone.incoming,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF047857),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('+'), findsOneWidget);
    expect(find.text('Rp840.000'), findsOneWidget);
  });

  testWidgets('QuestMoney: nominal kecil dapat perlakuan lebih ringan', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const QuestMoney(
          amount: 840000,
          tone: MoneyTone.outgoing,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFFB91C1C),
          ),
        ),
      ),
    );
    await tester.pump();

    final sign = tester.widget<Text>(find.text('−'));
    expect(sign.style?.fontSize, closeTo(12 * QuestSignStyle.smallRatio, 0.01));
    expect(sign.style?.color!.a, closeTo(QuestSignStyle.smallOpacity, 0.01));
  });
}
