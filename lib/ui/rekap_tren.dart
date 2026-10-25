import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/buckets.dart';
import '../core/money.dart';
import '../core/rekap_filter.dart';
import '../models.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Segmen Tren pada layar Rekap: batang masuk/keluar per minggu/bulan
/// sesuai periode [filter]. Batang keluar MURNI (keputusan A): transfer
/// biasa tidak dihitung.
class RekapTren extends StatefulWidget {
  const RekapTren({super.key, required this.repository, required this.filter});

  final LedgerRepository repository;
  final RekapFilter filter;

  @override
  State<RekapTren> createState() => _RekapTrenState();
}

class _RekapTrenState extends State<RekapTren> {
  // Disematkan sekali agar rebuild tak subscribe ulang (anti-kedip).
  late Stream<List<TxWithCategory>> _rows;

  @override
  void initState() {
    super.initState();
    _rows = _buildRows();
  }

  @override
  void didUpdateWidget(covariant RekapTren oldWidget) {
    super.didUpdateWidget(oldWidget);
    // TANPA setState — build sudah terjadwal; StreamBuilder di bawah melihat stream baru dan subscribe dengan benar.
    if (widget.repository != oldWidget.repository ||
        _windowKey(widget.filter) != _windowKey(oldWidget.filter) ||
        widget.filter.accountId != oldWidget.filter.accountId) {
      _rows = _buildRows();
    }
  }

  Stream<List<TxWithCategory>> _buildRows() {
    final win = widget.filter.window;
    final now = DateTime.now();
    final start = win?.start ?? DateTime(now.year, now.month);
    final end = win?.end ?? DateTime(now.year, now.month + 1);
    return widget.repository.watchBetweenWithCategory(
      start,
      end,
      accountId: widget.filter.accountId,
    );
  }

  // RekapFilter tak punya == — bandingkan jendela periode per field.
  static String _windowKey(RekapFilter f) {
    final win = f.window;
    return '${win?.start}|${win?.end}';
  }

  @override
  Widget build(BuildContext context) {
    final win = widget.filter.window;
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
          stream: _rows,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const QuestSkeleton(rows: 1, height: 220);
            }
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
                ? 'Tren tiap bulan'
                : 'Tren tiap minggu';
            return Column(
              children: [
                _MonthlyBarCard(buckets: buckets, title: title),
                const SizedBox(height: Spacing.m),
                _TrendBreakdownCard(buckets: buckets),
              ],
            );
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
class _TrendBreakdownCard extends StatelessWidget {
  const _TrendBreakdownCard({required this.buckets});

  final List<TrendBucket> buckets;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(Spacing.m),
      decoration: BoxDecoration(
        color: context.q.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.q.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rincian Arus Kas Tiap Periode',
            style: context.qTitle(15),
          ),
          const SizedBox(height: Spacing.s),
          for (final b in buckets) ...[
            _BucketRow(bucket: b),
            if (b != buckets.last)
              Divider(height: 16, thickness: 1, color: context.q.line),
          ],
        ],
      ),
    );
  }
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({required this.bucket});

  final TrendBucket bucket;

  @override
  Widget build(BuildContext context) {
    final net = bucket.incoming - bucket.outgoing;
    final isSurplus = net >= 0;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bucket.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: context.q.text,
                ),
              ),
              Text(
                isSurplus ? 'Surplus' : 'Defisit',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSurplus ? context.q.good : context.q.bad,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${Money.format(bucket.incoming)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.q.good,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '−${Money.format(bucket.outgoing)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.q.bad,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: Spacing.s),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSurplus ? SeedColors.incomingTint : SeedColors.outgoingTint,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '${isSurplus ? '+' : '−'}${Money.format(net.abs())}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: isSurplus ? context.q.good : context.q.bad,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
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
        const SizedBox(width: Spacing.xs),
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
      _drawCenteredText(
        canvas,
        size,
        'Belum ada yang bisa direkap — mulai catat dulu, ya',
      );
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
