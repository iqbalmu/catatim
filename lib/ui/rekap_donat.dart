import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/budget.dart' show deltaLabel;
import '../core/dates_id.dart';
import '../core/money.dart';
import '../core/rekap_filter.dart';
import '../models.dart';
import '../storage/repository.dart';
import '../storage/database.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Segmen Donat pada layar Rekap (segmen DEFAULT — mockup v2.1: pertanyaan
/// pertama pengguna "uangku ke mana?"). Toggle Keluar/Masuk hidup DI DALAM
/// kartu donat; delta vs periode pembanding tampil sebagai chip. Statistik
/// keluar MURNI (keputusan A): transfer keluar tidak masuk donat. Tap
/// kategori → [onCategoryTap] dengan filter hasil [RekapFilter.applyDonatTap]
/// (shell yang memindah segmen ke Transaksi).
class RekapDonat extends StatefulWidget {
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
  State<RekapDonat> createState() => _RekapDonatState();
}

class _RekapDonatState extends State<RekapDonat> {
  // Disematkan sekali agar rebuild tak subscribe ulang (anti-kedip).
  late Stream<List<TxWithCategory>> _rows;

  /// Mode donat: false = keluar (default), true = masuk.
  bool _incoming = false;

  @override
  void initState() {
    super.initState();
    _rows = _buildRows();
  }

  @override
  void didUpdateWidget(covariant RekapDonat oldWidget) {
    super.didUpdateWidget(oldWidget);
    // TANPA setState — build sudah terjadwal; StreamBuilder di bawah melihat stream baru dan subscribe dengan benar.
    // RekapFilter tak punya == — bandingkan jendela + akun per field.
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

    return StreamBuilder<List<TxWithCategory>>(
      stream: _rows,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: Spacing.m),
            child: QuestSkeleton(rows: 2, height: 120),
          );
        }
        final rows = snapshot.data ?? const <TxWithCategory>[];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DonatCard(
                rows: rows,
                incoming: _incoming,
                onToggle: (v) => setState(() => _incoming = v),
                repository: widget.repository,
                start: start,
                end: end,
                onTap: (categoryId) => widget.onCategoryTap(
                  widget.filter.applyDonatTap(
                    categoryId: categoryId,
                    monthStart: start,
                    monthEnd: end,
                  ),
                ),
              ),
              if (!_incoming) _TopSpendCard(rows: rows),
            ],
          ),
        );
      },
    );
  }
}

/// Kartu donat: toggle arah + donut + legenda + chip delta vs periode
/// pembanding — semuanya dalam satu kartu (mockup v2.1).
class _DonatCard extends StatelessWidget {
  const _DonatCard({
    required this.rows,
    required this.incoming,
    required this.onToggle,
    required this.repository,
    required this.start,
    required this.end,
    required this.onTap,
  });

  final List<TxWithCategory> rows;
  final bool incoming;
  final ValueChanged<bool> onToggle;
  final LedgerRepository repository;
  final DateTime start;
  final DateTime end;
  final void Function(int categoryId) onTap;

