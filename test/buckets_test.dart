import 'package:flutter_test/flutter_test.dart';
import 'package:bukuduit/core/buckets.dart';
import 'package:bukuduit/models.dart';

AmountPoint point(
  int year,
  int month,
  int day,
  Direction direction,
  int amount,
) => (at: DateTime(year, month, day), direction: direction, amount: amount);

void main() {
  group('monthlyBuckets', () {
    test('6 bucket dengan label lintas tahun yang benar', () {
      final rows = [
        point(2025, 12, 20, Direction.outgoing, 100000),
        point(2026, 1, 5, Direction.outgoing, 50000),
        point(2026, 1, 6, Direction.incoming, 200000),
      ];
      final buckets = monthlyBuckets(rows, DateTime(2026, 1, 10));
      expect(buckets, hasLength(6));
      expect(buckets[4].label, 'Des');
      expect(buckets[4].outgoing, 100000);
      expect(buckets[5].label, "Jan '26");
      expect(buckets[5].outgoing, 50000);
      expect(buckets[5].incoming, 200000);
      expect(buckets[0].outgoing, 0);
    });
  });

  group('weeklyBuckets', () {
    test('4 jendela 7 hari berakhir hari ini', () {
      // now = Jumat 10 Okt 2026; jendela tertua mulai 13 Sep.
      final now = DateTime(2026, 10, 10);
      final rows = [
        point(2026, 10, 10, Direction.outgoing, 10000), // jendela 4
        point(2026, 10, 3, Direction.outgoing, 20000), // jendela 3
        point(2026, 9, 25, Direction.incoming, 30000), // jendela 2
        point(2026, 9, 13, Direction.outgoing, 40000), // jendela 1
        point(2026, 9, 1, Direction.outgoing, 99999), // di luar
      ];
      final buckets = weeklyBuckets(rows, now);
      expect(buckets, hasLength(4));
      expect(buckets[0].outgoing, 40000);
      expect(buckets[0].label, '13 Sep');
      expect(buckets[1].incoming, 30000);
      expect(buckets[2].outgoing, 20000);
      expect(buckets[3].outgoing, 10000);
    });
  });

  group('trendBuckets', () {
    test('rentang pendek → mingguan', () {
      final rows = [
        point(2026, 10, 5, Direction.outgoing, 10000),
        point(2026, 9, 20, Direction.outgoing, 20000),
      ];
      final buckets = trendBuckets(
        rows,
        DateTime(2026, 9, 15),
        DateTime(2026, 10, 10),
      );
      // span 25 hari → 4 jendela mingguan berakhir 10 Okt.
      expect(buckets, hasLength(4));
      expect(buckets.last.outgoing, 10000);
    });

    test('rentang panjang → bulanan', () {
      final rows = [
        point(2026, 8, 10, Direction.outgoing, 70000),
        point(2026, 10, 10, Direction.outgoing, 10000),
      ];
      final buckets = trendBuckets(
        rows,
        DateTime(2026, 5, 1),
        DateTime(2026, 10, 10),
      );
      expect(buckets, hasLength(6));
      expect(buckets.first.label, 'Mei');
      expect(buckets[3].outgoing, 70000); // Agu
      expect(buckets.last.outgoing, 10000); // Okt
    });

    test('batas 62 hari tetap mingguan', () {
      final rows = <AmountPoint>[];
      final buckets = trendBuckets(
        rows,
        DateTime(2026, 8, 10),
        DateTime(2026, 10, 10),
      );
      // span 61 hari → mingguan (9 jendela).
      expect(buckets, hasLength(9));
    });
  });
}
