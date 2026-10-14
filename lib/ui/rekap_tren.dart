import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/buckets.dart';
import '../core/rekap_filter.dart';
import '../models.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Segmen Tren pada layar Rekap: batang masuk/keluar per minggu/bulan
/// sesuai periode [filter]. Batang keluar MURNI (keputusan A): transfer
/// biasa tidak dihitung.
class RekapTren extends StatelessWidget {
  const RekapTren({super.key, required this.repository, required this.filter});

  final LedgerRepository repository;
  final RekapFilter filter;

  @override
  Widget build(BuildContext context) {
    final win = filter.window;
    final now = DateTime.now();
    final start = win?.start ?? DateTime(now.year, now.month);
    final end = win?.end ?? DateTime(now.year, now.month + 1);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        Spacing.m,
        Spacing.s,
        Spacing.m,
        Spacing.m + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        StreamBuilder<List<TxWithCategory>>(
          stream: repository.watchBetweenWithCategory(
            start,
            end,
            accountId: filter.accountId,
          ),
          builder: (context, snapshot) {
            final rows = snapshot.data ?? const <TxWithCategory>[];
            final points = <AmountPoint>[
              for (final r in rows)
                // Keluar murni: kaki transfer keluar tidak jadi titik.
                if (r.tx.direction == Direction.incoming ||
                    r.tx.kind != TxKind.transfer)
                  (
                    at: r.tx.occurredAt,
                    direction: r.tx.direction,
                    amount: r.tx.amount,
                  ),
            ];
            final endInclusive = end.subtract(const Duration(days: 1));
            final buckets = trendBuckets(points, start, endInclusive);
            final title = end.difference(start).inDays > 62
                ? 'Tren bulanan'
                : 'Tren mingguan';
            return _MonthlyBarCard(buckets: buckets, title: title);
          },
        ),
      ],
    );
  }
}

class _MonthlyBarCard extends StatelessWidget {
  const _MonthlyBarCard({required this.buckets, required this.title});

  final List<TrendBucket> buckets;
  final String title;

  @override
  Widget build(BuildContext context) {
    final maxAmount = buckets.fold(
      0,
      (m, b) => math.max(m, math.max(b.incoming, b.outgoing)),
    );
    return QuestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: context.qTitle())),
              _LegendDot(color: context.q.good, label: 'Masuk'),
              const SizedBox(width: Spacing.s),
              _LegendDot(color: context.q.bad, label: 'Keluar'),
            ],
          ),
          const SizedBox(height: Spacing.m),
          SizedBox(
            height: 160,
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: _BarsPainter(
                  months: [
                    for (final b in buckets)
                      (
                        label: b.label,
                        totals: (incoming: b.incoming, outgoing: b.outgoing),
                      ),
                  ],
                  maxAmount: maxAmount,
                  labelColor: context.q.muted,
                  inColor: context.q.good,
                  outColor: context.q.bad,
                ),
              ),
            ),
          ),
        ],
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: context.q.line, width: 1.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: context.qSmall()),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.months,
    required this.maxAmount,
    required this.labelColor,
    required this.inColor,
    required this.outColor,
  });

  final List<({String label, ({int incoming, int outgoing}) totals})> months;
  final int maxAmount;
  final Color labelColor;
  final Color inColor;
  final Color outColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (maxAmount == 0) {
      _drawCenteredText(canvas, size, 'Belum ada data.');
      return;
    }
    final groupWidth = size.width / months.length;
    final barWidth = math.min(14.0, groupWidth / 3.2);
    final chartHeight = size.height - 18;

    final paint = Paint();
    for (var i = 0; i < months.length; i++) {
      final m = months[i];
      final groupCenter = groupWidth * i + groupWidth / 2;
      final inH = chartHeight * m.totals.incoming / maxAmount;
      final outH = chartHeight * m.totals.outgoing / maxAmount;

      paint.color = inColor;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            groupCenter - barWidth - 1.5,
            chartHeight - inH,
            barWidth,
            math.max(inH, 2),
          ),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        paint,
      );
      paint.color = outColor;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            groupCenter + 1.5,
            chartHeight - outH,
            barWidth,
            math.max(outH, 2),
          ),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        paint,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: m.label,
          style: TextStyle(
            fontSize: 10,
            color: labelColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(groupCenter - tp.width / 2, chartHeight + 4));
    }
  }

  void _drawCenteredText(Canvas canvas, Size size, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 13, color: labelColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(size.width / 2 - tp.width / 2, size.height / 2 - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BarsPainter oldDelegate) =>
      oldDelegate.maxAmount != maxAmount ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.inColor != inColor ||
      oldDelegate.outColor != outColor ||
      oldDelegate.months.length != months.length ||
      [
        for (var i = 0; i < months.length; i++)
          oldDelegate.months[i].label != months[i].label ||
              oldDelegate.months[i].totals.incoming !=
                  months[i].totals.incoming ||
              oldDelegate.months[i].totals.outgoing !=
                  months[i].totals.outgoing,
      ].any((differs) => differs);
}