  List<_Bucket> _buckets(BuildContext context) {
    final byCategory = <Category?, int>{};
    for (final r in rows) {
      if (incoming) {
        if (r.tx.direction != Direction.incoming) continue;
      } else {
        if (r.tx.direction != Direction.outgoing) continue;
        if (r.tx.kind == TxKind.transfer) continue; // belanja murni
      }
      byCategory.update(
        r.category,
        (v) => v + r.tx.amount,
        ifAbsent: () => r.tx.amount,
      );
    }
    return [
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
  }

  @override
  Widget build(BuildContext context) {
    final buckets = _buckets(context);
    final total = buckets.fold(0, (a, b) => a + b.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Donut Visual Card
        QuestCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 176,
                    child: QuestSegmented<bool>(
                      selected: incoming,
                      onChanged: onToggle,
                      options: const [
                        (value: false, label: 'Keluar', icon: null),
                        (value: true, label: 'Masuk', icon: null),
                      ],
                    ),
                  ),
                  _DeltaChip(
                    repository: repository,
                    start: start,
                    end: end,
                    spend: !incoming,
                  ),
                ],
              ),
              const SizedBox(height: Spacing.m),
              if (total == 0)
                QuestEmpty(
                  title: incoming ? 'Belum ada pemasukan' : 'Belum ada pengeluaran',
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
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    incoming ? 'Total Masuk' : 'Total Keluar',
                                    style: context.qSmall(11.5),
                                    maxLines: 1,
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      Money.format(total),
                                      style: context.qTitle(17),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.s),
                // Top 3 category chips under Donut
                Center(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final b in buckets.take(3))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: b.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: b.color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${b.label} ${((b.amount / total) * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: b.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (total > 0) ...[
          const SizedBox(height: Spacing.m),
          // 2. Category Breakdown Card
          QuestCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rincian per Kategori',
                      style: context.qTitle(15),
                    ),
                    Text(
                      '${buckets.length} kategori',
                      style: context.qSmall(12),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.m),
                for (final b in buckets) _legendRow(context, b, total),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _legendRow(BuildContext context, _Bucket b, int total) {
    final pct = total > 0 ? (b.amount / total) : 0.0;
    final pctInt = (pct * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.s),
      child: QuestPress(
        onTap: b.categoryId == null ? null : () => onTap(b.categoryId!),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.q.surface2,
            borderRadius: BorderRadius.circular(AppRadius.tile),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
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
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: context.q.text,
                      ),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      Money.format(b.amount),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: context.q.text,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: b.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '$pctInt%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: b.color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: context.q.line,
                  valueColor: AlwaysStoppedAnimation<Color>(b.color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip delta arah terpilih vs periode sama sebelumnya (fair mid-month).
/// Favorable = mint, unfavorable = merah; pembanding nol → teks netral
/// "bulan pertama".
class _DeltaChip extends StatefulWidget {
  const _DeltaChip({
    required this.repository,
    required this.start,
    required this.end,
    required this.spend,
  });

  final LedgerRepository repository;
  final DateTime start;
  final DateTime end;
  final bool spend;

  @override
  State<_DeltaChip> createState() => _DeltaChipState();
}

class _DeltaChipState extends State<_DeltaChip> {
  late Future<int> _cur;
  late Future<int> _prev;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant _DeltaChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spend != oldWidget.spend ||
        widget.start.millisecondsSinceEpoch !=
            oldWidget.start.millisecondsSinceEpoch ||
        widget.end.millisecondsSinceEpoch !=
            oldWidget.end.millisecondsSinceEpoch) {
      _fetch();
    }
  }

  void _fetch() {
    final span = widget.end.difference(widget.start);
    final prevStart = widget.start.subtract(span);
    _cur = widget.spend
        ? widget.repository.sumSpendBetween(widget.start, widget.end)
        : widget.repository.sumBetween(
            widget.start,
            widget.end,
            Direction.incoming,
          );
    _prev = widget.spend
        ? widget.repository.sumSpendBetween(prevStart, widget.start)
        : widget.repository.sumBetween(
            prevStart,
            widget.start,
            Direction.incoming,
          );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _cur,
      builder: (context, cur) {
        return FutureBuilder<int>(
          future: _prev,
          builder: (context, prev) {
            final delta = deltaLabel(cur.data ?? 0, prev.data ?? 0);
            if (delta == null) {
              return Text(
                'bulan pertama — pembanding menyusul',
                style: context.qSmall(11),
              );
            }
            final up = delta.startsWith('▲');
            // Keluar: turun itu baik. Masuk: naik itu baik.
            final good = widget.spend ? !up : up;
            final tint = good
                ? SeedColors.incomingTint
                : SeedColors.outgoingTint;
            final fg = good ? SeedColors.incoming : SeedColors.outgoing;
            final month = idMonthsShort[(widget.start.month + 10) % 12];
            return Container(
              padding: Insets.chip,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '$delta vs $month',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: fg,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Kartu "Keluar terbesar": agregat keluar murni per lawan transaksi —
/// jembatan dari persentase donat ke transaksi nyata (mockup v2.1).
class _TopSpendCard extends StatelessWidget {
  const _TopSpendCard({required this.rows});

  final List<TxWithCategory> rows;

  @override
  Widget build(BuildContext context) {
    final byParty = <String, ({int total, int count, Category? cat})>{};
    for (final r in rows) {
      if (r.tx.direction != Direction.outgoing) continue;
      if (r.tx.kind == TxKind.transfer) continue;
      final name =
          (r.tx.counterparty != null && r.tx.counterparty!.trim().isNotEmpty)
              ? r.tx.counterparty!.trim()
              : (r.tx.rawTitle?.trim().isNotEmpty == true
                    ? r.tx.rawTitle!.trim()
                    : '(tanpa nama)');
      final prev = byParty[name];
      byParty[name] = (
        total: (prev?.total ?? 0) + r.tx.amount,
        count: (prev?.count ?? 0) + 1,
        cat: r.category ?? prev?.cat,
      );
    }
    final top = byParty.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    if (top.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Spacing.m),
      child: QuestCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Keluar terbesar', style: context.qTitle()),
            const SizedBox(height: Spacing.s),
            for (final e in top.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.xs),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (e.value.cat == null
                                ? context.q.muted
                                : SeedColors.categoryColor(
                                    e.value.cat!.colorIndex,
                                  ))
                            .withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        e.key[0].toUpperCase(),
                        style: context.qSmall(13).copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: Spacing.s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.key,
                            overflow: TextOverflow.ellipsis,
                            style: context.qTitle(13),
                          ),
                          Text(
                            '${e.value.count} kali'
                            '${e.value.cat != null ? ' · ${e.value.cat!.name}' : ''}',
                            style: context.qSmall(11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Spacing.s),
                    Text(
                      '−${Money.format(e.value.total)}',
                      style: context.qTitle(13).copyWith(
                            color: context.q.bad,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bucket {
  const _Bucket(this.label, this.categoryId, this.amount, this.color);

  final String label;
  final int? categoryId;
  final int amount;
  final Color color;
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
