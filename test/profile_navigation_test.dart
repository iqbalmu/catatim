import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:catatim/capture/capture_channel.dart';
import 'package:catatim/capture/pipeline.dart';
import 'package:catatim/game/progress.dart';
import 'package:catatim/rules/engine.dart';
import 'package:catatim/rules/rule_set.dart';
import 'package:catatim/storage/database.dart';
import 'package:catatim/storage/repository.dart';
import 'package:catatim/theme/quest.dart';
import 'package:catatim/ui/home_screen.dart';
import 'package:catatim/ui/laporan_screen.dart';
import 'package:catatim/ui/settings_screen.dart';

void main() {
  testWidgets(
    'HomeScreen: Laporan menggantikan Profil di navbar, Profil dibuka dari Header Beranda tanpa navbar',
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

      // 1. Verifikasi navbar memiliki 'Laporan' dan tidak ada 'Profil' di navbar
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Transaksi'), findsOneWidget);
      expect(find.text('Bon'), findsOneWidget);
      expect(find.text('Laporan'), findsOneWidget);
      expect(find.text('Profil'), findsNothing);

      // 2. Tab Laporan di navbar berfungsi
      await tester.tap(find.text('Laporan'));
      await tester.pumpAndSettle();
      expect(find.byType(LaporanScreen), findsOneWidget);

      // Kembali ke tab Beranda
      await tester.tap(find.text('Beranda'));
      await tester.pumpAndSettle();
      expect(find.byType(LaporanScreen), findsNothing);

      // 3. Buka Profil dari Header Beranda (tombol avatar di pojok kanan atas)
      final profileHeaderBtn = find.byIcon(Icons.person_outline_rounded);
      expect(profileHeaderBtn, findsOneWidget);

      await tester.tap(profileHeaderBtn);
      await tester.pumpAndSettle();

      // Layar Profil & Pengaturan tampil secara mandiri dengan tombol back (tanpa navbar)
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Profil & Pengaturan'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Verifikasi 2 grup terstruktur: Manajemen Keuangan & Pengaturan Sistem
      expect(find.text('Akun Bank & Dompet'), findsOneWidget);
      expect(find.text('Anggaran & Kategori'), findsOneWidget);
      expect(find.text('Laporan Finansial'), findsOneWidget);

      // Tekan tombol back di halaman Profil untuk kembali ke Beranda
      final settingsBackButton = find.byIcon(Icons.arrow_back_rounded);
      await tester.tap(settingsBackButton);
      await tester.pumpAndSettle();

      // Sudah kembali ke Beranda
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.text('Beranda'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await db.close();
    },
  );
}
