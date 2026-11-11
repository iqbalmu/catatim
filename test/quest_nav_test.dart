import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bukuduit/theme/quest.dart';
import 'package:bukuduit/ui/quest.dart';

void main() {
  testWidgets('QuestBottomNav switches active tabs across center button gap', (tester) async {
    int currentTab = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: QuestSchemes.light(),
        home: Scaffold(
          bottomNavigationBar: StatefulBuilder(
            builder: (context, setState) {
              return QuestBottomNav(
                index: currentTab,
                onChanged: (i) => setState(() => currentTab = i),
                destinations: const [
                  QuestDestination(icon: Icons.dashboard_rounded, label: 'Beranda'),
                  QuestDestination(icon: Icons.receipt_long_rounded, label: 'Transaksi'),
                  QuestDestination(icon: Icons.pie_chart_outline_rounded, label: 'Anggaran'),
                  QuestDestination(icon: Icons.bar_chart_rounded, label: 'Laporan'),
                ],
                centerAction: (
                  tooltip: 'Catat',
                  onTap: () {},
                  icon: Icons.add_rounded,
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Transaksi'), findsOneWidget);
    expect(find.text('Anggaran'), findsOneWidget);
    expect(find.text('Laporan'), findsOneWidget);

    // Tap Transaksi (index 1)
    await tester.tap(find.text('Transaksi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // Animating
    await tester.pumpAndSettle();
    expect(currentTab, 1);

    // Tap Anggaran (index 2) across center button gap
    await tester.tap(find.text('Anggaran'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // Animating across gap
    await tester.pumpAndSettle();
    expect(currentTab, 2);

    // Tap Laporan (index 3)
    await tester.tap(find.text('Laporan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(currentTab, 3);

    // Tap Beranda (index 0) returning all the way across
    await tester.tap(find.text('Beranda'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(currentTab, 0);
  });
}
