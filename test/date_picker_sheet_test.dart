import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:catatim/theme/quest.dart';
import 'package:catatim/ui/date_picker_sheet.dart';

void main() {
  Widget harness({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime?> onPicked,
  }) => MaterialApp(
    theme: QuestSchemes.light(),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showQuestDatePicker(
              context,
              initialDate: initialDate,
              firstDate: firstDate,
              lastDate: lastDate,
            ).then(onPicked),
            child: const Text('buka'),
          ),
        ),
      ),
    ),
  );

  testWidgets('drawer kalender mengembalikan tanggal yang dipilih', (
    tester,
  ) async {
    DateTime? picked;
    await tester.pumpWidget(
      harness(
        initialDate: DateTime(2026, 3, 10),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        onPicked: (v) => picked = v,
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Tanggal'), findsOneWidget);
    expect(find.text('Mar 2026'), findsOneWidget);

    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();

    expect(picked, DateTime(2026, 3, 15));
    expect(find.text('Pilih Tanggal'), findsNothing);
  });

  testWidgets('tanggal di luar batas tidak bisa dipilih', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(
      harness(
        initialDate: DateTime(2026, 3, 10),
        firstDate: DateTime(2026, 3),
        lastDate: DateTime(2026, 3, 15),
        onPicked: (v) => picked = v,
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    // Navigasi bulan berikutnya nonaktif — ujung rentang bulan ini.
    await tester.tap(find.byTooltip('Bulan berikutnya'));
    await tester.pumpAndSettle();
    expect(find.text('Mar 2026'), findsOneWidget);
    expect(find.text('Apr 2026'), findsNothing);

    // Tanggal 16 di luar batas: ketukan tidak menutup drawer.
    await tester.tap(find.text('16'));
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(find.text('Pilih Tanggal'), findsOneWidget);

    // Tanggal dalam batas tetap bisa dipilih.
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    expect(picked, DateTime(2026, 3, 12));
  });
}
