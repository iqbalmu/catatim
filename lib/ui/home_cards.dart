import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/budget.dart';
import '../core/dates_id.dart';
import '../core/money.dart';
import '../game/progress.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'account_manage_screen.dart';
import 'budget_screen.dart';
import 'quest.dart';

/// Strip peringatan + ubin dashboard beranda: saldo, tren, keluar, masuk.
/// Semua mengalir via stream/service sehingga selalu segar.

/// Strip peringatan garis anggaran kritis — persisten sampai selesai.
/// Tap membuka layar Anggaran.
class AlertStrip extends StatelessWidget {
  const AlertStrip({
    super.key,
    required this.repository,
    required this.service,
  });

  final LedgerRepository repository;
  final ProgressService service;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final snap = service.latest?.snapshot;
        final critical = [
          if (snap != null) ...snap.overLines,
          if (snap != null) ...snap.warningLines,
        ].take(2).toList();
        if (critical.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final line in critical)
              _AlertRow(
                line: line,
                repository: repository,
                service: service,
              ),
          ],
        );
      },
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.line,
    required this.repository,
    required this.service,
  });

  final LimitLine line;
  final LedgerRepository repository;
  final ProgressService service;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final over = line.level == BudgetLevel.over;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.s),
      child: QuestPress(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BudgetScreen(repository: repository),
          ),
        ).whenComplete(service.refresh),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: over
                ? q.bad.withValues(alpha: 0.12)
                : q.honey.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                over
                    ? Icons.error_outline_rounded
                    : Icons.warning_amber_rounded,
                size: 18,
                color: over ? q.bad : q.honeyInk,
              ),
              const SizedBox(width: Spacing.s),
              Expanded(
                child: Text(
                  '${line.label}: ${Money.format(line.used)} / '
                  '${Money.format(line.limit!)} (${line.usedPercent}%)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: over ? q.bad : q.honeyInk,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: over ? q.bad : q.honeyInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ubin dashboard: kartu putih kompak.
class _Tile extends StatelessWidget {
  const _Tile({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return QuestCard(
      onTap: onTap,
      radius: 18,
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

/// Ubin saldo: total + ringkas per akun. Tap → Kelola Akun.
class SaldoTile extends StatelessWidget {
  const SaldoTile({super.key, required this.repository});

  final LedgerRepository repository;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AccountManageScreen(repository: repository),
        ),
      ),
      child: StreamBuilder<List<Account>>(
        stream: repository.watchAccounts(),
        builder: (context, accSnap) {
          return StreamBuilder<Map<int, int>>(
            stream: repository.watchAccountBalances(),
            builder: (context, balSnap) {
              final accounts = accSnap.data ?? const <Account>[];
              final balances = balSnap.data ?? const <int, int>{};
              final total = balances.values.fold(0, (a, b) => a + b);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SALDO', style: context.qEyebrow()),
                  const SizedBox(height: 2),
                  Text(
                    Money.format(total),
                    style: context.qTitle(19).copyWith(
                          color: total < 0 ? context.q.bad : context.q.text,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    accounts.isEmpty
                        ? 'Belum ada akun'
                        : accounts
                            .map((a) =>
                                '${a.name} ${_shortMoney(balances[a.id] ?? 0)}')
                            .join(' · '),
                    style: context.qSmall(11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Ubin tren 7 hari: sparkline + kategori teratas. Tap → Laporan.
class TrendTile extends StatelessWidget {
  const TrendTile({
    super.key,
    required this.repository,
    required this.onOpenReports,
  });

  final LedgerRepository repository;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);

    return _Tile(
      onTap: onOpenReports,
      child: StreamBuilder<Map<DateTime, int>>(
        stream: repository.watchOutSumByDaySince(
          today.subtract(const Duration(days: 6)),
        ),
        builder: (context, sumsSnap) {
          return StreamBuilder<Map<({int? category, int? account}), int>>(
            stream: repository.watchOutPairsBetween(monthStart, monthEnd),
            builder: (context, usageSnap) {
              return StreamBuilder<List<Category>>(
                stream: repository.watchCategories(),
                builder: (context, catSnap) {
                  final sums = sumsSnap.data ?? const <DateTime, int>{};
                  final points = [
                    for (var i = 0; i < 7; i++)
                      sums[today.subtract(Duration(days: i))] ?? 0,
                  ].reversed.toList();
                  final top = _topOne(usageSnap.data, catSnap.data);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TREN 7 HARI', style: context.qEyebrow()),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 30,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _Sparkline(
                            points: points,
                            line: context.q.honey,
                            base: context.q.line,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        top == null
                            ? 'Belum ada data'
                            : '${top.name} ${_shortMoney(top.total)}',
                        style: context.qSmall(11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Ubin keluar bulan ini: nominal + delta vs bulan lalu + bar anggaran.
/// Tap → Anggaran.
class OutTile extends StatelessWidget {
  const OutTile({
    super.key,
    required this.service,
    required this.onOpenBudget,
  });

  final ProgressService service;
  final VoidCallback onOpenBudget;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final snap = service.latest;
        if (snap == null) {
          return const _Tile(onTap: null, child: SizedBox(height: 64));
        }
        final shot = snap.snapshot;
        final now = DateTime.now();
        final lastShort = idMonthsShort[(now.month + 10) % 12];
        final delta = deltaLabel(snap.monthOut, shot.lastMonthOut);
        final up =
            shot.lastMonthOut > 0 && snap.monthOut > shot.lastMonthOut;
        final down =
            shot.lastMonthOut > 0 && snap.monthOut < shot.lastMonthOut;
        final worst = heroBudgetLine(shot);
        final q = context.q;
        return _Tile(
          onTap: onOpenBudget,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KELUAR', style: context.qEyebrow()),
              const SizedBox(height: 2),
              Text(
                Money.format(snap.monthOut),
                style: context.qTitle(19),
              ),
              const SizedBox(height: 2),
              Text(
                delta == null ? 'bulan pertama' : '$delta · $lastShort',
                style: context.qSmall(11).copyWith(
                      color: delta == null
                          ? q.muted
                          : up
                              ? q.bad
                              : down
                                  ? q.good
                                  : q.muted,
                    ),
              ),
              if (worst != null) ...[
                const SizedBox(height: 6),
                QuestBar(
                  value: worst.fraction,
                  height: 6,
                  color: switch (worst.level) {
                    BudgetLevel.over => q.bad,
                    BudgetLevel.warning => q.honey,
                    BudgetLevel.ok => q.good,
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Ubin masuk bulan ini: nominal + delta vs bulan lalu.
class InTile extends StatelessWidget {
  const InTile({super.key, required this.service});

  final ProgressService service;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final snap = service.latest;
        if (snap == null) {
          return const _Tile(onTap: null, child: SizedBox(height: 64));
        }
        final shot = snap.snapshot;
        final now = DateTime.now();
        final lastShort = idMonthsShort[(now.month + 10) % 12];
        final delta = deltaLabel(snap.monthIn, shot.lastMonthIn);
        final up = shot.lastMonthIn > 0 && snap.monthIn > shot.lastMonthIn;
        final down =
            shot.lastMonthIn > 0 && snap.monthIn < shot.lastMonthIn;
        final q = context.q;
        return _Tile(
          onTap: null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MASUK', style: context.qEyebrow()),
              const SizedBox(height: 2),
              Text(
                Money.format(snap.monthIn),
                style: context.qTitle(19).copyWith(color: q.good),
              ),
              const SizedBox(height: 2),
              Text(
                delta == null ? 'bulan pertama' : '$delta · $lastShort',
                style: context.qSmall(11).copyWith(
                      color: delta == null
                          ? q.muted
                          : up
                              ? q.good
                              : down
                                  ? q.bad
                                  : q.muted,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Rupiah ringkas untuk ruang sempit: -Rp78.000 → '-78rb',
/// Rp11.002.000 → '11,0jt'.
String _shortMoney(int v) {
  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  if (a >= 1000000) {
    final jt = a / 1000000;
    final s = jt >= 10
        ? jt.round().toString()
        : jt.toStringAsFixed(1).replaceFirst('.', ',');
    return '$sign${s}jt';
  }
  if (a >= 1000) return '$sign${(a / 1000).round()}rb';
  return Money.format(v);
}

/// Kategori keluar terbesar bulan berjalan; null bila kosong.
({String name, int total})? _topOne(
  Map<({int? category, int? account}), int>? usage,
  List<Category>? categories,
) {
  if (usage == null || categories == null) return null;
  final names = {for (final c in categories) c.id: c.name};
  final byCategory = <int, int>{};
  for (final e in usage.entries) {
    final cat = e.key.category;
    if (cat == null) continue;
    byCategory.update(cat, (v) => v + e.value, ifAbsent: () => e.value);
  }
  if (byCategory.isEmpty) return null;
  final top = byCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final first = top.first;
  return (name: names[first.key] ?? 'Lainnya', total: first.value);
}

class _Sparkline extends CustomPainter {
  const _Sparkline({
    required this.points,
    required this.line,
    required this.base,
  });

  final List<int> points;
  final Color line;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = base
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      basePaint,
    );
    if (points.isEmpty) return;

    final maxValue = points.fold(0, (a, b) => math.max(a, b));
    Offset pointAt(int i) {
      final x = points.length == 1
          ? size.width / 2
          : size.width * i / (points.length - 1);
      final y = maxValue == 0
          ? size.height - 2
          : size.height - 2 - (size.height - 6) * points[i] / maxValue;
      return Offset(x, y);
    }

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(pointAt(i).dx, pointAt(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Sparkline oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.line != line ||
      oldDelegate.base != base;
}
