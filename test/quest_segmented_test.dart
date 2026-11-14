import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catatim/theme/quest.dart';
import 'package:catatim/ui/quest.dart';

void main() {
  testWidgets('QuestSegmented slides indicator smoothly between options', (
    tester,
  ) async {
    bool selected = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: QuestSchemes.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Center(
                child: SizedBox(
                  width: 300,
                  child: QuestSegmented<bool>(
                    selected: selected,
                    onChanged: (val) => setState(() => selected = val),
                    options: const [
                      (value: false, label: 'Pengeluaran (8)', icon: null),
                      (value: true, label: 'Pemasukan (3)', icon: null),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    // Initial state: first option is selected
    expect(find.text('Pengeluaran (8)'), findsOneWidget);
    expect(find.text('Pemasukan (3)'), findsOneWidget);

    // Tap second option
    await tester.tap(find.text('Pemasukan (3)'));
    await tester.pump(); // Start animation
    await tester.pump(
      const Duration(milliseconds: 100),
    ); // Halfway through slide

    // Check AnimatedAlign is animating
    await tester.pumpAndSettle(); // Complete slide
    expect(selected, isTrue);

    // Tap first option again
    await tester.tap(find.text('Pengeluaran (8)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(selected, isFalse);
  });
}
