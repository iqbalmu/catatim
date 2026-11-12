import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bukuduit/theme/quest.dart';
import 'package:bukuduit/ui/quest.dart';

void main() {
  testWidgets('QuestSelectField displays selected label and opens bottom sheet picker on tap', (tester) async {
    String? selectedValue = 'bca';
    bool addTriggered = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: QuestSchemes.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: QuestSelectField<String>(
                    labelText: 'Sumber Dana',
                    sheetTitle: 'Pilih Sumber Dana',
                    value: selectedValue,
                    options: const [
                      QuestSelectOption(
                        value: 'bca',
                        label: 'BCA',
                        subtitle: 'Rekening Bank',
                        icon: Icons.account_balance_rounded,
                      ),
                      QuestSelectOption(
                        value: 'gopay',
                        label: 'GoPay',
                        subtitle: 'E-Wallet',
                        icon: Icons.phone_android_rounded,
                      ),
                      QuestSelectOption(
                        value: 'cash',
                        label: 'Tunai',
                        subtitle: 'Dompet Tunai',
                        icon: Icons.payments_outlined,
                      ),
                    ],
                    onChanged: (val) => setState(() => selectedValue = val),
                    onAdd: () => addTriggered = true,
                    addLabel: 'Tambah Akun Baru',
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    // Initial state: shows "Sumber Dana" and "BCA"
    expect(find.text('Sumber Dana'), findsOneWidget);
    expect(find.text('BCA'), findsOneWidget);

    // Tap the select field to open picker
    await tester.tap(find.text('BCA'));
    await tester.pumpAndSettle();

    // Bottom sheet is now open
    expect(find.text('Pilih Sumber Dana'), findsOneWidget);
    expect(find.text('GoPay'), findsOneWidget);
    expect(find.text('Tunai'), findsOneWidget);
    expect(find.text('Tambah Akun Baru'), findsOneWidget);

    // Pick GoPay
    await tester.tap(find.text('GoPay'));
    await tester.pumpAndSettle();

    // Value should be updated to GoPay and sheet dismissed
    expect(selectedValue, 'gopay');
    expect(find.text('GoPay'), findsOneWidget);
    expect(find.text('Pilih Sumber Dana'), findsNothing);

    // Open again to test onAdd
    await tester.tap(find.text('GoPay'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tambah Akun Baru'));
    await tester.pumpAndSettle();

    expect(addTriggered, isTrue);
    expect(find.text('Pilih Sumber Dana'), findsNothing);
  });
}
