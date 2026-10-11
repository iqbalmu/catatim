import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../models.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';
import 'month_picker.dart';
import 'range_calendar.dart';
import '../core/buckets.dart';
import '../core/dates_id.dart';

/// Tab laporan: donut kategori interaktif + tren sesuai periode.
class ReportTab extends StatefulWidget {
  const ReportTab({super.key, required this.repository});

  final LedgerRepository repository;

  @override
  State<ReportTab> createState() => _ReportTabState();
}

enum _Period { month, custom }

class _ReportTabState extends State<ReportTab> {
  _Period _period = _Period.month;
  DateTime? _month; // bulan terpilih, dinormalisasi ke tanggal 1
  DateTimeRange? _custom;

  Future<void> _openPeriodSheet() async {
    final result = await showQuestSheet<(_Period, DateTime?, DateTimeRange?)>(
      context,
      (context) => _PeriodSheet(
        initialPeriod: _period,
        initialMonth: _month,
        initialCustom: _custom,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _period = result.$1;
        _month = result.$2;
        _custom = result.$3;
      });
    }
  }

  String get _periodLabel {
    final now = DateTime.now();
    return switch (_period) {
      _Period.month => _monthLabel(_month ?? DateTime(now.year, now.month)),
      _Period.custom =>
        _custom == null
            ? 'Pilih rentang'
            : '${idDayMonth(_custom!.start)} – ${idDayMonth(_custom!.end)}',
    };
  }

  /// 'Bulan ini' bila bulan berjalan, selain itu 'Okt 2026'.
  String _monthLabel(DateTime m) {
    final now = DateTime.now();
    if (m.year == now.year && m.month == now.month) return 'Bulan ini';
    return idMonthYear(m);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final DateTime winStart;
    final DateTime winEnd;
    switch (_period) {
      case _Period.month:
        final m = _month ?? DateTime(now.year, now.month);
        winStart = DateTime(m.year, m.month);
        winEnd = DateTime(m.year, m.month + 1);
      case _Period.custom:
        final c = _custom!;
        winStart = DateTime(c.start.year, c.start.month, c.start.day);
        winEnd = DateTime(c.end.year, c.end.month, c.end.day + 1);
    }

    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: QuestHeader(title: 'Laporan', subtitle: _periodLabel),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.m,
        ),
        children: [
          // Chip periode kompak pengganti segmented — buka sheet kalender.
          QuestPress(
            onTap: _openPeriodSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.q.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.q.line, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: context.q.shadow,
                    offset: const Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.event_outlined, color: context.q.honeyInk),
                  const SizedBox(width: Spacing.s),
                  Expanded(
                    child: Text(_periodLabel, style: context.qTitle(15)),
                  ),
                  Icon(Icons.expand_more_rounded, color: context.q.muted),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.m),
          StreamBuilder<List<TxWithCategory>>(
            stream: widget.repository.watchBetweenWithCategory(
              winStart,
              winEnd,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const QuestSkeleton(rows: 2, height: 120);
              }
              return _CategoryDonutCard(
                rows: snapshot.data ?? const <TxWithCategory>[],
              );
            },
          ),
          const SizedBox(height: Spacing.m),
          StreamBuilder<List<TxWithCategory>>(
            stream: widget.repository.watchBetweenWithCategory(
              winStart,
              winEnd,
            ),
            builder: (context, snapshot) {
              final rows = snapshot.data ?? const <TxWithCategory>[];
              final points = <AmountPoint>[
                for (final r in rows)
                  (
                    at: r.tx.occurredAt,
                    direction: r.tx.direction,
                    amount: r.tx.amount,
                  ),
              ];
              final List<TrendBucket> buckets;
              final String title;
              switch (_period) {
                case _Period.month:
                case _Period.custom:
                  final endInclusive = winEnd.subtract(const Duration(days: 1));
                  buckets = trendBuckets(points, winStart, endInclusive);
                  title = winEnd.difference(winStart).inDays > 62
                      ? 'Tren bulanan'
                      : 'Tren mingguan';
              }
              return _MonthlyBarCard(buckets: buckets, title: title);
            },
          ),
        ],
      ),
    );
  }
}

/// Sheet pemilih periode: segmented bulan/rentang + picker inline.
class _PeriodSheet extends StatefulWidget {
  const _PeriodSheet({
    required this.initialPeriod,
    required this.initialMonth,
    required this.initialCustom,
  });

