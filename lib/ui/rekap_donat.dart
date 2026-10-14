import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/budget.dart' show deltaLabel;
import '../core/money.dart';
import '../core/rekap_filter.dart';
import '../models.dart';
import '../storage/repository.dart';
import '../storage/database.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Segmen Donat pada layar Rekap: headline keluar/masuk + donut kategori
/// sesuai periode [filter]. Statistik keluar MURNI (keputusan A): transfer
/// biasa & Sisihkan tidak masuk headline maupun donut. Tap kategori →
/// [onCategoryTap] dengan filter hasil [RekapFilter.applyDonatTap]
/// (shell yang memindah segmen ke Transaksi).
class RekapDonat extends StatelessWidget {
  const RekapDonat({
    super.key,
    required this.repository,
    required this.filter,
    required this.onCategoryTap,
  });

  final LedgerRepository repository;
  final RekapFilter filter;
  final void Function(RekapFilter filter) onCategoryTap;

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
        _PeriodHeadlines(repository: repository, winStart: start, winEnd: end),
        const SizedBox(height: Spacing.m),
        StreamBuilder<List<TxWithCategory>>(
          stream: repository.watchBetweenWithCategory(
            start,
            end,
            accountId: filter.accountId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const QuestSkeleton(rows: 2, height: 120);
            }
            return _CategoryDonutCard(
              rows: snapshot.data ?? const <TxWithCategory>[],
              onTap: (categoryId) => onCategoryTap(
                filter.applyDonatTap(
                  categoryId: categoryId,
                  monthStart: start,
                  monthEnd: end,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Kartu headline: nominal besar + delta vs periode pembanding.
class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({
    required this.label,
    required this.amount,
    required this.delta,
    required this.upIsBad,
  });

  final String label;
  final int amount;
  final String? delta;
  final bool upIsBad;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final arrow = delta?.startsWith('▲') ?? false;
    final flat = delta?.startsWith('±') ?? false;
    final deltaColor = delta == null || flat
        ? q.muted
        : (arrow == upIsBad ? q.bad : q.good);
    return Container(
      padding: const EdgeInsets.all(Spacing.m),
      decoration: BoxDecoration(
        color: q.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: q.shadow,
            offset: const Offset(0, 6),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.qEyebrow()),
                const SizedBox(height: 2),
                FittedBox(
                  child: Text(
                    Money.format(amount),
                    style: context.qDisplay(30),
                  ),
                ),
              ],
            ),
          ),
          if (delta != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: deltaColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                delta!,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: deltaColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dua headline (keluar & masuk) + delta vs periode pembanding.
class _PeriodHeadlines extends StatelessWidget {
  const _PeriodHeadlines({
    required this.repository,
    required this.winStart,
    required this.winEnd,
  });

  final LedgerRepository repository;
  final DateTime winStart;
  final DateTime winEnd;

  @override
  Widget build(BuildContext context) {
    final span = winEnd.difference(winStart);
    final prevStart = winStart.subtract(span);
    final prevEnd = winStart;
    return Column(
      children: [
        // KELUAR MURNI: sumSpendBetween (transfer biasa & Sisihkan
        // dikecualikan) — keputusan A, bukan sumBetween.
        _HeadlineFuture(
          repository: repository,
          label: 'KELUAR · periode ini',
          start: winStart,
          end: winEnd,
          prevStart: prevStart,
          prevEnd: prevEnd,
          spend: true,
          upIsBad: true,
        ),
        const SizedBox(height: Spacing.s),
        _HeadlineFuture(
          repository: repository,
          label: 'MASUK · periode ini',
          start: winStart,
          end: winEnd,
          prevStart: prevStart,
          prevEnd: prevEnd,
          spend: false,
          upIsBad: false,
        ),
      ],
    );
  }
}

class _HeadlineFuture extends StatelessWidget {
  const _HeadlineFuture({
    required this.repository,
    required this.label,
    required this.start,
    required this.end,
    required this.prevStart,
    required this.prevEnd,
    required this.spend,
    required this.upIsBad,
  });

  final LedgerRepository repository;
  final String label;
  final DateTime start;
  final DateTime end;
  final DateTime prevStart;
  final DateTime prevEnd;
  final bool spend;
  final bool upIsBad;

  Future<int> _sum(DateTime s, DateTime e) => spend
      ? repository.sumSpendBetween(s, e)
      : repository.sumBetween(s, e, Direction.incoming);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _sum(start, end),
      builder: (context, cur) {
        return FutureBuilder<int>(
          future: _sum(prevStart, prevEnd),
          builder: (context, prev) {
            final amount = cur.data ?? 0;
            return _HeadlineCard(
              label: label,
              amount: amount,
              delta: deltaLabel(amount, prev.data ?? 0),
              upIsBad: upIsBad,
            );
          },
        );
      },
    );
  }
}

class _Bucket {
  final String label;
  final int? categoryId;
  final int amount;
  final Color color;

  const _Bucket(this.label, this.categoryId, this.amount, this.color);
}

/// Donut kategori pengeluaran: keluar MURNI (kind transfer — transfer
/// antar-akun & Sisihkan — tidak dihitung). Tap baris legend/slice →
/// [onTap] dengan id kategori (Tanpa kategori tidak bisa deep-link).
class _CategoryDonutCard extends StatelessWidget {
  const _CategoryDonutCard({required this.rows, required this.onTap});

  final List<TxWithCategory> rows;
  final void Function(int categoryId) onTap;

  @override
  Widget build(BuildContext context) {
    final byCategory = <Category?, int>{};
    for (final r in rows) {
      if (r.tx.direction != Direction.outgoing) continue;
      if (r.tx.kind == TxKind.transfer) continue; // belanja murni
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
          e.key?.id,
          e.value,
          e.key == null
              ? context.q.muted.withValues(alpha: 0.4)
              : SeedColors.categoryColor(e.key!.colorIndex),
        ),
    ]..sort((a, b) => b.amount.compareTo(a.amount));

    return QuestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pengeluaran per kategori', style: context.qTitle()),
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
                        dim: context.q.surface,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Total keluar', style: context.qSmall()),
                            Text(
                              Money.format(total),
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
            for (final b in buckets) _legendRow(context, b, total),
          ],
        ],
      ),
    );
  }

  Widget _legendRow(BuildContext context, _Bucket b, int total) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: QuestPress(
        onTap: b.categoryId == null ? null : () => onTap(b.categoryId!),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: b.color,
                  shape: BoxShape.circle,
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
    required this.dim,
  });

  final List<_Bucket> buckets;
  final int total;
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
    for (final b in buckets) {
      final sweep = b.amount / total * 2 * math.pi;
      paint.color = b.color;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.total != total ||
      oldDelegate.buckets.length != buckets.length ||
      [
        for (var i = 0; i < buckets.length; i++)
          oldDelegate.buckets[i].amount != buckets[i].amount ||
              oldDelegate.buckets[i].color != buckets[i].color,
      ].any((differs) => differs);
}
