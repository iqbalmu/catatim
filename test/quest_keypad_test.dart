import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catatim/theme/quest.dart';
import 'package:catatim/ui/quest.dart';

void main() {
  Widget wrapKeypad({
    required int amount,
    required ValueChanged<int> onChanged,
    required VoidCallback onSave,
    String saveLabel = 'Simpan',
    int maxDigits = 12,
  }) {
    return MaterialApp(
      theme: QuestSchemes.light(),
      home: Scaffold(
        body: QuestKeypad(
          amount: amount,
          onChanged: onChanged,
          onSave: onSave,
          saveLabel: saveLabel,
          maxDigits: maxDigits,
        ),
      ),
    );
  }

  testWidgets('menekan digit menambahkan angka', (tester) async {
    int current = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return wrapKeypad(
            amount: current,
            onChanged: (v) => setState(() => current = v),
            onSave: () {},
          );
        },
      ),
    );

    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    expect(current, 5);

    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(current, 52);
  });

  testWidgets('menekan 000 mengalikan 1000', (tester) async {
    int current = 15;
    late StateSetter updateState;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          updateState = setState;
          return wrapKeypad(
            amount: current,
            onChanged: (v) => setState(() => current = v),
            onSave: () {},
          );
        },
      ),
    );

    await tester.tap(find.text('000'));
    await tester.pumpAndSettle();
    expect(current, 15000);

    // Saat nominal 0, menekan 000 tidak mengubah nilai
    updateState(() => current = 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('000'));
    await tester.pumpAndSettle();
    expect(current, 0);
  });

  testWidgets(
    'menekan backspace menghapus 1 digit, long press menghapus semua',
    (tester) async {
      int current = 12500;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return wrapKeypad(
              amount: current,
              onChanged: (v) => setState(() => current = v),
              onSave: () {},
            );
          },
        ),
      );

      // Backspace tap
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pumpAndSettle();
      expect(current, 1250);

      // Backspace long press
      await tester.longPress(find.byIcon(Icons.backspace_outlined));
      await tester.pumpAndSettle();
      expect(current, 0);
    },
  );

  testWidgets('menekan C mengosongkan nominal ke 0', (tester) async {
    int current = 750000;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return wrapKeypad(
            amount: current,
            onChanged: (v) => setState(() => current = v),
            onSave: () {},
          );
        },
      ),
    );

    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();
    expect(current, 0);
  });

  testWidgets('batas maxDigits mencegah input tembus batas', (tester) async {
    int current = 999;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return wrapKeypad(
            amount: current,
            maxDigits: 4,
            onChanged: (v) => setState(() => current = v),
            onSave: () {},
          );
        },
      ),
    );

    // Tambah 1 digit (jadi 4 digit = 9995) -> diizinkan
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    expect(current, 9995);

    // Tambah 1 digit lagi (jadi 5 digit) -> ditolak karena maxDigits = 4
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    expect(current, 9995);

    // Menekan 000 (akan jadi 7 digit) -> ditolak
    await tester.tap(find.text('000'));
    await tester.pumpAndSettle();
    expect(current, 9995);
  });

  testWidgets('tombol simpan: disabled saat nominal 0, enabled saat > 0', (
    tester,
  ) async {
    int savedCount = 0;
    int current = 0;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return wrapKeypad(
            amount: current,
            saveLabel: 'Catat',
            onChanged: (v) => setState(() => current = v),
            onSave: () => savedCount++,
          );
        },
      ),
    );

    expect(find.text('Catat'), findsOneWidget);

    // Saat amount == 0, tombol ditekan tidak memicu onSave
    await tester.tap(find.text('Catat'));
    await tester.pumpAndSettle();
    expect(savedCount, 0);

    // Isi nominal > 0
    await tester.tap(find.text('8'));
    await tester.pumpAndSettle();
    expect(current, 8);

    // Saat amount > 0, tombol ditekan memicu onSave
    await tester.tap(find.text('Catat'));
    await tester.pumpAndSettle();
    expect(savedCount, 1);
  });
}
