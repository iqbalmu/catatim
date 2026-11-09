import 'package:bukuduit/capture/capture_channel.dart';
import 'package:bukuduit/capture/pipeline.dart';
import 'package:bukuduit/game/progress.dart';
import 'package:bukuduit/rules/engine.dart';
import 'package:bukuduit/rules/rule_set.dart';
import 'package:bukuduit/storage/database.dart';
import 'package:bukuduit/storage/repository.dart';
import 'package:bukuduit/theme/quest.dart';
import 'package:bukuduit/ui/home_cards.dart';
import 'package:bukuduit/ui/home_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'StackedHeroCards tumpang tindih: swipe kiri atau kanan bebas menukar kedua kartu',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LedgerRepository(db);
    final ruleSet = RuleSet.fromJson({'version': 1, 'banks': []});
    final pipeline = CapturePipeline(
      channel: const CaptureChannel(),
      engine: RuleEngine(ruleSet),
      repository: repo,
    );
    final progress = ProgressService(repository: repo);
    await repo.getAccounts();

    await tester.pumpWidget(
      MaterialApp(
        theme: QuestSchemes.light(),
        home: HomeScreen(
          repository: repo,
          pipeline: pipeline,
          progress: progress,
          ruleSet: ruleSet,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Pastikan tidak ada tab pill teks seperti sebelumnya
    expect(find.text('Geser kartu'), findsNothing);

    // 1. Awalnya Pace Harian aktif di atas, dan kartu belakang menampilkan info Total Saldo
    expect(find.text('Pace Harian Belum Aktif'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Kartu di belakang: Total Saldo')),
      findsOneWidget,
    );

    // 2. Swipe kiri (drag left) menukar ke Total Saldo, dan kartu belakang menampilkan info Pace Harian
    await tester.drag(find.byType(StackedHeroCards), const Offset(-250, 0), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('TOTAL SALDO'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Kartu di belakang: Pace Harian')),
      findsOneWidget,
    );

    // 3. Swipe kiri LAGI (bebas arah kiri/kanan) menukar kembali ke Pace Harian
    await tester.drag(find.byType(StackedHeroCards), const Offset(-250, 0), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Pace Harian Belum Aktif'), findsOneWidget);

    // 4. Swipe kanan (drag right) menukar ke Total Saldo
    await tester.drag(find.byType(StackedHeroCards), const Offset(250, 0), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('TOTAL SALDO'), findsOneWidget);

    // 5. Swipe kanan LAGI menukar kembali ke Pace Harian
    await tester.drag(find.byType(StackedHeroCards), const Offset(250, 0), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Pace Harian Belum Aktif'), findsOneWidget);

    // 6. Tap bagian bawah kartu pasif yang mengintip juga menukar kartu
    final rect = tester.getRect(find.byType(StackedHeroCards));
    await tester.tapAt(Offset(rect.center.dx, rect.bottom - 4));
    await tester.pumpAndSettle();

    expect(find.text('TOTAL SALDO'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  });
}
