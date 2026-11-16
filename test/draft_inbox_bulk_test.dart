import 'package:catatim/capture/capture_channel.dart';
import 'package:catatim/capture/pipeline.dart';
import 'package:catatim/models.dart';
import 'package:catatim/rules/engine.dart';
import 'package:catatim/rules/rule_set.dart';
import 'package:catatim/storage/database.dart';
import 'package:catatim/storage/repository.dart';
import 'package:catatim/theme/quest.dart';
import 'package:catatim/ui/draft_inbox_sheet.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// POLA TEARDOWN: query/assert DB dulu, lalu unmount widget tree
// (membatalkan subscription stream), TERAKHIR db.close(). Query setelah
// close membuat test runner menggantung.
void main() {
  late AppDatabase db;
  late LedgerRepository repo;
  late CapturePipeline pipeline;

  RawCapture capture({required DateTime postedAt}) => RawCapture(
    packageName: 'id.bm.blu',
    title: 'blu',
    body: 'Kamu menerima transfer masuk Rp2.000.000 dari BUDI',
    postedAt: postedAt,
  );

  RuleSet bluRules() => RuleSet.fromJson({
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

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LedgerRepository(db);
    pipeline = CapturePipeline(
      channel: const CaptureChannel(),
      engine: RuleEngine(bluRules()),
      repository: repo,
    );
  });

  Widget host() => MaterialApp(
    theme: QuestSchemes.light(),
    home: Scaffold(
      body: DraftInboxView(
        repository: repo,
        pipeline: pipeline,
        ruleSet: bluRules(),
      ),
    ),
  );

  Future<void> seedTwoParsedOneUnparsed() async {
    await repo.addDraftFromCapture(
      raw: capture(postedAt: DateTime(2026, 11, 15, 9)),
      draft: const ParsedDraft(
        bankId: 'blu',
        bankName: 'blu by BCA',
        ruleName: 'transfer masuk',
        kind: TxKind.transfer,
        direction: Direction.incoming,
        amount: 50000,
        counterparty: 'BUDI',
      ),
    );
    await repo.addDraftFromCapture(
      raw: capture(postedAt: DateTime(2026, 11, 15, 10)),
      draft: const ParsedDraft(
        bankId: 'blu',
        bankName: 'blu by BCA',
        ruleName: 'qris',
        kind: TxKind.payment,
        direction: Direction.outgoing,
        amount: 35000,
        counterparty: 'Indomaret',
      ),
    );
    // Draf tanpa nominal — harus tetap di inbox.
    await repo.addDraftFromCapture(
      raw: capture(postedAt: DateTime(2026, 11, 15, 11)),
      draft: const ParsedDraft(
        bankId: 'blu',
        bankName: 'blu by BCA',
        ruleName: 'qris',
        kind: TxKind.payment,
        direction: Direction.outgoing,
        amount: 0,
        counterparty: 'Warung',
      ),
    );
  }

  Future<void> unmountAndClose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await db.close();
    });
  }

  testWidgets('terima semua: draf ber-nominal dicatat, kosong tertinggal', (
    tester,
  ) async {
    await tester.runAsync(seedTwoParsedOneUnparsed);
    await tester.pumpWidget(host());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terima Semua').first);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    // Dialog konfirmasi menyebut jumlah draf.
    expect(find.text('2 draf akan dicatat:'), findsOneWidget);
    expect(find.text('• blu by BCA — 2 draf'), findsOneWidget);
    expect(find.textContaining('1 draf belum ada nominalnya'), findsOneWidget);

    await tester.tap(find.text('Terima Semua').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    final txs = await tester.runAsync(() => db.select(db.transactions).get());
    expect(txs, hasLength(2));
    final draftsLeft = await tester.runAsync(() => db.select(db.drafts).get());
    expect(draftsLeft, hasLength(1));
    expect(draftsLeft!.single.amount, 0);
    await unmountAndClose(tester);
  });

  testWidgets('batal di dialog tidak mencatat apa pun', (tester) async {
    await tester.runAsync(seedTwoParsedOneUnparsed);
    await tester.pumpWidget(host());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terima Semua').first);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(await tester.runAsync(() => db.select(db.transactions).get()), isEmpty);
    expect(await tester.runAsync(() => db.select(db.drafts).get()), hasLength(3));
    await unmountAndClose(tester);
  });

  testWidgets('semua draf tanpa nominal: tombol hanya snack, tanpa dialog', (
    tester,
  ) async {
    await tester.runAsync(
      () => repo.addDraftFromCapture(
        raw: capture(postedAt: DateTime(2026, 11, 15, 9)),
        draft: const ParsedDraft(
          bankId: 'blu',
          bankName: 'blu by BCA',
          ruleName: 'qris',
          kind: TxKind.payment,
          direction: Direction.outgoing,
          amount: 0,
          counterparty: 'Warung',
        ),
      ),
    );
    await tester.pumpWidget(host());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terima Semua').first);
    await tester.pumpAndSettle();

    expect(find.text('Terima Semua Draf?'), findsNothing);
    expect(await tester.runAsync(() => db.select(db.transactions).get()), isEmpty);
    await unmountAndClose(tester);
  });

  testWidgets('pasangan transfer ikut diterima massal', (tester) async {
    final base = DateTime(2026, 11, 15, 12);
    await tester.runAsync(() async {
      await db
          .into(db.drafts)
          .insert(
            DraftsCompanion.insert(
              bankId: 'blu',
              kind: TxKind.withdrawal,
              direction: Direction.outgoing,
              amount: 100000,
              occurredAt: base,
              counterparty: const Value('Tarik Tunai'),
            ),
          );
      await db
          .into(db.drafts)
          .insert(
            DraftsCompanion.insert(
              bankId: 'gopay',
              kind: TxKind.topup,
              direction: Direction.incoming,
              amount: 100000,
              occurredAt: base.add(const Duration(seconds: 30)),
              counterparty: const Value('Top Up'),
            ),
          );
    });
    await tester.pumpWidget(host());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terima Semua').first);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(
      find.text('2 draf akan dicatat (termasuk 1 transfer antar akun):'),
      findsOneWidget,
    );
    await tester.tap(find.text('Terima Semua').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    final txs = await tester.runAsync(() => db.select(db.transactions).get());
    expect(txs, hasLength(2));
    expect(txs!.every((t) => t.kind == TxKind.internal), isTrue);
    await unmountAndClose(tester);
  });
}
