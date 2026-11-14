import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:catatim/storage/database.dart';
import 'package:catatim/storage/repository.dart';
import 'package:catatim/theme/quest.dart';
import 'package:catatim/ui/rencana_batas.dart';

void main() {
  testWidgets(
    'showAddCategoryFlow: nama + alokasi tersimpan saat tombol Tambah ditekan',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = LedgerRepository(db);

      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showAddCategoryFlow(context, repo),
                  child: const Text('buka'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Kopi');
      await tester.enterText(find.byType(TextField).last, '50000');
      await tester.tap(find.text('Tambah'));
      // Majukan jam melewati auto-dismiss SnackBar sukses; pumpAndSettle
      // setelahnya supaya teardown tidak menemukan frame/timer pending.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final categories = await repo.getCategories();
      expect(categories.map((c) => c.name), contains('Kopi'));

      // Baca langsung tabel budgets (bukan watch) — stream query drift
      // tidak drain di fake-async teardown.
      final budgets = await db.select(db.budgets).get();
      expect(
        budgets.any((b) => b.monthlyLimit == 50000),
        isTrue,
        reason: 'alokasi bulanan harus ikut tersimpan',
      );
    },
  );
}
