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

  test('bank terhubung yang tak terparse masuk log untuk dibaca ulang', () async {
    await repo.setBankConnected('blu', true);
    await started([
      RawCapture(
        packageName: 'com.blu.app',
        title: 'Blu',
        body: 'Blu: ada info penting tentang akunmu',
        postedAt: DateTime(2026, 10, 10, 9),
      ),
    ]);

    expect(await db.select(db.drafts).get(), isEmpty);
    final logs = await db.select(db.captureLogs).get();
    expect(logs, hasLength(1));
    expect(logs.first.parsed, isFalse);
  });

  test('notifikasi ganda bank terhubung hanya jadi satu draf', () async {
    await repo.setBankConnected('blu', true);
    final raw = _blu();
    await started([raw, _blu(at: raw.postedAt.add(const Duration(seconds: 30)))]);

    expect(await db.select(db.drafts).get(), hasLength(1));
  });
}
