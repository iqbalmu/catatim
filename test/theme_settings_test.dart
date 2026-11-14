import 'package:catatim/capture/capture_channel.dart';
import 'package:catatim/capture/pipeline.dart';
import 'package:catatim/game/progress.dart';
import 'package:catatim/rules/engine.dart';
import 'package:catatim/rules/rule_set.dart';
import 'package:catatim/storage/database.dart';
import 'package:catatim/storage/repository.dart';
import 'package:catatim/theme/quest.dart';
import 'package:catatim/ui/settings_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThemeMode Settings & UI', () {
    late AppDatabase db;
    late LedgerRepository repo;
    late ProgressService progress;
    late RuleSet ruleSet;
    late CapturePipeline pipeline;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = LedgerRepository(db);
      progress = ProgressService(repository: repo);
      ruleSet = RuleSet(version: 1, banks: []);
      pipeline = CapturePipeline(
        channel: const CaptureChannel(),
        engine: RuleEngine(ruleSet),
        repository: repo,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Repository: getThemeMode, setThemeMode, watchThemeMode', () async {
      // Default: system
      expect(await repo.getThemeMode(), equals(ThemeMode.system));

      // Set to dark
      await repo.setThemeMode(ThemeMode.dark);
      expect(await repo.getThemeMode(), equals(ThemeMode.dark));

      // Set to light
      await repo.setThemeMode(ThemeMode.light);
      expect(await repo.getThemeMode(), equals(ThemeMode.light));

      // Set back to system
      await repo.setThemeMode(ThemeMode.system);
      expect(await repo.getThemeMode(), equals(ThemeMode.system));
    });

    testWidgets('SettingsScreen: buka lembar pilih tema dan ganti ke Gelap', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          darkTheme: QuestSchemes.dark(),
          home: Scaffold(
            body: SettingsScreen(
              repository: repo,
              pipeline: pipeline,
              ruleSet: ruleSet,
              progress: progress,
            ),
          ),
        ),
      );
      // SettingsScreen menampilkan Pochy beranimasi (loop) — pump manual.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Cari tile 'Tema Tampilan'
      final themeTile = find.text('Tema Tampilan');
      expect(themeTile, findsOneWidget);
      expect(find.text('Sistem'), findsOneWidget);

      // Tap tile Tema Tampilan untuk membuka bottom sheet
      await tester.tap(themeTile);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Verifikasi opsi-opsi tema di bottom sheet
      // 'Sistem' tampil di baris pengaturan dan di opsi lembar.
      expect(find.text('Sistem'), findsNWidgets(2));
      expect(find.text('Terang'), findsOneWidget);
      expect(find.text('Gelap'), findsOneWidget);

      // Tap opsi 'Gelap'
      await tester.tap(find.text('Gelap'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verifikasi nilai tersimpan di repository
      expect(await repo.getThemeMode(), equals(ThemeMode.dark));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
