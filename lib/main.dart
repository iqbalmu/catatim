import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'capture/capture_channel.dart';
import 'capture/pipeline.dart';
import 'game/progress.dart';
import 'rules/engine.dart';
import 'storage/database.dart';
import 'storage/repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await applyPendingRestore(); // pulihkan backup yang di-stage user
  final db = AppDatabase(await openAppDatabase());
  final repository = LedgerRepository(db);
  final engine = RuleEngine(await loadSeedRuleSet());
  final progress = ProgressService(repository: repository);
  final pipeline = CapturePipeline(
    channel: const CaptureChannel(),
    engine: engine,
    repository: repository,
    progress: progress,
  );
  unawaited(pipeline.start());
  unawaited(progress.refresh());

  runApp(BukuduitApp(
    repository: repository,
    pipeline: pipeline,
    progress: progress,
  ));
}
