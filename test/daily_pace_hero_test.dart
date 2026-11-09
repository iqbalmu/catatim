import 'package:bukuduit/core/budget.dart';
import 'package:bukuduit/game/progress.dart';
import 'package:bukuduit/models.dart';
import 'package:bukuduit/storage/database.dart';
import 'package:bukuduit/storage/repository.dart';
import 'package:bukuduit/theme/quest.dart';
import 'package:bukuduit/ui/home_cards.dart';
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
        body: DailyPaceHeroCard(
          progress: progress,
          onTap: onTap ?? () {},
        ),
      ),
    );
  }

  testWidgets('DailyPaceHeroCard tampilkan empty state saat anggaran belum diatur',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildHero(onTap: () => tapped = true));
    await tester.pumpAndSettle();

    expect(find.text('Pace Harian Belum Aktif'), findsOneWidget);
    expect(find.text('Atur Batas Anggaran'), findsOneWidget);

    await tester.tap(find.text('Pace Harian Belum Aktif'));
    expect(tapped, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => db.close());
  });

  testWidgets(
      'DailyPaceHeroCard tampilkan sisa aman dan status aman saat anggaran diatur',
      (tester) async {
    await tester.runAsync(() async {
      await repo.setSetting(kKeyDailyLimit, '100000');
      await progress.refresh();
    });

    await tester.pumpWidget(buildHero());
    await tester.pumpAndSettle();

    expect(find.text('PACE HARIAN'), findsOneWidget);
    expect(find.text('Aman'), findsOneWidget);
    expect(find.text('Sisa aman hari ini'), findsOneWidget);
    expect(find.text('Keluar hari ini: Rp0'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => db.close());
  });

  testWidgets(
      'DailyPaceHeroCard tampilkan defisit dan status Defisit Harian saat pengeluaran over',
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

    expect(find.text('Defisit Harian'), findsOneWidget);
    expect(find.text('Defisit belanja hari ini'), findsOneWidget);
    expect(find.text('Keluar hari ini: Rp75.000'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => db.close());
  });
}
