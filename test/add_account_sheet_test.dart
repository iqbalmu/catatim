import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:catatim/capture/capture_channel.dart';
import 'package:catatim/capture/pipeline.dart';
import 'package:catatim/rules/engine.dart';
import 'package:catatim/rules/rule_set.dart';
import 'package:catatim/storage/database.dart';
import 'package:catatim/storage/repository.dart';
import 'package:catatim/theme/quest.dart';
import 'package:catatim/ui/add_account_sheet.dart';

void main() {
  testWidgets(
    'AddAccountSheet: bebas overflow di layar sempit dengan banyak pilihan bank',
    (tester) async {
      // Gunakan resolusi layar HP kompak (360 x 640)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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
          {
            'id': 'nagari',
            'displayName': 'Bank Nagari',
            'packageNames': ['com.nagari'],
            'keywords': ['nagari'],
            'templates': [],
          },
          {
            'id': 'bca',
            'displayName': 'BCA',
            'packageNames': ['com.bca'],
            'keywords': ['bca'],
            'templates': [],
          },
          {
            'id': 'mandiri',
            'displayName': "Livin' by Mandiri",
            'packageNames': ['com.mandiri'],
            'keywords': ['livin'],
            'templates': [],
          },
          {
            'id': 'bri',
            'displayName': 'BRImo',
            'packageNames': ['com.bri'],
            'keywords': ['brimo'],
            'templates': [],
          },
          {
            'id': 'bni',
            'displayName': 'wondr by BNI',
            'packageNames': ['com.bni'],
            'keywords': ['wondr'],
            'templates': [],
          },
        ],
      });
      final pipeline = CapturePipeline(
        channel: const CaptureChannel(),
        engine: RuleEngine(ruleSet),
        repository: repo,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AddAccountSheet.show(
                  context,
                  repository: repo,
                  pipeline: pipeline,
                  ruleSet: ruleSet,
                ),
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      );

      // Buka sheet (beri kesempatan Future.wait DB/channel selesai di runAsync)
      await tester.tap(find.text('Buka'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      // Verifikasi judul dan bank muncul
      expect(find.text('Mau tambah apa?'), findsOneWidget);
      expect(find.text('blu by BCA'), findsOneWidget);
      expect(find.text('Bank Nagari'), findsOneWidget);
      expect(find.text("Livin' by Mandiri"), findsOneWidget);

      // Bebas overflow saat pertama buka
      expect(tester.takeException(), isNull);

      // Pastikan form manual tidak lagi menumpuk di layar pilih bank
      expect(find.text('Simpan'), findsNothing);
      expect(find.text('Bank lain? Catat manual'), findsOneWidget);

      // Ketuk "Bank lain? Catat manual" untuk masuk sub-step manual
      await tester.ensureVisible(find.text('Bank lain? Catat manual'));
      await tester.tap(find.text('Bank lain? Catat manual'));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Bank Manual'), findsOneWidget);
      expect(find.text('Simpan'), findsOneWidget);
      expect(find.text('CIMB Niaga'), findsOneWidget);

      // Bebas overflow di sub-step manual
      expect(tester.takeException(), isNull);

      // Kembali ke daftar bank otomatis
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();
      expect(find.text('Mau tambah apa?'), findsOneWidget);

      // Ketuk salah satu bank → membuka drawer baru dari bawah
      await tester.ensureVisible(find.text('BCA'));
      await tester.tap(find.text('BCA'));
      await tester.pumpAndSettle();
      expect(find.text('Hubungkan BCA'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tutup drawer hubungkan → kembali ke daftar bank
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();
      expect(find.text('Mau tambah apa?'), findsOneWidget);

      // Unmount dan bersihkan timer drift
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await db.close();
      });
    },
  );
}
