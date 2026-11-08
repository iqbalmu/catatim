import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:bukuduit/capture/capture_channel.dart';
import 'package:bukuduit/capture/pipeline.dart';
import 'package:bukuduit/game/progress.dart';
import 'package:bukuduit/rules/engine.dart';
import 'package:bukuduit/rules/rule_set.dart';
import 'package:bukuduit/storage/database.dart';
import 'package:bukuduit/storage/repository.dart';
import 'package:bukuduit/theme/quest.dart';
import 'package:bukuduit/ui/home_screen.dart';
import 'package:bukuduit/ui/laporan_screen.dart';
import 'package:bukuduit/ui/settings_screen.dart';

void main() {
  testWidgets(
    'HomeScreen: Tab Profil & Pengaturan menggantikan Laporan di navbar, dan Laporan dapat dibuka dari Profil',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LedgerRepository(db);
      final ruleSet = RuleSet.fromJson({
        'version': 1,
        'banks': [
          {
            'id': 'blu',
            'displayName': 'blu by BCA',
            'packageNames': ['id.bm.blu'],
            'keywords': ['blu'],
            'templates': [],
          },
        ],
      });
      final pipeline = CapturePipeline(
        channel: const CaptureChannel(),
        engine: RuleEngine(ruleSet),
        repository: repo,
      );
      final progress = ProgressService(repository: repo);

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

      // Verifikasi navbar memiliki 'Profil' dan tidak ada 'Laporan' di navbar
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Transaksi'), findsOneWidget);
      expect(find.text('Bon'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('Laporan'), findsNothing);

      // Pindah ke tab Profil via bottom nav
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();

      // Layar Profil & Pengaturan tampil
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Profil & Pengaturan'), findsOneWidget);
      expect(find.text('Laporan Finansial'), findsOneWidget);

      // Buka Laporan Finansial dari dalam Profil & Pengaturan
      await tester.tap(find.text('Laporan Finansial'));
      await tester.pumpAndSettle();

      // Layar Laporan sekarang terbuka dengan tombol back
      expect(find.byType(LaporanScreen), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Tekan tombol back untuk kembali ke Profil & Pengaturan
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Profil & Pengaturan'), findsOneWidget);

      // Kembali ke tab Beranda
      await tester.tap(find.text('Beranda'));
      await tester.pumpAndSettle();

      // Di Beranda, header sudah bersih tanpa tombol profil/pengaturan
      expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.settings_outlined), findsNothing);

      // Tunggu timer refresh settle selesai dan tutup db
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await db.close();
    },
  );

  testWidgets(
    'SettingsScreen di tab Profil: komponen menetas dengan animasi bertahap (QuestTabEnter)',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LedgerRepository(db);
      final ruleSet = RuleSet.fromJson({
        'version': 1,
        'banks': [],
      });
      final pipeline = CapturePipeline(
        channel: const CaptureChannel(),
        engine: RuleEngine(ruleSet),
        repository: repo,
      );
      final progress = ProgressService(repository: repo);

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

      // Pindah ke tab Profil
      await tester.tap(find.text('Profil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // Di tengah animasi, kartu di tab Profil sedang menetas (opacity < 1.0)
      final cardOpacity = tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.text('Laporan Finansial'),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(cardOpacity, lessThan(1.0));

      await tester.pumpAndSettle();
      final settledOpacity = tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.text('Laporan Finansial'),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(settledOpacity, equals(1.0));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await db.close();
    },
  );
}
