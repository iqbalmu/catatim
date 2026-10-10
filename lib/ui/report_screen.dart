import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../models.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/tokens.dart';

const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Tab laporan: donut kategori + tren 6 bulan, digambar CustomPainter.
class ReportTab extends StatefulWidget {
  const ReportTab({super.key, required this.repository});

  final LedgerRepository repository;

  @override
  State<ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<ReportTab> {
  bool _sixMonths = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sixAgo = DateTime(now.year, now.month - 5);
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.m),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Bulan ini')),
              ButtonSegment(value: true, label: Text('6 bulan')),
            ],
            selected: {_sixMonths},
            onSelectionChanged: (s) => setState(() => _sixMonths = s.first),
          ),
          const SizedBox(height: Spacing.m),
          StreamBuilder<List<TxWithCategory>>(
            stream: widget.repository
                .watchBetweenWithCategory(sixAgo, monthEnd),
            builder: (context, snapshot) {
              final all = snapshot.data ?? const <TxWithCategory>[];
              final windowed = _sixMonths
                  ? all
                  : [
                      for (final r in all)
                        if (!r.tx.occurredAt.isBefore(monthStart)) r,
                    ];
              return _CategoryDonutCard(rows: windowed);
            },
          ),
          const SizedBox(height: Spacing.m),
          StreamBuilder<List<TxWithCategory>>(
            stream: widget.repository
                .watchBetweenWithCategory(sixAgo, monthEnd),
            builder: (context, snapshot) =>
                _MonthlyBarCard(rows: snapshot.data ?? const <TxWithCategory>[]),
          ),
        ],
      ),
    );
  }
}

class _Bucket {
  final String label;
  final int amount;
  final Color color;

  const _Bucket(this.label, this.amount, this.color);
}

class _CategoryDonutCard extends StatelessWidget {
  const _CategoryDonutCard({required this.rows});

  final List<TxWithCategory> rows;

  @override
  Widget build(BuildContext context) {
    final byCategory = <Category?, int>{};
    for (final r in rows) {
      if (r.tx.direction != Direction.outgoing) continue;
      byCategory.update(r.category, (v) => v + r.tx.amount,
          ifAbsent: () => r.tx.amount);
    }
    final total = byCategory.values.fold(0, (a, b) => a + b);
    final buckets = [
      for (final e in byCategory.entries)
        _Bucket(
          e.key?.name ?? 'Tanpa kategori',
          e.value,
          e.key == null
              ? Theme.of(context).colorScheme.outlineVariant
              : SeedColors.categoryColor(e.key!.colorIndex),
        ),
    ]..sort((a, b) => b.amount.compareTo(a.amount));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pengeluaran per kategori',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.m),
            if (total == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Spacing.xl),
                child: Center(child: Text('Belum ada pengeluaran.')),
              )
            else ...[
              SizedBox(
                height: 180,
                child: Center(
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: CustomPaint(
                      painter: _DonutPainter(buckets, total),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Total keluar',
                                style: Theme.of(context).textTheme.labelSmall),
                            Text(
                              Money.format(total),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.m),
              for (final b in buckets.take(6))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration:
                            BoxDecoration(color: b.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: Spacing.s),
                      Expanded(child: Text(b.label, overflow: TextOverflow.ellipsis)),
                      Text(
                        '${(b.amount / total * 100).toStringAsFixed(0)}% · ${Money.format(b.amount)}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.buckets, this.total);

  final List<_Bucket> buckets;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    const stroke = 30.0;
    final rect = Rect.fromCircle(center: center, radius: radius - stroke / 2);
    var start = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    for (final b in buckets) {
      final sweep = b.amount / total * 2 * math.pi;
      paint.color = b.color;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.total != total || oldDelegate.buckets.length != buckets.length;
}

class _MonthlyBarCard extends StatelessWidget {
  const _MonthlyBarCard({required this.rows});

  final List<TxWithCategory> rows;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [
      for (var i = 5; i >= 0; i--)
        DateTime(now.year, now.month - i),
    ];
    final totals = <DateTime, ({int incoming, int outgoing})>{
      for (final m in months) (m): (incoming: 0, outgoing: 0),
    };
    for (final r in rows) {
      final key = DateTime(r.tx.occurredAt.year, r.tx.occurredAt.month);
      final slot = totals[key];
      if (slot == null) continue;
      totals[key] = r.tx.direction == Direction.incoming
          ? (incoming: slot.incoming + r.tx.amount, outgoing: slot.outgoing)
          : (incoming: slot.incoming, outgoing: slot.outgoing + r.tx.amount);
    }
    final maxAmount = totals.values
        .expand((v) => [v.incoming, v.outgoing])
        .fold(0, math.max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Tren 6 bulan',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                _LegendDot(
                    color: SeedColors.incoming, label: 'Masuk'),
                const SizedBox(width: Spacing.s),
                _LegendDot(
                    color: SeedColors.outgoing, label: 'Keluar'),
              ],
            ),
            const SizedBox(height: Spacing.m),
            SizedBox(
              height: 160,
              child: CustomPaint(
                size: Size.infinite,
                painter: _BarsPainter(
                  months: [
                    for (final m in months)
                      (
                        label: '${_monthsShort[m.month - 1]}${m.month == 1 ? " '${m.year % 100}" : ''}',
                        totals: totals[m]!,
                      ),
                  ],
                  maxAmount: maxAmount,
                  labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.months,
    required this.maxAmount,
    required this.labelColor,
  });

  final List<({String label, ({int incoming, int outgoing}) totals})> months;
  final int maxAmount;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (maxAmount == 0) {
      _drawCenteredText(canvas, size, 'Belum ada data.');
      return;
    }
    final groupWidth = size.width / months.length;
    final barWidth = math.min(14.0, groupWidth / 3.2);
    final chartHeight = size.height - 18; // ruang label bulan

    final paint = Paint();
    for (var i = 0; i < months.length; i++) {
      final m = months[i];
      final groupCenter = groupWidth * i + groupWidth / 2;
      final inH = chartHeight * m.totals.incoming / maxAmount;
      final outH = chartHeight * m.totals.outgoing / maxAmount;

      paint.color = SeedColors.incoming;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(groupCenter - barWidth - 1.5, chartHeight - inH,
              barWidth, math.max(inH, 2)),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        paint,
      );
      paint.color = SeedColors.outgoing;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(groupCenter + 1.5, chartHeight - outH, barWidth,
              math.max(outH, 2)),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        paint,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: m.label,
          style: TextStyle(fontSize: 10, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(groupCenter - tp.width / 2, chartHeight + 4),
      );
    }
  }

  void _drawCenteredText(Canvas canvas, Size size, String text) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: 13, color: labelColor)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        size.width / 2 - tp.width / 2,
        size.height / 2 - tp.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _BarsPainter oldDelegate) =>
      oldDelegate.maxAmount != maxAmount ||
      oldDelegate.labelColor != labelColor;
}
