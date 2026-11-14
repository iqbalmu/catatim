import 'package:flutter_test/flutter_test.dart';
import 'package:catatim/core/budget.dart';
import 'package:catatim/core/budget_alert.dart';

void main() {
  group('budgetAlertPeriodKey', () {
    test('harian memakai tanggal, bulanan memakai bulan', () {
      final key = budgetAlertPeriodKey(
        LimitScope.daily,
        DateTime(2026, 11, 13, 9, 41),
      );
      expect(key, 'd2026-11-13');
      expect(
        budgetAlertPeriodKey(LimitScope.monthly, DateTime(2026, 11, 13)),
        'm2026-11',
      );
    });

    test('mingguan memakai Senin, walau lintas bulan/tahun', () {
      // Kamis 2 Juli 2026 → Seninnya 29 Juni (bulan sebelumnya).
      expect(
        budgetAlertPeriodKey(LimitScope.weekly, DateTime(2026, 7, 2)),
        'w2026-06-29',
      );
      // Rabu 1 Januari 2025 → Seninnya 30 Desember 2024.
      expect(
        budgetAlertPeriodKey(LimitScope.weekly, DateTime(2025)),
        'w2024-12-30',
      );
    });
  });

  ({int used, int? limit, String? note}) line(
    int used, {
    int? limit,
    String? note,
  }) => (used: used, limit: limit, note: note);

  group('planBudgetAlerts', () {
    final now = DateTime(2026, 11, 13, 10);

    test('menembak sekali saat pertama menyentuh ambang, lalu diam', () {
      final first = planBudgetAlerts(
        lines: {LimitScope.daily: line(820, limit: 1000)},
        thresholdPercent: 80,
        state: const {},
        now: now,
      );
      expect(first.hits, hasLength(1));
      expect(first.hits.single.scope, LimitScope.daily);
      expect(first.hits.single.percent, 82);
      expect(first.hits.single.over, isFalse);
      expect(first.newState['daily#warn'], 'd2026-11-13');

      final again = planBudgetAlerts(
        lines: {LimitScope.daily: line(900, limit: 1000)},
        thresholdPercent: 80,
        state: first.newState,
        now: now,
      );
      expect(again.hits, isEmpty);
      // State tidak berubah (map baru, isi identik).
      expect(again.newState, first.newState);
    });

    test('over menembak dengan key terpisah dari warn', () {
      var state = planBudgetAlerts(
        lines: {LimitScope.daily: line(850, limit: 1000)},
        thresholdPercent: 80,
        state: const {},
        now: now,
      ).newState;

      // Lewat batas → tetap menembak (warn sudah kirim periode ini).
      state = planBudgetAlerts(
        lines: {LimitScope.daily: line(1200, limit: 1000)},
        thresholdPercent: 80,
        state: state,
        now: now,
      ).newState;

      final hit = state['daily#over'];
      expect(hit, 'd2026-11-13');

      // Over yang sama tidak kirim ulang di periode yang sama.
      final plan = planBudgetAlerts(
        lines: {LimitScope.daily: line(1500, limit: 1000)},
        thresholdPercent: 80,
        state: state,
        now: now,
      );
      expect(plan.hits, isEmpty);
    });

    test('threshold 100 hanya menembak sebagai over, bukan dobel', () {
      final plan = planBudgetAlerts(
        lines: {LimitScope.daily: line(1000, limit: 1000)},
        thresholdPercent: 100,
        state: const {},
        now: now,
      );
      expect(plan.hits, hasLength(1));
      expect(plan.hits.single.over, isTrue);
    });

    test('ganti periode menembak lagi sekali', () {
      final state = planBudgetAlerts(
        lines: {LimitScope.daily: line(900, limit: 1000)},
        thresholdPercent: 80,
        state: const {},
        now: now,
      ).newState;

      final besok = planBudgetAlerts(
        lines: {LimitScope.daily: line(100, limit: 1000)},
        thresholdPercent: 80,
        state: state,
        now: DateTime(2026, 11, 14, 8),
      );
      expect(besok.hits, isEmpty); // 10% — belum sentuh ambang.

      final besokOver = planBudgetAlerts(
        lines: {LimitScope.daily: line(950, limit: 1000)},
        thresholdPercent: 80,
        state: state,
        now: DateTime(2026, 11, 14, 8),
      );
      expect(besokOver.hits, hasLength(1));
      expect(besokOver.newState['daily#warn'], 'd2026-11-14');
    });

    test('tanpa batas atau limit nol/negatif selalu dilewati', () {
      final plan = planBudgetAlerts(
        lines: {
          LimitScope.daily: line(1000),
          LimitScope.weekly: line(9999, limit: 0),
          LimitScope.monthly: line(50, limit: -100),
        },
        thresholdPercent: 80,
        state: const {},
        now: now,
      );
      expect(plan.hits, isEmpty);
      expect(plan.newState, isEmpty);
    });

    test('satu event banyak scope, terurut harian→mingguan→bulanan', () {
      final plan = planBudgetAlerts(
        lines: {
          LimitScope.monthly: line(8100, limit: 10000),
          LimitScope.daily: line(95, limit: 100),
          LimitScope.weekly: line(50, limit: 100),
        },
        thresholdPercent: 80,
        state: const {},
        now: now,
      );
      expect(plan.hits.map((h) => h.scope).toList(), [
        LimitScope.daily,
        LimitScope.monthly,
      ]);
      // State lengkap disimpan, termasuk scope yang tidak menembak
      // (tetap apa adanya dari state lama).
      expect(plan.newState, hasLength(2));
    });
  });

  group('budgetAlertMessage', () {
    test('null tanpa hit', () {
      expect(budgetAlertMessage(const [], thresholdPercent: 80), isNull);
    });

    test('satu garis: judul spesifik + isi nominal dan sisa', () {
      final msg = budgetAlertMessage(const [
        BudgetAlertHit(
          scope: LimitScope.daily,
          used: 82_000,
          limit: 100_000,
          percent: 82,
          over: false,
        ),
      ], thresholdPercent: 80);
      expect(msg!.title, 'Batas Harian: 80% terpakai');
      expect(msg.body, 'Harian: Rp82.000 dari Rp100.000 — sisa Rp18.000');
    });

    test('garis over: judul berbeda + penanda lewat', () {
      final msg = budgetAlertMessage(const [
        BudgetAlertHit(
          scope: LimitScope.weekly,
          used: 1_200_000,
          limit: 1_000_000,
          percent: 120,
          over: true,
        ),
      ], thresholdPercent: 80);
      expect(msg!.title, 'Batas Mingguan terlampaui');
      expect(msg.body, contains('(lewat)'));
      expect(msg.body, contains('sisa Rp0'));
    });

    test('banyak garis: judul gabungan + body per baris', () {
      final msg = budgetAlertMessage(const [
        BudgetAlertHit(
          scope: LimitScope.daily,
          used: 90,
          limit: 100,
          percent: 90,
          over: false,
        ),
        BudgetAlertHit(
          scope: LimitScope.monthly,
          used: 2_500_000,
          limit: 3_000_000,
          percent: 83,
          over: false,
        ),
      ], thresholdPercent: 80);
      expect(msg!.title, 'Batas pengeluaran menyentuh 80%');
      expect(msg.body.split('\n'), hasLength(2));
      expect(msg.body, contains('Harian: Rp90 dari Rp100'));
    });
  });
}
