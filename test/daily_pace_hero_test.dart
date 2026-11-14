import 'package:catatim/core/budget.dart';
import 'package:catatim/game/progress.dart';
import 'package:catatim/models.dart';
import 'package:catatim/storage/database.dart';
import 'package:catatim/storage/repository.dart';
import 'package:catatim/theme/quest.dart';
import 'package:catatim/ui/home_cards.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;
  late ProgressService progress;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LedgerRepository(db);
    progress = ProgressService(repository: repo);
  });

  Widget buildHero({VoidCallback? onTap}) {
    return MaterialApp(
      theme: QuestSchemes.light(),
      home: Scaffold(
        body: DailyPaceHeroCard(progress: progress, onTap: onTap ?? () {}),
      ),
    );
  }

  testWidgets(
    'DailyPaceHeroCard tampilkan empty state saat anggaran belum diatur',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildHero(onTap: () => tapped = true));
      await tester.pumpAndSettle();

      expect(find.text('Jatah hari ini belum diatur'), findsOneWidget);
      expect(find.text('Atur Batas Anggaran'), findsOneWidget);

      await tester.tap(find.text('Jatah hari ini belum diatur'));
      expect(tapped, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => db.close());
    },
  );

  testWidgets(
    'DailyPaceHeroCard tampilkan sisa aman dan status aman saat anggaran diatur',
    (tester) async {
      await tester.runAsync(() async {
        await repo.setSetting(kKeyDailyLimit, '100000');
        await progress.refresh();
      });

      await tester.pumpWidget(buildHero());
      await tester.pumpAndSettle();

      expect(find.text('Jatah hari ini'), findsOneWidget);
      expect(find.text('Aman'), findsOneWidget);
      expect(find.text('Sisa yang boleh dipakai hari ini'), findsOneWidget);
      expect(find.text('Keluar hari ini: Rp0'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => db.close());
    },
  );

  testWidgets(
    'DailyPaceHeroCard tampilkan defisit dan status Defisit saat pengeluaran over',
    (tester) async {
      await tester.runAsync(() async {
        await repo.setSetting(kKeyDailyLimit, '50000');
        await repo.addManual(
          amount: 75000,
          direction: Direction.outgoing,
          kind: TxKind.payment,
          occurredAt: DateTime.now(),
        );
        await progress.refresh();
      });

      await tester.pumpWidget(buildHero());
      await tester.pumpAndSettle();

      expect(find.text('Defisit'), findsOneWidget);
      expect(find.text('Melebihi jatah hari ini'), findsOneWidget);
      expect(find.text('Keluar hari ini: Rp75.000'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => db.close());
    },
  );
}
