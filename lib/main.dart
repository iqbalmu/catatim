import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'ui/locked_screen.dart';

import 'capture/capture_channel.dart';
import 'capture/pipeline.dart';
import 'game/progress.dart';
import 'notify/budget_alert_service.dart';
import 'rules/engine.dart';
import 'storage/database.dart';
import 'storage/repository.dart';
import 'storage/seed_dummy.dart';
import 'theme/quest.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Edge-to-edge (audit A-03): konten mengalir di belakang status bar;
  // gaya ikonnya diatur per-tema lewat AnnotatedRegion di HomeScreen.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Frame pertama tampil SEKARANG; init berat jalan di belakang splash
  // (audit F-01 — dulu buka DB + seed menahan startup 2,6–3,2 dtk).
  runApp(const BukuduitBootstrap());
}

/// rules — lalu tukar ke app utama / layar terkunci.
/// Splash + init async: pulihkan restore, buka DB sekali (probe kunci
/// memakai koneksi yang sama — tidak dua kali buka), seed, katalog
/// rules — lalu tukar ke app utana / layar terkunci.
class BukuduitBootstrap extends StatefulWidget {
  const BukuduitBootstrap({super.key});

  @override
  State<BukuduitBootstrap> createState() => _BukuduitBootstrapState();
}

class _BukuduitBootstrapState extends State<BukuduitBootstrap> {
  Widget? _ready;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    await applyPendingRestore(); // pulihkan backup yang di-stage user
    final db = AppDatabase(await openAppDatabase());

    // DB lama tak terbaca dengan kunci perangkat ini (mis. pindah HP)
    // → layar pemulihan, bukan crash generik (audit A-06).
    try {
      await db
          .customSelect(
            'SELECT count(*) AS c FROM sqlite_master',
            variables: const [],
            readsFrom: const {},
          )
          .get();
    } catch (_) {
      await db.close();
      if (mounted) setState(() => _locked = true);
      return;
    }

    final repository = LedgerRepository(db);
    await seedDummyIfEmpty(db, repository); // data contoh (debug, DB kosong)
    await refreshSeedDemoDates(db); // geser tanggal demo mengikuti hari ini
    unawaited(repository.pruneCaptureLogs()); // log terbaca/dup >30 hari

    // Katalog bank dimuat sekali — dipakai engine (parser) + UI (hubungkan).
    // Aturan pengguna tak lagi di-seed/di-load ke pipeline: model hubungkan
    // bank memakai seed rules murni agar bankId selalu ID katalog asli.
    final ruleSet = await loadSeedRuleSet();
    final engine = RuleEngine(ruleSet);
    final progress = ProgressService(
      repository: repository,
      alerts: BudgetAlertService(repository: repository),
    );
    final pipeline = CapturePipeline(
      channel: const CaptureChannel(),
      engine: engine,
      repository: repository,
      progress: progress,
    );
    unawaited(pipeline.start());
    unawaited(progress.refresh());

    if (!mounted) return;
    setState(() {
      _ready = BukuduitApp(
        repository: repository,
        pipeline: pipeline,
        progress: progress,
        ruleSet: ruleSet,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = _ready;
    if (app != null) return app;
    if (_locked) return const BukuduitLockedApp();
    // Splash mengikuti brightness perangkat supaya tidak berkedip putih saat
    // app dibuka dalam tema gelap (mode pilihan user belum terbaca — DB baru
    // dibuka di _init).
    final dark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? QuestSchemes.dark() : QuestSchemes.light(),
      home: Scaffold(
        backgroundColor: (dark ? QuestPalette.dark : QuestPalette.light).bg,
      ),
    );
  }
}
