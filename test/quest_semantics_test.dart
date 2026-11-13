import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catatim/theme/quest.dart';
import 'package:catatim/ui/month_picker.dart';
import 'package:catatim/ui/quest.dart';

/// Spot-check semantik TalkBack yang ditambahkan $impeccable harden
/// (audit 2026-11-11): state terpilih diumumkan pada pemilih bulan dan chip.
void main() {
  testWidgets('QuestMonthPicker: sel bulan mengumumkan selected + label',
      (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(MaterialApp(
      theme: QuestSchemes.light(),
      home: Scaffold(
        body: QuestMonthPicker(
          initialMonth: DateTime(2026, 5),
          onChanged: (_) {},
        ),
      ),
    ));

    final mei = tester.getSemantics(find.bySemanticsLabel('Mei').first);
    expect(mei.label, 'Mei');
    expect(mei.flagsCollection.isSelected, Tristate.isTrue,
        reason: 'Bulan terpilih harus diumumkan ke TalkBack');
    expect(mei.flagsCollection.isButton, isTrue);

    final jan = tester.getSemantics(find.bySemanticsLabel('Jan').first);
    expect(jan.flagsCollection.isSelected, isNot(Tristate.isTrue),
        reason: 'Bulan lain tidak boleh menyaru terpilih');

    handle.dispose();
  });

  testWidgets('QuestChip: state selected terumumkan', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(MaterialApp(
      theme: QuestSchemes.light(),
      home: Scaffold(
        body: Center(
          child: QuestChip(
            label: 'Makanan',
            selected: true,
            onTap: () {},
          ),
        ),
      ),
    ));

    final chip = tester.getSemantics(find.bySemanticsLabel('Makanan').first);
    expect(chip.label, 'Makanan');
    expect(chip.flagsCollection.isSelected, Tristate.isTrue);
    expect(chip.flagsCollection.isButton, isTrue);

    handle.dispose();
  });

  testWidgets(
    'QuestButton: label tidak menyusut saat font scale naik (re-audit P2)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          home: const Scaffold(
            body: Center(
              child: QuestButton(
                label: 'Catat Transaksi Sekarang',
                onPressed: null,
              ),
            ),
          ),
        ),
      );

      // FittedBox(scaleDown) memperkecil teks di bawah preferensi font
      // pengguna — label kini ellipsis, ukuran tetap mengikuti textScaler.
      expect(
        find.descendant(
          of: find.byType(QuestButton),
          matching: find.byType(FittedBox),
        ),
        findsNothing,
      );
      final label =
          tester.widget<Text>(find.text('Catat Transaksi Sekarang'));
      expect(label.maxLines, 1);
      expect(label.style?.fontSize, 14);
    },
  );
}