  final _Period initialPeriod;
  final DateTime? initialMonth;
  final DateTimeRange? initialCustom;

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  late _Period _period;
  DateTime? _month;
  DateTimeRange? _custom;

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod;
    _month = widget.initialMonth;
    _custom = widget.initialCustom;
  }

  void _select(_Period v) {
    setState(() {
      _period = v;
      if (v == _Period.month && _month == null) {
        final now = DateTime.now();
        _month = DateTime(now.year, now.month);
      }
    });
  }

  void _apply() {
    // Rentang tanpa pilihan tanggal = fallback bulan berjalan, jangan
    // biarkan _custom! crash di build.
    final period = (_period == _Period.custom && _custom == null)
        ? _Period.month
        : _period;
    Navigator.pop(context, (period, _month, _custom));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text('Periode', style: context.qTitle(20)),
            ),
            const SizedBox(height: Spacing.m),
            QuestSegmented<_Period>(
              selected: _period,
              onChanged: _select,
              options: const [
                (value: _Period.month, label: 'Bulan', icon: null),
                (value: _Period.custom, label: 'Rentang', icon: null),
              ],
            ),
            if (_period == _Period.month) ...[
              const SizedBox(height: Spacing.m),
              QuestCard(
                radius: 16,
                child: QuestMonthPicker(
                  initialMonth: _month,
                  onChanged: (m) => setState(() => _month = m),
                ),
              ),
            ],
            if (_period == _Period.custom) ...[
              const SizedBox(height: Spacing.m),
              QuestCard(
                radius: 16,
                child: QuestRangeCalendar(
                  initialRange: _custom,
                  onChanged: (r) => setState(() => _custom = r),
                ),
              ),
            ],
            const SizedBox(height: Spacing.l),
            QuestButton(
              label: 'Terapkan',
              icon: Icons.check_rounded,
              onPressed: _apply,
            ),
            const SizedBox(height: Spacing.m),
          ],
        ),
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

class _CategoryDonutCard extends StatefulWidget {
  const _CategoryDonutCard({required this.rows});

  final List<TxWithCategory> rows;

  @override
  State<_CategoryDonutCard> createState() => _CategoryDonutCardState();
}

class _CategoryDonutCardState extends State<_CategoryDonutCard> {
  int _selected = -1;

  @override
  Widget build(BuildContext context) {
    final byCategory = <Category?, int>{};
    for (final r in widget.rows) {
      if (r.tx.direction != Direction.outgoing) continue;
      byCategory.update(
        r.category,
        (v) => v + r.tx.amount,
        ifAbsent: () => r.tx.amount,
      );
    }
    final total = byCategory.values.fold(0, (a, b) => a + b);
    final buckets = [
      for (final e in byCategory.entries)
        _Bucket(
          e.key?.name ?? 'Tanpa kategori',
          e.value,
          e.key == null
              ? context.q.muted.withValues(alpha: 0.4)
              : SeedColors.categoryColor(e.key!.colorIndex),
        ),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
    if (_selected >= buckets.length) _selected = -1;

    final focus = _selected >= 0 ? buckets[_selected] : null;

    return QuestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pengeluaran per kategori',
                  style: context.qTitle(),
                ),
              ),
              if (focus != null)
                QuestChip(
                  label: '✕ ${focus.label}',
                  selected: true,
                  onTap: () => setState(() => _selected = -1),
                ),
            ],
          ),
          const SizedBox(height: Spacing.m),
          if (total == 0)
            QuestEmpty(
              title: 'Belum ada pengeluaran',
              hint: 'Catat transaksimu — Duit menunggu!',
            )
          else ...[
            SizedBox(
              height: 180,
              child: Center(
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _DonutPainter(
                        buckets: buckets,
                        total: total,
                        selected: _selected,
                        dim: context.q.surface,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              focus?.label ?? 'Total keluar',
                              style: context.qSmall(),
                            ),
                            Text(
                              Money.format(focus?.amount ?? total),
                              style: context.qTitle(19),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.m),
            for (var i = 0; i < buckets.length; i++)
              _legendRow(context, buckets[i], total, i),
          ],
        ],
      ),
    );
  }

  Widget _legendRow(BuildContext context, _Bucket b, int total, int index) {
    final active = _selected == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: QuestPress(
        onTap: () => setState(() => _selected = active ? -1 : index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? context.q.honey.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? context.q.line : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: b.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.q.line, width: 1.5),
                ),
              ),
              const SizedBox(width: Spacing.s),
              Expanded(
                child: Text(
                  b.label,
                  overflow: TextOverflow.ellipsis,
                  style: context.qBody(13),
                ),
              ),
              Text(
                '${(b.amount / total * 100).toStringAsFixed(0)}% · ${Money.format(b.amount)}',
                style: context
                    .qSmall(12)
                    .copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.buckets,
    required this.total,
    required this.selected,
    required this.dim,
  });

  final List<_Bucket> buckets;
  final int total;
  final int selected;
  final Color dim;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    const stroke = 30.0;
    final rect = Rect.fromCircle(center: center, radius: radius - stroke / 2);
    var start = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final sweep = b.amount / total * 2 * math.pi;
      paint.color = (selected < 0 || selected == i)
          ? b.color
          : Color.alphaBlend(dim.withValues(alpha: 0.55), b.color);
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.total != total ||
      oldDelegate.buckets.length != buckets.length ||
      oldDelegate.selected != selected;
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
      oldDelegate.outColor != outColor;
}
