import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bukuduit/capture/capture_channel.dart';
import 'package:bukuduit/capture/pipeline.dart';
import 'package:bukuduit/models.dart';
import 'package:bukuduit/rules/engine.dart';
import 'package:bukuduit/rules/rule_set.dart';
import 'package:bukuduit/storage/database.dart';
import 'package:bukuduit/storage/repository.dart';

/// Channel palsu: drain mengosongkan antrean seperti implementasi native.
class _FakeChannel extends CaptureChannel {
  _FakeChannel(this.items);

  List<RawCapture> items;
  final allowedPushes = <Set<String>>[];
  final learnedPackages = <String>[];
  List<RawCapture> activeItems = [];

  @override
  Future<List<RawCapture>> getActiveNotifications() async => activeItems;

  @override
  Future<void> setAllowedPackages(Set<String> packages) async {
    allowedPushes.add(packages);
  }

  @override
  Future<void> learnBankPackage(String packageName) async {
    learnedPackages.add(packageName);
  }

  @override
  Future<List<RawCapture>> drainQueue() async {
    final drained = List<RawCapture>.of(items);
    items = const [];
    return drained;
  }

  @override
  Stream<RawCapture> stream() => Stream.fromIterable(items);
}

Map<String, dynamic> _bank(String id, String name) => {
  'id': id,
  'displayName': name,
  'packageNames': ['com.$id.app'],
  'keywords': [name.toLowerCase()],
  'templates': [
    {
      'name': 'transfer masuk',
      'kind': 'transfer',
      'direction': 'in',
      'matchAll': ['transfer masuk'],
    },
  ],
};

RuleSet _rules() => RuleSet.fromJson({
  'version': 1,
  'banks': [_bank('blu', 'Blu'), _bank('gopay', 'GoPay')],
});

RawCapture _blu({DateTime? at}) => RawCapture(
  packageName: 'com.blu.app',
  title: 'Blu',
  body: 'Kamu menerima transfer masuk Rp2.000.000 dari BUDI',
  postedAt: at ?? DateTime(2026, 10, 10, 9),
);

