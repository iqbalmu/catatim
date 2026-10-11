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
              final accounts = accSnap.data ?? const <Account>[];
              final balances = balSnap.data ?? const <int, int>{};
              if (accSnap.connectionState == ConnectionState.waiting) {
                return const QuestSkeleton(height: 70, rows: 1);
              }
              final total = balances.values.fold(0, (a, b) => a + b);

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
                          FutureBuilder<Color>(
                            future: _dotColor(context, account.id),
                            builder: (context, dot) => Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: dot.data ?? context.q.line,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: Spacing.s),
                          Expanded(
                            child: Text(account.name, style: context.qSmall(13)),
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
      ),
    );
  }

  /// Warna dot alokasi akun: level terburuk alokasi yang di-scope ke
  /// akun itu; abu-abu bila akun tanpa alokasi ber-scope.
  Future<Color> _dotColor(BuildContext context, int accountId) async {
    final q = context.q;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);
    final results = await Future.wait([
      repository.watchBudgets().first,
      repository.outPairsBetween(monthStart, monthEnd),
    ]);
    final budgets = results[0] as List<Budget>;
    final usage = results[1] as Map<({int? category, int? account}), int>;
    final level = accountBudgetLevel(
      budgets: budgets
          .map((b) => (
                categoryId: b.categoryId,
                accountId: b.accountId,
                monthlyLimit: b.monthlyLimit,
              ))
          .toList(),
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
  late Future<_InsightData> _future = _load();

  Future<_InsightData> _load() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);
    final sums = await widget.repository.outSumByDaySince(
      today.subtract(Duration(days: _windowDays - 1)),
    );
    final usage =
        await widget.repository.outPairsBetween(monthStart, monthEnd);
    final categories = await widget.repository.watchCategories().first;
    final names = {for (final c in categories) c.id: c.name};
    final byCategory = <int, int>{};
    for (final e in usage.entries) {
      final cat = e.key.category;
      if (cat == null) continue;
      byCategory.update(cat, (v) => v + e.value, ifAbsent: () => e.value);
    }
    final top = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _InsightData(
      sums: sums,
      today: today,
      topCategories: [
        for (final e in top.take(3))
          (name: names[e.key] ?? 'Lainnya', total: e.value),
      ],
    );
  }

  void _setWindow(int days) {
    setState(() {
      _windowDays = days;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return QuestCard(
      onTap: widget.onOpenReports,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('TREN KELUAR', style: context.qEyebrow()),
              const Spacer(),
              QuestSegmented<int>(
                options: const [
                  (value: 7, label: '7 hari', icon: null),
                  (value: 30, label: '30 hari', icon: null),
                ],
                selected: _windowDays,
                onChanged: _setWindow,
              ),
            ],
          ),
          const SizedBox(height: Spacing.s),
          FutureBuilder<_InsightData>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const QuestSkeleton(height: 96, rows: 1);
              }
              final data = snap.data;
              if (data == null) {
                return Text('Data belum tersedia.', style: context.qSmall());
              }
              final points = [
                for (var i = 0; i < _windowDays; i++)
                  data.sums[data.today.subtract(Duration(days: _windowDays - 1 - i))] ?? 0,
              ];
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
                  for (final cat in data.topCategories)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(cat.name, style: context.qSmall(13)),
                          ),
                          Text(
                            Money.format(cat.total),
                            style: context.qSmall(13),
                          ),
                        ],
                      ),
                    ),
                  if (data.topCategories.isEmpty)
                    Text('Belum ada pengeluaran bulan ini.',
                        style: context.qSmall()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InsightData {
  const _InsightData({
    required this.sums,
    required this.today,
    required this.topCategories,
  });

  final Map<DateTime, int> sums;
  final DateTime today;
  final List<({String name, int total})> topCategories;
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
