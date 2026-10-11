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
}
