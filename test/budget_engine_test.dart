import 'package:flutter_test/flutter_test.dart';
import 'package:bukuduit/core/budget.dart';

void main() {
  group('LimitLine.level', () {
    test('tanpa batas selalu ok', () {
      final line = LimitLine(label: 'x', used: 999999);
      expect(line.level, BudgetLevel.ok);
      expect(line.fraction, 0);
      expect(line.usedPercent, 0);
    });

    test('ambang warning 75% dan over 100%', () {
      BudgetLevel levelOf(int used, int limit) =>
          LimitLine(label: 'x', used: used, limit: limit).level;
      expect(levelOf(749, 1000), BudgetLevel.ok);
      expect(levelOf(750, 1000), BudgetLevel.warning);
      expect(levelOf(999, 1000), BudgetLevel.warning);
      expect(levelOf(1000, 1000), BudgetLevel.over);
      expect(levelOf(1500, 1000), BudgetLevel.over);
    });

    test('fraction dipotong ke 1', () {
      final line = LimitLine(label: 'x', used: 3000, limit: 1000);
      expect(line.fraction, 1);
      expect(line.usedPercent, 300);
    });
  });

  group('BudgetSnapshot', () {
    BudgetSnapshot snap({
      List<LimitLine> lines = const [],
      int monthOut = 0,
      int lastMonthOut = 0,
      int monthIn = 0,
      int lastMonthIn = 0,
      bool hasData = true,
    }) =>
        BudgetSnapshot(
          lines: lines,
          monthOut: monthOut,
          lastMonthOut: lastMonthOut,
          monthIn: monthIn,
          lastMonthIn: lastMonthIn,
          hasData: hasData,
        );

    test('worstLevel over menang atas warning dan ok', () {
      final s = snap(lines: const [
        LimitLine(label: 'a', used: 10, limit: 100),
        LimitLine(label: 'b', used: 80, limit: 100),
        LimitLine(label: 'c', used: 120, limit: 100),
      ]);
      expect(s.worstLevel, BudgetLevel.over);
      expect(s.overLines.single.label, 'c');
      expect(s.warningLines.single.label, 'b');
      expect(s.criticalLine!.label, 'c');
    });

    test('criticalLine warning terburuk berdasar persentase', () {
      final s = snap(lines: const [
        LimitLine(label: 'a', used: 76, limit: 100),
        LimitLine(label: 'b', used: 90, limit: 100),
      ]);
      expect(s.criticalLine!.label, 'b');
    });

    test('tanpa masalah criticalLine null', () {
      final s = snap(lines: const [
        LimitLine(label: 'a', used: 10, limit: 100),
      ]);
      expect(s.criticalLine, isNull);
    });

    test('tren keluar: turun membaik, naik memburuk, ±5% datar', () {
      expect(snap(monthOut: 900, lastMonthOut: 1000).outTrend,
          TrendDirection.better);
      expect(snap(monthOut: 1100, lastMonthOut: 1000).outTrend,
          TrendDirection.worse);
      expect(snap(monthOut: 1020, lastMonthOut: 1000).outTrend,
          TrendDirection.flat);
    });

    test('tren keluar saat bulan lalu kosong', () {
      // Bulan lalu 0, sekarang ada → memburuk.
      expect(snap(monthOut: 100, lastMonthOut: 0).outTrend,
          TrendDirection.worse);
      // Dua-duanya kosong → datar.
      expect(snap(monthOut: 0, lastMonthOut: 0).outTrend,
          TrendDirection.flat);
    });

    test('tren masuk: naik membaik', () {
      expect(snap(monthIn: 1200, lastMonthIn: 1000).inTrend,
          TrendDirection.better);
      expect(snap(monthIn: 800, lastMonthIn: 1000).inTrend,
          TrendDirection.worse);
    });

    test('label tren konsisten arah', () {
      expect(trendLabel(TrendDirection.better, incoming: false),
          'keluar turun');
      expect(trendLabel(TrendDirection.worse, incoming: false),
          'keluar naik');
      expect(trendLabel(TrendDirection.better, incoming: true), 'masuk naik');
    });
  });

  group('pace harian', () {
    final now = DateTime(2026, 10, 11); // Minggu, 31 hari.

    test('prioritas harian di atas mingguan/bulanan', () {
      final p = dailyPace(
        now: now,
        dayOut: 42500,
        weekOut: 150000,
        monthOut: 1000000,
        dailyLimit: 50000,
        weeklyLimit: 300000,
        monthlyTotal: 3100000,
      );
      expect(p.safeToSpend, 7500);
    });

    test('harian over tetap negatif', () {
      expect(
        dailyPace(
          now: now,
          dayOut: 60000,
          weekOut: 60000,
          monthOut: 60000,
          dailyLimit: 50000,
        ).safeToSpend,
        -10000,
      );
    });

    test('fallback mingguan: sisa minggu dibagi sisa hari', () {
      expect(
        dailyPace(
          now: now,
          dayOut: 100000,
          weekOut: 100000,
          monthOut: 100000,
          weeklyLimit: 300000,
        ).safeToSpend,
        200000, // (300rb-100rb) / sisa 1 hari (Minggu).
      );
      expect(
        dailyPace(
          now: DateTime(2026, 10, 7), // Rabu.
          dayOut: 100000,
          weekOut: 100000,
          monthOut: 100000,
          weeklyLimit: 300000,
        ).safeToSpend,
        40000, // / sisa 5 hari.
      );
    });

    test('fallback bulanan: sisa bulan dibagi sisa hari', () {
      expect(
        dailyPace(
          now: now,
          dayOut: 1000000,
          weekOut: 1000000,
          monthOut: 1000000,
          monthlyTotal: 3100000,
        ).safeToSpend,
        100000, // 2100000 / (31-11+1).
      );
    });

    test('tanpa batas apa pun: null', () {
      expect(
        dailyPace(
          now: now,
          dayOut: 0,
          weekOut: 0,
          monthOut: 0,
        ).safeToSpend,
        isNull,
      );
    });

    test('limit nol diperlakukan tanpa batas', () {
      expect(
        dailyPace(
          now: now,
          dayOut: 0,
          weekOut: 0,
          monthOut: 0,
          dailyLimit: 0,
        ).safeToSpend,
        isNull,
      );
    });

    test('idealUsedPercent dan dimensi bulan', () {
      final p = dailyPace(now: now, dayOut: 0, weekOut: 0, monthOut: 0);
      expect(p.idealUsedPercent, 35);
      expect(p.dayOfMonth, 11);
      expect(p.daysInMonth, 31);
      final feb = dailyPace(
        now: DateTime(2024, 2, 1),
        dayOut: 0,
        weekOut: 0,
        monthOut: 0,
      );
      expect(feb.daysInMonth, 29);
      expect(feb.idealUsedPercent, 3);
    });
  });
}
