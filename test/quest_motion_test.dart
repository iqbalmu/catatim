import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bukuduit/capture/capture_channel.dart';
import 'package:bukuduit/capture/pipeline.dart';
import 'package:bukuduit/game/progress.dart';
import 'package:bukuduit/models.dart';
import 'package:bukuduit/rules/engine.dart';
import 'package:bukuduit/rules/rule_set.dart';
import 'package:bukuduit/storage/database.dart';
import 'package:bukuduit/storage/repository.dart';
import 'package:bukuduit/theme/quest.dart';
import 'package:bukuduit/ui/home_cards.dart';
import 'package:bukuduit/ui/home_screen.dart';
import 'package:bukuduit/ui/quest.dart';

/// Animasi tipis permukaan Beranda: toggle saldo & banner draf. Dipagari
/// agar regenerasi UI tidak menghilangkan umpan balik visual secara diam-diam.
///
/// Konvensi testWidgets + drift (lihat `laporan_layout_test`): stream butuh
/// napas via `tester.runAsync`, dan db wajib ditutup DI DALAM body test —
/// timer NativeDatabase yang hidup melewati akhir test memicu
/// "A Timer is still pending".
void main() {
  testWidgets('toggle saldo: angka → bulat dengan crossfade, tanpa error', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      MaterialApp(
        theme: QuestSchemes.light(),
        home: Scaffold(
          body: TotalBalanceCard(
            repository: repo,
            pipeline: pipeline,
            ruleSet: ruleSet,
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pumpAndSettle();

    // Awal: saldo terlihat, belum tersembunyi.
    expect(find.text('••••••••'), findsNothing);

    await tester.tap(find.byType(IconButton));
    await tester.pump(); // tengah transisi: anak baru sudah masuk pohon.
    expect(find.text('••••••••'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('••••••••'), findsOneWidget);
    expect(find.text('Saldo disembunyikan'), findsOneWidget);
    // Chip akun ikut tersembunyi.
    expect(find.text('••••••'), findsWidgets);
    expect(tester.takeException(), isNull);

    // Toggle balik → angka kembali.
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.text('••••••••'), findsNothing);
    expect(tester.takeException(), isNull);

    await db.close();
  });

  testWidgets('banner draf: muncul & runtuh dengan animasi, tanpa error', (
    tester,
  ) async {
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

    Future<void> breathe() => tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );

    await tester.pumpWidget(
      MaterialApp(
        theme: QuestSchemes.light(),
        home: Scaffold(
          body: DraftAttentionBanner(
            repository: repo,
            ruleSet: ruleSet,
            progress: progress,
            pipeline: pipeline,
            onOpenAnggaran: () {},
            onOpenBon: () {},
          ),
        ),
      ),
    );
    await breathe();
    await tester.pumpAndSettle();

    // Tanpa draf: banner kolaps, tidak ada error layout.
    expect(find.text('Transaksi Bank Terdeteksi'), findsNothing);
    expect(tester.takeException(), isNull);

    // Draf masuk → banner tampil.
    await tester.runAsync(() async {
      await repo.addDraftFromCapture(
        raw: RawCapture(
          packageName: 'id.bm.blu',
          title: 'blu',
          body: 'Transfer masuk Rp50.000 dari BUDI',
          postedAt: DateTime(2026, 10, 31, 9),
        ),
        draft: ParsedDraft(
          bankId: 'blu',
          bankName: 'blu by BCA',
          ruleName: 'transfer masuk',
          kind: TxKind.transfer,
          direction: Direction.incoming,
          amount: 50000,
          counterparty: 'BUDI',
        ),
      );
    });
    await breathe();
    await tester.pumpAndSettle();
    expect(find.text('Transaksi Bank Terdeteksi'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Semua draf dibuang → banner runtuh dengan AnimatedSize.
    await tester.runAsync(() async {
      final drafts = await db.select(db.drafts).get();
      for (final d in drafts) {
        await repo.discardDraft(d.id);
      }
    });
    await breathe();
    await tester.pumpAndSettle();
    expect(find.text('Transaksi Bank Terdeteksi'), findsNothing);
    expect(tester.takeException(), isNull);

    await db.close();
  });

  testWidgets('QuestEnter: konten menetas setelah slide, penuh saat selesai', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: QuestSchemes.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      body: ListView(
                        children: const [
                          QuestEnter(index: 0, child: Text('Konten A')),
                          QuestEnter(index: 2, child: Text('Konten B')),
                        ],
                      ),
                    ),
                  ),
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pump(); // transisi push dimulai
    await tester.pump(const Duration(milliseconds: 100)); // slide tengah jalan

    // Konten masih menetas — belum terlihat penuh.
    final fading = tester.widget<FadeTransition>(
      find.byType(FadeTransition).first,
    );
    expect(fading.opacity.value, lessThan(1.0));

    await tester.pumpAndSettle();
    expect(find.text('Konten A'), findsOneWidget);
    expect(find.text('Konten B'), findsOneWidget);
    final settled = tester.widget<FadeTransition>(
      find.byType(FadeTransition).first,
    );
    expect(settled.opacity.value, 1.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QuestProgressBar: tumbuh dari nol ke nilai akhir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: QuestSchemes.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 200,
            child: QuestProgressBar(value: 1, color: Color(0xFF112233)),
          ),
        ),
      ),
    );
    await tester.pump(); // frame pertama: masih di awal pertumbuhan

    final early = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(early.widthFactor!, lessThan(1.0));

    await tester.pumpAndSettle();
    final grown = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(grown.widthFactor, 1.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QuestProgressBar tumbuh ulang tiap token panggung naik', (
    tester,
  ) async {
    var token = 0;
    late void Function(void Function()) setOuter;
    await tester.pumpWidget(
      MaterialApp(
        theme: QuestSchemes.light(),
        home: StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return Scaffold(
              body: QuestStage(
                token: token,
                child: const SizedBox(
                  width: 200,
                  child: QuestProgressBar(value: 1, color: Color(0xFF112233)),
                ),
              ),
            );
          },
        ),
      ),
    );

    double factor() => tester
        .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .widthFactor!;

    await tester.pump(); // mount: mulai tumbuh
    expect(factor(), lessThan(1.0));
    await tester.pumpAndSettle();
    expect(factor(), 1.0);

    setOuter(() => token++); // ganti tab
    await tester.pump();
    expect(factor(), lessThan(1.0)); // tumbuh lagi dari nol
    await tester.pumpAndSettle();
    expect(factor(), 1.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QuestTabEnter menetas tiap token panggung naik', (
    tester,
  ) async {
    var token = 0;
    late void Function(void Function()) setOuter;
    await tester.pumpWidget(
      MaterialApp(
        theme: QuestSchemes.light(),
        home: StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return Scaffold(
              backgroundColor: Colors.white,
              body: QuestStage(
                token: token,
                child: const QuestTabEnter(child: Text('Isi tab')),
              ),
            );
          },
        ),
      ),
    );

    double opacity() => tester.widget<Opacity>(find.byType(Opacity)).opacity;

    await tester.pump();
    expect(opacity(), lessThan(1.0)); // menetas, belum penuh
    await tester.pumpAndSettle();
    expect(opacity(), 1.0);

    setOuter(() => token++); // ganti tab → menetas lagi
    await tester.pump();
    expect(opacity(), lessThan(1.0));
    await tester.pumpAndSettle();
    expect(opacity(), 1.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mirror shell: IndexedStack + ganti tab memutar ulang semua', (
    tester,
  ) async {
    // Mereplikasi struktur shell asli: QuestStage di atas IndexedStack,
    // semua tab dibangun sejak awal, token naik tiap ganti tab.
    var tab = 0;
    var token = 0;
    late void Function(void Function()) setOuter;
    await tester.pumpWidget(
      MaterialApp(
        theme: QuestSchemes.light(),
        home: StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return Scaffold(
              body: QuestStage(
                token: token,
                child: IndexedStack(
                  index: tab,
                  children: const [
                    Text('Beranda'),
                    SizedBox(
                      width: 200,
                      child: QuestProgressBar(
                        value: 1,
                        color: Color(0xFF112233),
                      ),
                    ),
                    QuestTabEnter(index: 1, child: Text('Laporan')),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    double factor() => tester
        .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .widthFactor!;
    double opacity() => tester.widget<Opacity>(find.byType(Opacity)).opacity;

    // Buka tab Anggaran (bar) — seperti _onTabChanged: tab + token.
    setOuter(() {
      tab = 1;
      token++;
    });
    await tester.pump();
    expect(factor(), lessThan(1.0)); // bar tumbuh DI ATAS panggung
    await tester.pumpAndSettle();
    expect(factor(), 1.0);

    // Pulang ke Beranda lalu buka Laporan → baris menetas + bar tumbuh lagi.
    setOuter(() {
      tab = 0;
      token++;
    });
    await tester.pumpAndSettle();
    setOuter(() {
      tab = 2;
      token++;
    });
    await tester.pump();
    expect(opacity(), lessThan(1.0));
    await tester.pumpAndSettle();
    expect(opacity(), 1.0);

    setOuter(() {
      tab = 1;
      token++;
    });
    await tester.pump();
    expect(factor(), lessThan(1.0)); // replay di kunjungan berikutnya
    await tester.pumpAndSettle();
    expect(factor(), 1.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'QuestTabEnter: komponen muncul satu-satu berurutan tanpa mereset State anak',
    (tester) async {
      var token = 0;
      late void Function(void Function()) setOuter;
      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          home: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return Scaffold(
                body: QuestStage(
                  token: token,
                  child: Column(
                    children: const [
                      QuestTabEnter(index: 0, child: _StatefulProbe('Item 0')),
                      QuestTabEnter(index: 2, child: Text('Item 2')),
                      QuestTabEnter(index: 4, child: Text('Item 4')),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Di tengah animasi (160ms): Item 0 sudah sebagian tampil, Item 2 baru mulai,
      // Item 4 masih menunggu (opacity 0) — membuktikan tampil satu-per-satu.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      final opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .toList();
      expect(opacities[0], greaterThan(0.3));
      expect(opacities[0], greaterThan(opacities[1]));
      expect(opacities[2], equals(0.0));

      await tester.pumpAndSettle();
      expect(find.text('Item 0: 0'), findsOneWidget);

      // Ubah state anak, lalu naikkan token panggung → animasi berputar ulang
      // tanpa menghancurkan State anak.
      await tester.tap(find.text('Item 0: 0'));
      await tester.pump();
      expect(find.text('Item 0: 1'), findsOneWidget);

      setOuter(() => token++);
      await tester.pump();
      final replayFirst = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .first
          .opacity;
      expect(replayFirst, equals(0.0));
      expect(find.text('Item 0: 1'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Item 0: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'QuestBar di dalam QuestTabEnter: baru tumbuh dari 0 setelah kartu mulai tampil',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          home: const Scaffold(
            body: SizedBox(
              width: 240,
              child: QuestTabEnter(
                index: 2,
                child: QuestBar(value: 0.75, height: 10),
              ),
            ),
          ),
        ),
      );

      double barFactor() => tester
          .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor!;

      // Saat kartu index 2 belum muncul (100ms), bar masih 0 (belum curi start).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(barFactor(), equals(0.0));

      // Saat kartu sudah tampil di layar (420ms), bar terlihat sedang tumbuh (0 < v < 0.75).
      await tester.pump(const Duration(milliseconds: 320));
      expect(barFactor(), greaterThan(0.05));
      expect(barFactor(), lessThan(0.75));

      await tester.pumpAndSettle();
      expect(barFactor(), closeTo(0.75, 0.0001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'HomeScreen: pindah tab tanpa slide samping, komponen muncul bertahap',
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
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Pindah dari Beranda ke Bon via bottom nav.
      await tester.tap(find.text('Bon'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // Posisi horizontal judul 'PIUTANG' tidak bergeser dari samping:
      // sama persis antara saat baru masuk (60ms) dan saat animasi selesai.
      final earlyX = tester.getTopLeft(find.text('PIUTANG')).dx;

      // Di tengah animasi, kartu masih menetas (opacity < 1.0).
      final cardOpacity = tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.text('PIUTANG'),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(cardOpacity, lessThan(1.0));

      await tester.pumpAndSettle();
      final settledX = tester.getTopLeft(find.text('PIUTANG')).dx;
      expect(earlyX, equals(settledX));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await db.close();
      });
    },
  );

  testWidgets(
    'QuestMoney: nilai nominal meningkat dari 0 ke target dan berputar ulang tiap ganti tab',
    (tester) async {
      var token = 0;
      var amount = 1500000;
      late void Function(void Function()) setOuter;

      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          home: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return Scaffold(
                body: QuestStage(
                  token: token,
                  child: QuestMoney(amount: amount),
                ),
              );
            },
          ),
        ),
      );

      // Awal animasi: masih Rp0, belum langsung nilai akhir.
      await tester.pump();
      expect(find.text('Rp0'), findsOneWidget);
      expect(find.text('Rp1.500.000'), findsNothing);

      // Di tengah animasi: nilai sedang meningkat di antara 0 dan 1.500.000.
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.text('Rp0'), findsNothing);
      expect(find.text('Rp1.500.000'), findsNothing);

      // Selesai: tepat di nominal akhir.
      await tester.pumpAndSettle();
      expect(find.text('Rp1.500.000'), findsOneWidget);

      // Ganti tab (token naik) → menghitung ulang dari Rp0.
      setOuter(() => token++);
      await tester.pump();
      expect(find.text('Rp0'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Rp1.500.000'), findsOneWidget);

      // Perubahan nilai live → meluncur dari 1.500.000 ke 2.000.000 (bukan reset ke Rp0).
      setOuter(() => amount = 2000000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('Rp0'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Rp2.000.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TotalBalanceCard show/hide: efek frosted blur aktif saat transisi dan bersih saat diam',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LedgerRepository(db);
      await tester.runAsync(() async {
        final acc = await repo.addAccount('BCA Utama', AccountKind.bank);
        await repo.setOpeningBalance(acc.id, 2500000);
      });
      final ruleSet = RuleSet.fromJson({'version': 1, 'banks': []});
      final pipeline = CapturePipeline(
        channel: const CaptureChannel(),
        engine: RuleEngine(ruleSet),
        repository: repo,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          home: Scaffold(
            body: TotalBalanceCard(
              repository: repo,
              pipeline: pipeline,
              ruleSet: ruleSet,
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();

      // Saat diam: tanpa layer ImageFiltered aktif, nominal penuh tampil.
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.text('Rp2.500.000'), findsWidgets);

      // Tap sembunyikan → tengah transisi efek blur aktif.
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(ImageFiltered), findsWidgets);

      // Selesai sembunyi → layer blur dilepas, ikon kunci & teks tampil.
      await tester.pumpAndSettle();
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.text('••••••••'), findsOneWidget);

      // Tap tampilkan kembali → nominal menghitung naik dari Rp0 ke Rp2.500.000.
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(find.text('Rp0'), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.text('Rp2.500.000'), findsWidgets);
      expect(find.byType(ImageFiltered), findsNothing);
      expect(tester.takeException(), isNull);

      await db.close();
    },
  );
}

class _StatefulProbe extends StatefulWidget {
  const _StatefulProbe(this.label);
  final String label;

  @override
  State<_StatefulProbe> createState() => _StatefulProbeState();
}

class _StatefulProbeState extends State<_StatefulProbe> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _count++),
      child: Text('${widget.label}: $_count'),
    );
  }
}
