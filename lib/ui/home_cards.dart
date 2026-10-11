import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/budget.dart';
import '../core/money.dart';
import '../game/progress.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'account_manage_screen.dart';
import 'quest.dart';

/// Tiga kartu beranda di bawah hero maskot: pace harian (kartu utama),
/// saldo per akun, dan insight mini. Gaya mengikuti hero card.
///
/// Pace Card menjawab "boleh habis berapa hari ini?", Saldo Card
/// "uangku di mana?", Insight Card menjembatani ke tab Laporan.
/// Saldo & insight mengalir via drift streams sehingga selalu segar.

class PaceCard extends StatelessWidget {
  const PaceCard({super.key, required this.service});

  final ProgressService service;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final pace = service.latest?.dailyPace;
        if (pace == null) return const QuestSkeleton(height: 96);
        final q = context.q;
        final safe = pace.safeToSpend;
        final over = safe != null && safe < 0;

        return QuestCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SISA AMAN HARI INI', style: context.qEyebrow()),
              const SizedBox(height: Spacing.s),
              if (safe == null)
                Text(
                  'Tanpa batas — atur di menu ⋯ → Anggaran',
                  style: context.qTitle(15).copyWith(color: q.muted),
                )
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: FittedBox(
                        child: Text(
                          Money.format(safe),
                          style: context.qDisplay(34).copyWith(
                                color: over ? q.bad : q.text,
                              ),
                        ),
                      ),
                    ),
                    if (over) ...[
                      const SizedBox(width: Spacing.s),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'OVER',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: q.bad,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: Spacing.s),
              QuestBar(
                value: pace.dayOfMonth / pace.daysInMonth,
                height: 8,
                color: q.honey,
              ),
              const SizedBox(height: 6),
              Text(
                'tgl ${pace.dayOfMonth} · ideal ${pace.idealUsedPercent}%',
                style: context.qSmall(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SaldoCard extends StatelessWidget {
  const SaldoCard({super.key, required this.repository});

  final LedgerRepository repository;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);

    return QuestCard(
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
              return StreamBuilder<List<Budget>>(
                stream: repository.watchBudgets(),
                builder: (context, budgetSnap) {
                  return StreamBuilder<
                      Map<({int? category, int? account}), int>>(
                    stream: repository.watchOutPairsBetween(
                      monthStart,
                      monthEnd,
                    ),
                    builder: (context, usageSnap) {
                      final accounts = accSnap.data ?? const <Account>[];
                      final balances = balSnap.data ?? const <int, int>{};
                      if (accSnap.connectionState == ConnectionState.waiting) {
                        return const QuestSkeleton(height: 70, rows: 1);
                      }
                      final total = balances.values.fold(0, (a, b) => a + b);
                      final allocations = [
                        for (final b in budgetSnap.data ?? const <Budget>[])
                          (
                            categoryId: b.categoryId,
                            accountId: b.accountId,
                            monthlyLimit: b.monthlyLimit,
                          ),
                      ];
                      final usage =
                          usageSnap.data ?? const <({int? category, int? account}), int>{};

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('SALDO', style: context.qEyebrow()),
                              const Spacer(),
                              Text(
                                Money.format(total),
                                style: context.qTitle(17),
                              ),
                            ],
                          ),
                          const SizedBox(height: Spacing.s),
                          for (final account in accounts)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _dotFor(
                                        context,
                                        allocations,
                                        usage,
                                        account.id,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: Spacing.s),
                                  Expanded(
                                    child: Text(
                                      account.name,
                                      style: context.qSmall(13),
                                    ),
                                  ),
                                  Text(
                                    Money.format(balances[account.id] ?? 0),
                                    style: context.qSmall(13),
                                  ),
                                ],
                              ),
                            ),
                          if (accounts.isEmpty)
                            Text('Belum ada akun.', style: context.qSmall()),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Warna dot alokasi akun: level terburuk alokasi yang di-scope ke
  /// akun itu; abu-abu bila akun tanpa alokasi ber-scope.
  Color _dotFor(
    BuildContext context,
    List<CategoryAllocation> allocations,
    Map<({int? category, int? account}), int> usage,
    int accountId,
  ) {
    final q = context.q;
    final level = accountBudgetLevel(
      budgets: allocations,
      usage: usage,
      accountId: accountId,
    );
    return switch (level) {
      BudgetLevel.over => q.bad,
      BudgetLevel.warning => q.honey,
      BudgetLevel.ok => q.good,
      null => q.line,
    };
  }
}

class InsightCard extends StatefulWidget {
  const InsightCard({
    super.key,
    required this.repository,
    required this.onOpenReports,
  });

  final LedgerRepository repository;
  final VoidCallback onOpenReports;

  @override
  State<InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<InsightCard> {
  int _windowDays = 7;

  Stream<Map<DateTime, int>> _sumsStream() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return widget.repository.watchOutSumByDaySince(
      today.subtract(Duration(days: _windowDays - 1)),
    );
  }

  void _setWindow(int days) => setState(() => _windowDays = days);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);
    final today = DateTime(now.year, now.month, now.day);

    return QuestCard(
      onTap: widget.onOpenReports,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('TREN KELUAR', style: context.qEyebrow()),
              const SizedBox(width: Spacing.s),
              Expanded(
                child: QuestSegmented<int>(
                  options: const [
                    (value: 7, label: '7 hari', icon: null),
                    (value: 30, label: '30 hari', icon: null),
                  ],
                  selected: _windowDays,
                  onChanged: _setWindow,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.s),
          StreamBuilder<Map<DateTime, int>>(
            stream: _sumsStream(),
            key: ValueKey(_windowDays),
            builder: (context, sumsSnap) {
              return StreamBuilder<Map<({int? category, int? account}), int>>(
                stream: widget.repository.watchOutPairsBetween(
                  monthStart,
                  monthEnd,
                ),
                builder: (context, usageSnap) {
                  return StreamBuilder<List<Category>>(
                    stream: widget.repository.watchCategories(),
                    builder: (context, catSnap) {
                      if (sumsSnap.connectionState == ConnectionState.waiting ||
                          usageSnap.connectionState ==
                              ConnectionState.waiting ||
                          catSnap.connectionState == ConnectionState.waiting) {
                        return const QuestSkeleton(height: 96, rows: 1);
                      }
                      final sums = sumsSnap.data ?? const <DateTime, int>{};
                      final points = [
                        for (var i = 0; i < _windowDays; i++)
                          sums[today.subtract(Duration(days: i))] ?? 0,
                      ].reversed.toList();
                      final top = _topCategories(usageSnap.data, catSnap.data);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 48,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: _Sparkline(
                                points: points,
                                line: context.q.honey,
                                base: context.q.line,
                              ),
                            ),
                          ),
                          const SizedBox(height: Spacing.s),
                          for (final cat in top)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      cat.name,
                                      style: context.qSmall(13),
                                    ),
                                  ),
                                  Text(
                                    Money.format(cat.total),
                                    style: context.qSmall(13),
                                  ),
                                ],
                              ),
                            ),
                          if (top.isEmpty)
                            Text(
                              'Belum ada pengeluaran bulan ini.',
                              style: context.qSmall(),
                            ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  List<({String name, int total})> _topCategories(
    Map<({int? category, int? account}), int>? usage,
    List<Category>? categories,
  ) {
    if (usage == null || categories == null) return const [];
    final names = {for (final c in categories) c.id: c.name};
    final byCategory = <int, int>{};
    for (final e in usage.entries) {
      final cat = e.key.category;
      if (cat == null) continue;
      byCategory.update(cat, (v) => v + e.value, ifAbsent: () => e.value);
    }
    final top = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in top.take(3)) (name: names[e.key] ?? 'Lainnya', total: e.value),
    ];
  }
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