void main() {
  late AppDatabase db;
  late LedgerRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LedgerRepository(db);
  });

  tearDown(() async => db.close());

  Future<CapturePipeline> started(List<RawCapture> items) async {
    final pipeline = CapturePipeline(
      channel: _FakeChannel(items),
      engine: RuleEngine(_rules()),
      repository: repo,
    );
    await pipeline.start();
    // Beri kesempatan stream async diproses.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return pipeline;
  }

  test('notifikasi bank terhubung menjadi draf', () async {
    await repo.setBankConnected('blu', true);
    await started([_blu()]);

    final drafts = await db.select(db.drafts).get();
    expect(drafts, hasLength(1));
    expect(drafts.first.bankId, 'blu');
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  test('start mendorong allowlist paket bank terhubung ke native', () async {
    await repo.setBankConnected('blu', true);
    await repo.setBankConnected('gopay', true);
    final channel = _FakeChannel(const []);
    final pipeline = CapturePipeline(
      channel: channel,
      engine: RuleEngine(_rules()),
      repository: repo,
    );
    await pipeline.start();

    expect(channel.allowedPushes, [
      {'com.blu.app', 'com.gopay.app'},
    ]);
  });

  test('bank cocok keyword tapi paket asing: paket dipelajari', () async {
    await repo.setBankConnected('gopay', true);
    final channel = _FakeChannel([
      RawCapture(
        packageName: 'com.strike.app',
        title: 'GoPay',
        body: 'Kamu menerima transfer masuk Rp5.000 dari SARI',
        postedAt: DateTime(2026, 10, 10, 9),
      ),
    ]);
    final pipeline = CapturePipeline(
      channel: channel,
      engine: RuleEngine(_rules()),
      repository: repo,
    );
    await pipeline.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final drafts = await db.select(db.drafts).get();
    expect(drafts, hasLength(1));
    expect(drafts.first.bankId, 'gopay');
    expect(channel.learnedPackages, ['com.strike.app']);
  });

  test('notifikasi bank yang belum terhubung diabaikan diam-diam', () async {
    await started([_blu()]);

    expect(await db.select(db.drafts).get(), isEmpty);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.captureLogs).get(), isEmpty);
  });

  test('notifikasi bukan bank dikenal diabaikan diam-diam', () async {
    await repo.setBankConnected('blu', true);
    await started([
      RawCapture(
        packageName: 'com.whatsapp',
        title: 'Grup RT',
        body: 'Rapat jam 7 malam ini ya',
        postedAt: DateTime(2026, 10, 10, 9),
      ),
    ]);

    expect(await db.select(db.drafts).get(), isEmpty);
    expect(await db.select(db.captureLogs).get(), isEmpty);
  });

  test(
    'bank terhubung yang tak terparse jadi draf mentah (mode belajar)',
    () async {
      // Perilaku mode belajar: format belum dikenal TETAP jadi draf yang
      // menunggu keputusan user — bukan sekadar log "belum terbaca".
      await repo.setBankConnected('blu', true);
      await started([
        RawCapture(
          packageName: 'com.blu.app',
          title: 'Blu',
          body: 'Blu: ada info penting tentang akunmu',
          postedAt: DateTime(2026, 10, 10, 9),
        ),
      ]);

      final drafts = await db.select(db.drafts).get();
      expect(drafts, hasLength(1));
      expect(drafts.first.bankId, 'blu');
      expect(drafts.first.amount, 0); // tanpa nominal → user isi
    },
  );

  test(
    'mode belajar: app custom apa pun jadi draf dengan tebakan nominal',
    () async {
      await repo.setCustomBankConnected('com.strike.app', 'Strike', true);
      await started([
        RawCapture(
          packageName: 'com.strike.app',
          title: 'Strike',
          body: 'Pembayaran berhasil Rp75.000 di KOPI KENANGAN',
          postedAt: DateTime(2026, 10, 10, 9),
        ),
      ]);

      final drafts = await db.select(db.drafts).get();
      expect(drafts, hasLength(1));
      expect(drafts.first.bankId, 'app:com.strike.app');
      expect(drafts.first.amount, 75000); // tebakan pola umum
      expect(drafts.first.direction, Direction.outgoing); // kata "pembayaran"
    },
  );

  test('draf mentah tanpa nominal tidak saling menelan', () async {
    await repo.setCustomBankConnected('com.strike.app', 'Strike', true);
    final base = DateTime(2026, 10, 10, 9);
    await started([
      RawCapture(
        packageName: 'com.strike.app',
        title: 'Strike',
        body: 'Transaksi A tanpa angka',
        postedAt: base,
      ),
      RawCapture(
        packageName: 'com.strike.app',
        title: 'Strike',
        body: 'Transaksi A tanpa angka', // identik → dedup
        postedAt: base.add(const Duration(seconds: 30)),
      ),
      RawCapture(
        packageName: 'com.strike.app',
        title: 'Strike',
        body: 'Transaksi B lain tanpa angka',
        postedAt: base.add(const Duration(seconds: 60)),
      ),
    ]);

    final drafts = await db.select(db.drafts).get();
    expect(drafts, hasLength(2)); // A sekali + B
    expect(drafts.every((d) => d.amount == 0), isTrue);
  });

  test('notifikasi ganda bank terhubung hanya jadi satu draf', () async {
    await repo.setBankConnected('blu', true);
    final raw = _blu();
    await started([
      raw,
      _blu(at: raw.postedAt.add(const Duration(seconds: 30))),
    ]);

    expect(await db.select(db.drafts).get(), hasLength(1));
    // Duplikat yang digugurkan tetap terlihat sebagai log ignored_dup.
    final logs = await db.select(db.captureLogs).get();
    expect(logs, hasLength(1));
    expect(logs.first.ignoredDup, isTrue);
    expect(logs.first.parsed, isTrue);
  });

  test('baris antrean korup dilewati tanpa membuang sisanya', () async {
    final good = encodeCaptureLine(_blu());
    final parsed = parseCaptureLines(['{{{bukan json', good, '']);
    expect(parsed, hasLength(1));
    expect(parsed.single.body, _blu().body);
    expect(tryParseCaptureLine('{"packageName":'), isNull);
  });

  test('submitPastedText: format dikenal menjadi draf terisi penuh', () async {
    final pipeline = CapturePipeline(
      channel: _FakeChannel([]),
      engine: RuleEngine(_rules()),
      repository: repo,
    );
    final ok = await pipeline.submitPastedText(
      'Blu\nKamu menerima transfer masuk Rp350.000 dari SITI',
    );
    expect(ok, isTrue);
    final drafts = await db.select(db.drafts).get();
    expect(drafts, hasLength(1));
    expect(drafts.single.bankId, 'blu');
    expect(drafts.single.amount, 350000);
    expect(drafts.single.direction, Direction.incoming);
  });

  test(
    'submitPastedText: format tak dikenal menjadi draf mentah dengan tebakan',
    () async {
      final pipeline = CapturePipeline(
        channel: _FakeChannel([]),
        engine: RuleEngine(_rules()),
        repository: repo,
      );
      final ok = await pipeline.submitPastedText(
        'Pembayaran QRIS sebesar Rp45.000 di Kopi Kenangan berhasil',
      );
      expect(ok, isTrue);
      final drafts = await db.select(db.drafts).get();
      expect(drafts, hasLength(1));
      expect(drafts.single.bankId, 'paste');
      expect(drafts.single.amount, 45000);
      expect(drafts.single.direction, Direction.outgoing);
    },
  );

  test(
    'pullActiveNotifications: menarik notifikasi aktif menjadi draf',
    () async {
      await repo.setBankConnected('blu', true);
      final channel = _FakeChannel([]);
      channel.activeItems = [_blu()];
      final pipeline = CapturePipeline(
        channel: channel,
        engine: RuleEngine(_rules()),
        repository: repo,
      );
      await pipeline.start();

      final count = await pipeline.pullActiveNotifications();
      expect(count, 1);
      final drafts = await db.select(db.drafts).get();
      expect(drafts, hasLength(1));
      expect(drafts.single.amount, 2000000);
    },
  );
}
