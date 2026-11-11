part of '../laporan_screen.dart';

class _CategoryStat {
  const _CategoryStat({
    required this.id,
    required this.name,
    required this.amount,
    required this.color,
    required this.icon,
    required this.items,
  });

  final int? id;
  final String name;
  final int amount;
  final Color color;
  final IconData icon;
  final List<TxWithCategory> items;
}

class _ReportMetrics {
  const _ReportMetrics({
    required this.totalIn,
    required this.totalOut,
    required this.inCount,
    required this.outCount,
    required this.prevIn,
    required this.prevOut,
    required this.activeDaysSpan,
    required this.outCategories,
    required this.inCategories,
    required this.trendBuckets,
    required this.isMonthlyTrend,
    required this.topExpenses,
  });

  final int totalIn;
  final int totalOut;
  final int inCount;
  final int outCount;
  final int prevIn;
  final int prevOut;
  final int activeDaysSpan;
  final List<_CategoryStat> outCategories;
  final List<_CategoryStat> inCategories;
  final List<TrendBucket> trendBuckets;
  final bool isMonthlyTrend;
  final List<TxWithCategory> topExpenses;

  int get net => totalIn - totalOut;
  bool get isSurplus => net >= 0;
  bool get hasAnyActivity => inCount > 0 || outCount > 0;

  int? get savingsRatePercent {
    if (totalIn <= 0) return null;
    return ((net / totalIn) * 100).round();
  }

  int get avgDailyOut =>
      activeDaysSpan > 0 ? (totalOut / activeDaysSpan).round() : 0;

  int get avgPerOutTx => outCount > 0 ? (totalOut / outCount).round() : 0;

  int? get outDeltaPercent {
    if (prevOut <= 0) return null;
    return (((totalOut - prevOut) * 100) / prevOut).round();
  }

  int? get inDeltaPercent {
    if (prevIn <= 0) return null;
    return (((totalIn - prevIn) * 100) / prevIn).round();
  }

  static _ReportMetrics compute({
    required List<TxWithCategory> rows,
    required List<TxWithCategory> prevRows,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    var totalIn = 0;
    var totalOut = 0;
    var inCount = 0;
    var outCount = 0;

    final outByCat = <int?, List<TxWithCategory>>{};
    final inByCat = <int?, List<TxWithCategory>>{};
    final catMeta = <int?, Category?>{};
    final points = <AmountPoint>[];
    final pureExpenses = <TxWithCategory>[];

    for (final r in rows) {
      if (r.tx.direction == Direction.incoming) {
        if (r.tx.kind != TxKind.transfer) {
          totalIn += r.tx.amount;
          inCount++;
          final key = r.category?.id;
          catMeta[key] = r.category;
          inByCat.putIfAbsent(key, () => []).add(r);
          points.add((
            at: r.tx.occurredAt,
            direction: Direction.incoming,
            amount: r.tx.amount,
          ));
        }
      } else if (r.tx.kind != TxKind.transfer) {
        totalOut += r.tx.amount;
        outCount++;
        final key = r.category?.id;
        catMeta[key] = r.category;
        outByCat.putIfAbsent(key, () => []).add(r);
        pureExpenses.add(r);
        points.add((
          at: r.tx.occurredAt,
          direction: Direction.outgoing,
          amount: r.tx.amount,
        ));
      }
    }

    var prevIn = 0;
    var prevOut = 0;
    for (final r in prevRows) {
      if (r.tx.direction == Direction.incoming) {
        if (r.tx.kind != TxKind.transfer) {
          prevIn += r.tx.amount;
        }
      } else if (r.tx.kind != TxKind.transfer) {
        prevOut += r.tx.amount;
      }
    }

    List<_CategoryStat> buildStats(Map<int?, List<TxWithCategory>> grouped) {
      final list = <_CategoryStat>[];
      for (final entry in grouped.entries) {
        final cat = catMeta[entry.key];
        final sum = entry.value.fold<int>(0, (s, e) => s + e.tx.amount);
        final sortedItems = [...entry.value]
          ..sort((a, b) => b.tx.occurredAt.compareTo(a.tx.occurredAt));
        list.add(
          _CategoryStat(
            id: cat?.id,
            name: cat?.name ?? 'Tanpa Kategori',
            amount: sum,
            color: cat == null
                ? SeedColors.muted
                : SeedColors.categoryColor(cat.colorIndex),
            icon: _iconForCategory(cat),
            items: sortedItems,
          ),
        );
      }
      list.sort((a, b) => b.amount.compareTo(a.amount));
      return list;
    }

    pureExpenses.sort((a, b) => b.tx.amount.compareTo(a.tx.amount));

    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day + 1);
    final effectiveEnd =
        endExclusive.isAfter(todayEnd) && start.isBefore(todayEnd)
            ? todayEnd
            : endExclusive;
    final activeDays = math.max(1, effectiveEnd.difference(start).inDays);

    final endInclusive = endExclusive.subtract(const Duration(days: 1));
    final spanDays = endInclusive.difference(start).inDays;
    final buckets = bkt.trendBuckets(points, start, endInclusive);

    return _ReportMetrics(
      totalIn: totalIn,
      totalOut: totalOut,
      inCount: inCount,
      outCount: outCount,
      prevIn: prevIn,
      prevOut: prevOut,
      activeDaysSpan: activeDays,
      outCategories: buildStats(outByCat),
      inCategories: buildStats(inByCat),
      trendBuckets: buckets,
      isMonthlyTrend: spanDays > 62,
      topExpenses: pureExpenses.take(5).toList(),
    );
  }
}

IconData _iconForCategory(Category? cat) {
  if (cat == null) return Icons.label_outline_rounded;
  final lower = cat.name.toLowerCase();
  if (lower.contains('makan') ||
      lower.contains('minum') ||
      lower.contains('kopi')) {
    return Icons.restaurant_rounded;
  }
  if (lower.contains('transport') ||
      lower.contains('bensin') ||
      lower.contains('ojek')) {
    return Icons.directions_car_rounded;
  }
  if (lower.contains('tagihan') ||
      lower.contains('listrik') ||
      lower.contains('internet')) {
    return Icons.receipt_long_rounded;
  }
  if (lower.contains('belanja') || lower.contains('pasar')) {
    return Icons.shopping_bag_rounded;
  }
  if (lower.contains('hiburan') || lower.contains('game')) {
    return Icons.movie_rounded;
  }
  if (lower.contains('sehat') || lower.contains('obat')) {
    return Icons.favorite_rounded;
  }
  if (lower.contains('gaji') || lower.contains('upah')) {
    return Icons.payments_rounded;
  }
  if (lower.contains('transfer')) {
    return Icons.swap_horiz_rounded;
  }
  return switch (cat.colorIndex % 9) {
    0 => Icons.restaurant_rounded,
    1 => Icons.directions_car_rounded,
    2 => Icons.receipt_long_rounded,
    3 => Icons.shopping_bag_rounded,
    4 => Icons.movie_rounded,
    5 => Icons.favorite_rounded,
    6 => Icons.payments_rounded,
    7 => Icons.swap_horiz_rounded,
    _ => Icons.category_rounded,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
