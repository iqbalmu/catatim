import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:catatim/capture/capture_channel.dart';
import 'package:catatim/capture/pipeline.dart';
import 'package:catatim/rules/engine.dart';
import 'package:catatim/rules/rule_set.dart';
import 'package:catatim/storage/database.dart';
import 'package:catatim/storage/repository.dart';
import 'package:catatim/theme/quest.dart';
import 'package:catatim/ui/bank_accounts_screen.dart';
import 'package:catatim/ui/capture_settings_screen.dart';
import 'package:catatim/ui/notif_screen.dart';

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

  testWidgets(
    'CaptureSettingsScreen: 2-tab layout, sheet hubungkan, status pill, dan pola abaikan',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // 1. Verifikasi 2 Segmented Tab
      expect(find.text('Bank & App'), findsOneWidget);
      expect(find.text('Sistem & Aturan'), findsOneWidget);

      // 2. Tab 0: Status Card + CTA Aktifkan Izin, Catat otomatis, Search, dan daftar bank
      expect(find.text('Perlu Izin Notifikasi'), findsOneWidget);
      expect(find.text('Aktifkan Izin'), findsOneWidget);
      expect(find.text('Cek Kesehatan'), findsOneWidget);
      expect(find.text('Catat otomatis'), findsOneWidget);
      expect(find.text('Cari bank atau e-wallet…'), findsOneWidget);
      expect(find.text('Bank Jago'), findsOneWidget);
      expect(find.text('BCA (myBCA / BCA mobile)'), findsOneWidget);
      expect(find.text('Hubungkan App Lain dari HP'), findsOneWidget);

      var openedListenerSettings = false;
      var mockListenerEnabled = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('catatim/capture'), (
            call,
          ) async {
            if (call.method == 'openListenerSettings') {
              openedListenerSettings = true;
              return null;
            }
            if (call.method == 'isListenerEnabled') return mockListenerEnabled;
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('catatim/capture'),
              null,
            );
      });

      // Tap switch Bank Jago saat izin belum aktif -> muncul bottom sheet panduan izin terpadu
      await tester.tap(find.bySemanticsLabel('Capture Bank Jago'));
      await tester.pumpAndSettle();
      expect(await repo.connectedBankIds(), isEmpty);
      expect(find.text('Hubungkan Bank Jago'), findsOneWidget);
      expect(find.text('Jaminan Privasi & Cara Kerja'), findsOneWidget);
      expect(find.text('Buka Pengaturan'), findsOneWidget);

      // Tap Buka Pengaturan di dalam bottom sheet izin
      await tester.tap(find.text('Buka Pengaturan'));
      await tester.pumpAndSettle();
      expect(openedListenerSettings, isTrue);

      // Simulasikan user balik dari Pengaturan tapi izin MASIH belum aktif
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Izinnya belum aktif'), findsOneWidget);
      expect(find.text('Buka Pengaturan Lagi'), findsOneWidget);

      // Simulasikan user menyalakan izin di Pengaturan lalu kembali ke app -> otomatis nyambung!
      mockListenerEnabled = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(await repo.connectedBankIds(), contains('jago'));
      expect(find.text('Capture Bank Jago diaktifkan.'), findsOneWidget);
      expect(find.text('Capture Aktif'), findsOneWidget);

      // Coba pencarian bank langsung di Tab 0
      await tester.enterText(find.byType(TextField).first, 'Jago');
      await tester.pumpAndSettle();
      expect(find.text('Bank Jago'), findsOneWidget);
      expect(find.text('BCA (myBCA / BCA mobile)'), findsNothing);

      // Hapus pencarian
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();
      expect(find.text('Bank Jago'), findsOneWidget);
      expect(find.text('BCA (myBCA / BCA mobile)'), findsOneWidget);

      // Tap status pill -> buka sheet Kesehatan & Izin Sistem
      await tester.tap(find.text('Capture Aktif'));
      await tester.pumpAndSettle();
      expect(find.text('Kesehatan & Izin Sistem'), findsOneWidget);
      expect(find.text('Panduan Khusus per Merk HP'), findsOneWidget);
      await tester.tap(find.text('Panduan Khusus per Merk HP'));
      await tester.pumpAndSettle();
      expect(find.textContaining('MIUI / HyperOS'), findsOneWidget);
      // Tutup sheet
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // 3. Pindah ke Tab 1: Sistem & Aturan
      await tester.tap(find.text('Sistem & Aturan'));
      await tester.pumpAndSettle();

      expect(find.text('Izin Akses Notifikasi'), findsOneWidget);
      expect(find.text('Optimasi Baterai'), findsOneWidget);
      expect(find.text('Lampu Sehat & Panduan Vendor'), findsOneWidget);
      expect(find.text('Alat Diagnostik & Pemulihan'), findsOneWidget);
      expect(find.text('Tambah'), findsOneWidget);

      // Buka dialog "+ Tambah Pola Abaikan"
      final tambahBtn = find.text('Tambah');
      await tester.ensureVisible(tambahBtn);
      await tester.pumpAndSettle();
      await tester.tap(tambahBtn);
      await tester.pumpAndSettle();

      expect(find.text('Tambah Pola Abaikan'), findsOneWidget);
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'promo cashback');
      await tester.enterText(textFields.at(1), 'Spam Promo');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

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
    },
  );

  testWidgets(
    'BankAccountsScreen & NotificationScreen: status jujur saat izin mati dan alur pengaktifan langsung di tempat',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var mockListenerEnabled = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('catatim/capture'), (
            call,
          ) async {
            if (call.method == 'isListenerEnabled') return mockListenerEnabled;
            if (call.method == 'openListenerSettings') return null;
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('catatim/capture'),
              null,
            );
      });

      // Hubungkan Bank Jago saat izin notifikasi masih mati
      await repo.setBankConnected('jago', true);
      await repo.ensureBankAccount(
        bankId: 'jago',
        name: 'Bank Jago',
        kind: ruleSet.bank('jago')!.accountKind,
      );

      // 1. Uji BankAccountsScreen: menampilkan kartu peringatan & status "Menunggu izin notifikasi"
      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          home: BankAccountsScreen(
            repository: repo,
            pipeline: pipeline,
            ruleSet: ruleSet,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Izin baca notifikasi belum aktif'), findsOneWidget);
      expect(find.text('Nyalakan Izin Notifikasi'), findsOneWidget);
      expect(find.textContaining('Menunggu izin notifikasi'), findsOneWidget);

      // Tap Nyalakan Izin Notifikasi -> muncul bottom sheet izin terpadu
      await tester.tap(find.text('Nyalakan Izin Notifikasi'));
      await tester.pumpAndSettle();
      expect(find.text('Aktifkan Izin Baca Notifikasi'), findsOneWidget);

      // Tutup dengan Nanti Saja
      await tester.tap(find.text('Nanti Saja'));
      await tester.pumpAndSettle();

      // 2. Uji NotificationScreen: peringatan "Nyalakan" langsung membuka bottom sheet izin
      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          home: NotificationScreen(
            repository: repo,
            pipeline: pipeline,
            ruleSet: ruleSet,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Izin baca notifikasi belum nyala'), findsOneWidget);
      await tester.tap(find.text('Nyalakan'));
      await tester.pumpAndSettle();
      expect(find.text('Aktifkan Izin Baca Notifikasi'), findsOneWidget);

      // Simulasikan izin diaktifkan di Pengaturan lalu kembali
      mockListenerEnabled = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Peringatan hilang otomatis karena izin sudah aktif
      expect(find.text('Izin baca notifikasi belum nyala'), findsNothing);
      expect(find.text('Belum ada peringatan'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
    },
  );
}
