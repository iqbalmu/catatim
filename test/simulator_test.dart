import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catatim/capture/pipeline.dart';
import 'package:catatim/capture/simulator.dart';
import 'package:catatim/capture/capture_channel.dart';
import 'package:catatim/rules/engine.dart';
import 'package:catatim/rules/rule_set.dart';
import 'package:catatim/storage/database.dart';
import 'package:catatim/storage/repository.dart';

RuleSet _loadSeed() {
  final raw = File('assets/rules/seed_rules.json').readAsStringSync();
  return RuleSet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  late RuleEngine engine;
  late AppDatabase db;
  late LedgerRepository repository;
  late CapturePipeline pipeline;

  setUp(() async {
    engine = RuleEngine(_loadSeed());
    db = AppDatabase(NativeDatabase.memory());
    repository = LedgerRepository(db);
    pipeline = CapturePipeline(
      channel: const CaptureChannel(),
      engine: engine,
      repository: repository,
    );
    // Hubungkan bank blu dan nagari agar draf bisa diproses
    await repository.setBankConnected('blu', true);
    await repository.setBankConnected('nagari', true);
  });

  tearDown(() async {
    await db.close();
  });

  group('NotificationSimulator - Batch & Dry Run', () {
    test('runBatch memvalidasi seluruh preset bawaan dengan akurasi 100%', () {
      final report = NotificationSimulator.runBatch(engine: engine);

      expect(report.total, kSimulatorPresets.length);
      for (final evaluation in report.evaluations) {
        expect(
          evaluation.passedExpectation,
          isTrue,
          reason:
              'Gagal pada preset ${evaluation.scenario?.name}: ${evaluation.message}',
        );
      }
      expect(report.failed, 0);
      expect(report.isAllPassed, isTrue);
      expect(report.passRate, 100.0);
    });

    test(
      'evaluate mendeteksi skenario negatif OTP dan tidak mem-parse transaksi',
      () {
        final eval = NotificationSimulator.evaluate(
          engine: engine,
          packageName: 'com.bcadigital.blu',
          title: 'blu by BCA',
          body: 'JANGAN BERIKAN KODE OTP 123456 kepada siapa pun.',
        );
        expect(eval.parsed, isFalse);
      },
    );

    test(
      'injectEndToEnd mendorong notifikasi ke antrean draf dan bisa dibersihkan',
      () async {
        final initialCount = await NotificationSimulator.countTrackedDrafts(
          repository,
        );
        expect(initialCount, 0);

        // Injeksi 1 preset blu transfer masuk
        final draftId = await NotificationSimulator.injectEndToEnd(
          pipeline: pipeline,
          repository: repository,
          packageName: 'com.bcadigital.blu',
          title: 'blu',
          body: 'Transfer masuk dari BUDI SANTOSO sebesar Rp 250.000 berhasil.',
        );

        expect(draftId, isNotNull);

        final drafts = await repository.watchDrafts().first;
        expect(drafts.any((d) => d.id == draftId), isTrue);

        final trackedCount = await NotificationSimulator.countTrackedDrafts(
          repository,
        );
        expect(trackedCount, 1);

        // Bersihkan data uji coba
        final deleted = await NotificationSimulator.cleanupSimulatedData(
          repository,
        );
        expect(deleted, 1);

        final remainingDrafts = await repository.watchDrafts().first;
        expect(remainingDrafts.any((d) => d.id == draftId), isFalse);

        final trackedAfter = await NotificationSimulator.countTrackedDrafts(
          repository,
        );
        expect(trackedAfter, 0);
      },
    );
  });
}
