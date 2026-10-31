import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'capture/capture_channel.dart';
import 'capture/pipeline.dart';
import 'game/progress.dart';
import 'rules/engine.dart';
import 'storage/database.dart';
import 'storage/repository.dart';
import 'storage/seed_dummy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await applyPendingRestore(); // pulihkan backup yang di-stage user
  final db = AppDatabase(await openAppDatabase());
  final repository = LedgerRepository(db);
  await seedDummyIfEmpty(db, repository); // data contoh (debug, DB kosong)
  await refreshSeedDemoDates(db); // geser tanggal demo mengikuti hari ini
  unawaited(repository.pruneCaptureLogs()); // log terbaca/dup >30 hari
  // Katalog bank dimuat sekali — dipakai engine (parser) + UI (hubungkan).
  // Aturan pengguna tak lagi di-seed/di-load ke pipeline: model hubungkan
  // bank memakai seed rules murni agar bankId selalu ID katalog asli.
  final ruleSet = await loadSeedRuleSet();
  final engine = RuleEngine(ruleSet);
  final progress = ProgressService(repository: repository);
  final pipeline = CapturePipeline(
    channel: const CaptureChannel(),
    engine: engine,
    repository: repository,
  );
  unawaited(pipeline.start());
  unawaited(progress.refresh());

  runApp(
    BukuduitApp(
      repository: repository,
      pipeline: pipeline,
      progress: progress,
      ruleSet: ruleSet,
    ),
  );
}
