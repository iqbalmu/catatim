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
