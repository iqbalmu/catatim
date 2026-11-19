import 'package:catatim/models.dart';
import 'package:catatim/notify/widget_channel.dart';
import 'package:catatim/notify/widget_sync_service.dart';
import 'package:catatim/storage/database.dart';
import 'package:catatim/storage/repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWidgetChannel extends WidgetChannel {
  ({
    String headline,
    String compactHeadline,
    String primaryAmount,
    String secondaryInfo,
    String draftChip,
    String streakBadge,
    int progressPercent,
    String progressLabel,
    bool hasProgress,
    String mood,
    bool isOver,
  })?
  lastUpdate;

  @override
  Future<void> updateWidget({
    required String headline,
    required String compactHeadline,
    required String primaryAmount,
    required String secondaryInfo,
    required String draftChip,
    required String streakBadge,
    required int progressPercent,
    required String progressLabel,
    required bool hasProgress,
    String mood = 'happy',
    bool isOver = false,
  }) async {
    lastUpdate = (
      headline: headline,
      compactHeadline: compactHeadline,
      primaryAmount: primaryAmount,
      secondaryInfo: secondaryInfo,
      draftChip: draftChip,
      streakBadge: streakBadge,
      progressPercent: progressPercent,
      progressLabel: progressLabel,
      hasProgress: hasProgress,
      mood: mood,
      isOver: isOver,
    );
  }
}

void main() {
  late AppDatabase db;
  late LedgerRepository repo;
  late _FakeWidgetChannel channel;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LedgerRepository(db);
    channel = _FakeWidgetChannel();
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'sync mengirim sisa jatah, progress bar, streak, chip draf, dan keluar hari ini',
    () async {
      final accounts = await repo.getAccounts();
      final cats = await repo.getCategories();
      final now = DateTime(2026, 11, 16, 12);

      await repo.addManual(
        amount: 35000,
        direction: Direction.outgoing,
        kind: TxKind.payment,
        counterparty: 'Makan',
        accountId: accounts.first.id,
        categoryId: cats.first.id,
        occurredAt: now,
      );

      await repo.addDraftFromCapture(
        raw: RawCapture(
          packageName: 'id.bm.blu',
          title: 'blu',
          body: 'QRIS Rp15.000',
          postedAt: now,
        ),
        draft: const ParsedDraft(
          bankId: 'blu',
          bankName: 'blu',
          ruleName: 'qris',
          kind: TxKind.payment,
          direction: Direction.outgoing,
          amount: 15000,
        ),
      );

      final sync = WidgetSyncService(
        repository: repo,
        channel: channel,
        now: () => now,
      );
      await sync.sync(
        safeToSpend: 65000,
        moodLine: 'Masih aman',
        mood: 'celebrate',
        streakDays: 3,
      );

      expect(channel.lastUpdate, isNotNull);
      expect(channel.lastUpdate!.primaryAmount, 'Rp65.000');
      expect(channel.lastUpdate!.streakBadge, '🔥 3');
      expect(channel.lastUpdate!.headline, 'Masih aman');
      expect(channel.lastUpdate!.compactHeadline, 'Keluar Rp35.000');
      expect(channel.lastUpdate!.secondaryInfo, 'Keluar Rp35.000');
      expect(channel.lastUpdate!.draftChip, '1 draf');
      expect(channel.lastUpdate!.hasProgress, isTrue);
      expect(channel.lastUpdate!.progressPercent, 35);
      expect(channel.lastUpdate!.mood, 'celebrate');
      expect(channel.lastUpdate!.isOver, isFalse);
    },
  );
}
