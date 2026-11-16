import 'package:catatim/models.dart';
import 'package:catatim/notify/notify_channel.dart';
import 'package:catatim/notify/reminder_scheduler.dart';
import 'package:catatim/storage/database.dart';
import 'package:catatim/storage/repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNotifyChannel extends NotifyChannel {
  final List<({int id, DateTime at, String title, String body})> scheduled = [];
  final List<int> cancelled = [];

  @override
  Future<void> scheduleNotification({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
  }) async {
    scheduled.add((id: id, at: scheduledAt, title: title, body: body));
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelled.add(id);
  }
}

void main() {
  late AppDatabase db;
  late LedgerRepository repo;
  late _FakeNotifyChannel channel;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LedgerRepository(db);
    channel = _FakeNotifyChannel();
  });

  tearDown(() async {
    await db.close();
  });

  test('pengingat harian nonaktif membatalkan jadwal', () async {
    await repo.setDailyReminderEnabled(false);
    final scheduler = ReminderScheduler(
      repository: repo,
      channel: channel,
      now: () => DateTime(2026, 11, 16, 10),
    );
    await scheduler.sync();

    expect(channel.cancelled, contains(ReminderScheduler.dailyReminderId));
    expect(channel.scheduled, isEmpty);
  });

  test('pengingat harian aktif menjadwalkan hari ini jika belum lewat', () async {
    await repo.setDailyReminderEnabled(true);
    await repo.setDailyReminderMinutes(20 * 60);
    final scheduler = ReminderScheduler(
      repository: repo,
      channel: channel,
      now: () => DateTime(2026, 11, 16, 10),
    );
    await scheduler.sync();

    expect(channel.scheduled, hasLength(1));
    expect(channel.scheduled.single.id, ReminderScheduler.dailyReminderId);
    expect(channel.scheduled.single.at, DateTime(2026, 11, 16, 20));
  });

  test('pengingat harian aktif menggeser ke besok jika jam sudah lewat', () async {
    await repo.setDailyReminderEnabled(true);
    await repo.setDailyReminderMinutes(20 * 60);
    final scheduler = ReminderScheduler(
      repository: repo,
      channel: channel,
      now: () => DateTime(2026, 11, 16, 21),
    );
    await scheduler.sync();

    expect(channel.scheduled, hasLength(1));
    expect(channel.scheduled.single.at, DateTime(2026, 11, 17, 20));
  });

  test('bon jatuh tempo menjadwalkan H-1 pukul 09:00 dan batal saat lunas', () async {
    final bonId = await repo.addBon(
      person: 'Andi',
      amount: 150000,
      direction: BonDirection.lent,
      dueDate: DateTime(2026, 11, 20),
    );
    final scheduler = ReminderScheduler(
      repository: repo,
      channel: channel,
      now: () => DateTime(2026, 11, 16, 10),
    );
    await scheduler.sync();

    expect(channel.scheduled, hasLength(1));
    expect(
      channel.scheduled.single.id,
      ReminderScheduler.bonReminderIdBase + bonId,
    );
    expect(channel.scheduled.single.at, DateTime(2026, 11, 19, 9));
    expect(channel.scheduled.single.title, 'Besok jatuh tempo: Andi');

    // Tandai lunas → sync membatalkan alarm bon.
    final accounts = await repo.getAccounts();
    final cats = await repo.getCategories();
    await repo.settleBon(
      bonId: bonId,
      amount: 150000,
      accountId: accounts.first.id,
      categoryId: cats.first.id,
    );
    channel.scheduled.clear();
    channel.cancelled.clear();

    await scheduler.sync();
    expect(channel.scheduled, isEmpty);
    expect(
      channel.cancelled,
      contains(ReminderScheduler.bonReminderIdBase + bonId),
    );
  });
}
