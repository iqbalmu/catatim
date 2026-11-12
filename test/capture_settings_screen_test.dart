import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:bukuduit/capture/capture_channel.dart';
import 'package:bukuduit/capture/pipeline.dart';
import 'package:bukuduit/rules/engine.dart';
import 'package:bukuduit/rules/rule_set.dart';
import 'package:bukuduit/storage/database.dart';
import 'package:bukuduit/storage/repository.dart';
import 'package:bukuduit/theme/quest.dart';
import 'package:bukuduit/ui/capture_settings_screen.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;
  late RuleSet ruleSet;
  late CapturePipeline pipeline;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LedgerRepository(db);
    ruleSet = RuleSet.fromJson({
      'version': 1,
      'banks': [
        {
          'id': 'bca',
          'displayName': 'BCA (myBCA / BCA mobile)',
          'packageNames': ['com.bca'],
          'keywords': ['bca'],
          'templates': [],
        },
        {
          'id': 'jago',
          'displayName': 'Bank Jago',
          'packageNames': ['com.jago'],
          'keywords': ['jago'],
          'templates': [],
        },
      ],
    });
    pipeline = CapturePipeline(
      channel: const CaptureChannel(),
      engine: RuleEngine(ruleSet),
      repository: repo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildScreen() {
    return MaterialApp(
      theme: QuestSchemes.light(),
      home: CaptureSettingsScreen(
        repository: repo,
        pipeline: pipeline,
        ruleSet: ruleSet,
      ),
    );
  }

  testWidgets('CaptureSettingsScreen: 3-tab layout, navigasi tab, dan penambahan pola abaikan',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // 1. Verifikasi Segmented Tab
    expect(find.text('Bank & E-Wallet'), findsOneWidget);
    expect(find.text('Izin & Sistem'), findsOneWidget);
    expect(find.text('Aturan & Alat'), findsOneWidget);

    // 2. Tab 0: Bank & E-Wallet
    expect(find.text('Cari bank atau e-wallet…'), findsOneWidget);
    expect(find.text('Bank Jago'), findsOneWidget);
    expect(find.text('BCA (myBCA / BCA mobile)'), findsOneWidget);

    // Coba pencarian
    await tester.enterText(find.byType(TextField).first, 'Jago');
    await tester.pumpAndSettle();
    expect(find.text('Bank Jago'), findsOneWidget);
    expect(find.text('BCA (myBCA / BCA mobile)'), findsNothing);

    // Hapus pencarian
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    expect(find.text('Bank Jago'), findsOneWidget);
    expect(find.text('BCA (myBCA / BCA mobile)'), findsOneWidget);

    // 3. Pindah ke Tab 1: Izin & Sistem
    await tester.tap(find.text('Izin & Sistem'));
    await tester.pumpAndSettle();

    expect(find.text('KESEHATAN PENANGKAP (LAMPU SEHAT)'), findsOneWidget);
    expect(find.text('Layanan Terhenti'), findsOneWidget);
    expect(find.text('Detak Listener'), findsOneWidget);
    expect(find.text('Notif Bank Terakhir'), findsOneWidget);
    expect(find.text('Bank Terpantau'), findsOneWidget);
    expect(find.text('Akses Notifikasi Belum Aktif'), findsOneWidget);
    expect(find.text('Optimasi Baterai HP'), findsOneWidget);
    expect(find.text('Panduan Khusus per Merk HP'), findsOneWidget);
    expect(find.textContaining('100% Offline & Privat'), findsOneWidget);

    // Expand & collapse Panduan Khusus Vendor HP (pastikan tidak crash PageStorage cast double to bool)
    await tester.tap(find.text('Panduan Khusus per Merk HP'));
    await tester.pumpAndSettle();
    expect(find.textContaining('MIUI / HyperOS'), findsOneWidget);

    // Scroll pada listview izin
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pumpAndSettle();

    // Pindah ke Tab 0 lalu kembali ke Tab 1 untuk memicu pemulihan PageStorage
    await tester.tap(find.text('Bank & E-Wallet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Izin & Sistem'));
    await tester.pumpAndSettle();
    expect(find.textContaining('MIUI / HyperOS'), findsOneWidget);

    // 4. Pindah ke Tab 2: Aturan & Alat
    await tester.tap(find.text('Aturan & Alat'));
    await tester.pumpAndSettle();

    expect(find.text('Simulator & Validasi Notifikasi'), findsOneWidget);
    expect(find.text('Tambah'), findsOneWidget);

    // Buka dialog "+ Tambah Pola Abaikan"
    final tambahBtn = find.text('Tambah');
    expect(tambahBtn, findsOneWidget);
    await tester.ensureVisible(tambahBtn);
    await tester.pumpAndSettle();
    await tester.tap(tambahBtn);
    await tester.pumpAndSettle();

    expect(find.text('Tambah Pola Abaikan'), findsOneWidget);

    // Isi form dialog
    expect(find.text('Kata Kunci / Frasa'), findsOneWidget);
    expect(find.text('Deskripsi / Label (Opsional)'), findsOneWidget);
    final textFields = find.byType(TextField);
    final patternField = textFields.first;
    final labelField = textFields.at(1);

    await tester.enterText(patternField, 'promo cashback');
    await tester.enterText(labelField, 'Spam Promo');
    await tester.pumpAndSettle();

    // Simpan pola
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Verifikasi pola muncul di list
    final ignored = await repo.ignoredPatterns();
    expect(ignored.length, 1);
    expect(ignored.first.pattern, 'promo cashback');
    expect(ignored.first.label, 'Spam Promo');
    expect(find.text('Spam Promo'), findsOneWidget);
    expect(find.text('Pola: "promo cashback"'), findsOneWidget);

    // Unmount dan bersihkan timer drift stream
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
  });
}
