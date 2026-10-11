import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/budget.dart';
import '../core/money.dart';
import '../models.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Layar Anggaran: batas harian/mingguan/bulanan, alokasi dana per
/// kategori, dan progres masuk/keluar bulan ini vs bulan lalu.
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key, required this.repository});

  final LedgerRepository repository;

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  int? _dailyLimit;
  int? _weeklyLimit;
  int? _monthlyTotal;

  @override
  void initState() {
    super.initState();
    _loadLimits();
  }

  Future<void> _loadLimits() async {
    final daily = int.tryParse(
      await widget.repository.getSetting(kKeyDailyLimit) ?? '',
    );
    final weekly = int.tryParse(
      await widget.repository.getSetting(kKeyWeeklyLimit) ?? '',
    );
    final monthly = int.tryParse(
      await widget.repository.getSetting(kKeyMonthlyTotal) ?? '',
    );
    if (!mounted) return;
    setState(() {
      _dailyLimit = daily;
      _weeklyLimit = weekly;
      _monthlyTotal = monthly;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);
    final lastMonthStart = DateTime(now.year, now.month - 1);
    final lastMonthEnd = lastMonthStart.add(monthEnd.difference(monthStart));

    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: const QuestHeader(
        title: 'Anggaran',
        subtitle: 'Alokasi dana & batas pengeluaran',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.l,
        ),
        children: [
          Text('Batas pengeluaran', style: context.qEyebrow()),
          const SizedBox(height: Spacing.s),
          _LimitRow(
            label: 'Batas harian',
            hint: 'Maks keluar per hari',
            value: _dailyLimit,
            onEdit: () => _editLimit(
              title: 'Batas harian',
              current: _dailyLimit,
              save: (v) async {
                await _saveLimit(kKeyDailyLimit, v);
                setState(() => _dailyLimit = v);
              },
            ),
          ),
          _LimitRow(
            label: 'Batas mingguan',
            hint: 'Maks keluar per minggu',
            value: _weeklyLimit,
            onEdit: () => _editLimit(
              title: 'Batas mingguan',
              current: _weeklyLimit,
              save: (v) async {
                await _saveLimit(kKeyWeeklyLimit, v);
                setState(() => _weeklyLimit = v);
              },
            ),
          ),
          _LimitRow(
            label: 'Total bulanan',
            hint: 'Maks keluar sebulan',
            value: _monthlyTotal,
            onEdit: () => _editLimit(
              title: 'Total bulanan',
              current: _monthlyTotal,
              save: (v) async {
                await _saveLimit(kKeyMonthlyTotal, v);
                setState(() => _monthlyTotal = v);
              },
            ),
          ),
          const SizedBox(height: Spacing.m),
          Text('Alokasi dana per kategori', style: context.qEyebrow()),
          const SizedBox(height: Spacing.s),
          StreamBuilder<List<Category>>(
            stream: widget.repository.watchCategories(),
            builder: (context, catSnap) {
              return StreamBuilder<List<Budget>>(
                stream: widget.repository.watchBudgets(),
                builder: (context, budgetSnap) {
                  return StreamBuilder<Map<int?, int>>(
                    stream: widget.repository.watchOutByCategoryBetween(
                      monthStart,
                      monthEnd,
                    ),
                    builder: (context, usedSnap) {
                      final categories = catSnap.data ?? const <Category>[];
                      final budgets = {
                        for (final b in budgetSnap.data ?? const <Budget>[])
                          b.categoryId: b.monthlyLimit,
                      };
                      final used = usedSnap.data ?? const <int?, int>{};
                      if (categories.isEmpty) {
                        return const QuestSkeleton(rows: 2);
                      }
                      return Column(
                        children: [
                          for (final c in categories) ...[
                            _AllocationRow(
                              name: c.name,
                              used: used[c.id] ?? 0,
                              limit: budgets[c.id],
                              onEdit: () => _editAllocation(c, budgets[c.id]),
                            ),
                            const SizedBox(height: Spacing.s),
                          ],
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: Spacing.m),
          Text('Progres bulan ini', style: context.qEyebrow()),
          const SizedBox(height: Spacing.s),
          StreamBuilder<int>(
            stream: widget.repository.watchSumBetween(
              monthStart,
              monthEnd,
              Direction.incoming,
            ),
            builder: (context, snap) => StreamBuilder<int>(
              stream: widget.repository.watchSumBetween(
                monthStart,
                monthEnd,
                Direction.outgoing,
              ),
              builder: (context, outSnap) => StreamBuilder<int>(
                stream: widget.repository.watchSumBetween(
                  lastMonthStart,
                  lastMonthEnd,
                  Direction.incoming,
                ),
                builder: (context, lastInSnap) => StreamBuilder<int>(
                  stream: widget.repository.watchSumBetween(
                    lastMonthStart,
                    lastMonthEnd,
                    Direction.outgoing,
                  ),
                  builder: (context, lastOutSnap) {
                    final monthIn = snap.data ?? 0;
                    final monthOut = outSnap.data ?? 0;
                    final lastIn = lastInSnap.data ?? 0;
                    final lastOut = lastOutSnap.data ?? 0;
                    return Row(
                      children: [
                        Expanded(
                          child: _ProgressCard(
                            label: 'Masuk',
                            amount: monthIn,
                            previous: lastIn,
                            incoming: true,
                          ),
                        ),
                        const SizedBox(width: Spacing.s),
                        Expanded(
                          child: _ProgressCard(
                            label: 'Keluar',
                            amount: monthOut,
                            previous: lastOut,
                            incoming: false,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveLimit(String key, int? value) async {
    if (value == null) {
      // Tidak ada API hapus setting — simpan kosong agar tak terbaca.
      await widget.repository.setSetting(key, '');
      return;
    }
    await widget.repository.setSetting(key, '$value');
  }

  Future<void> _editLimit({
    required String title,
    required int? current,
    required Future<void> Function(int?) save,
  }) async {
    final value = await _askAmount(
      context,
      title: title,
      current: current,
      emptyMeansRemove: true,
    );
    if (value == null && current == null) return;
    if (!mounted) return;
    await save(value);
    if (!mounted) return;
    questSnack(
      context,
      value == null ? '$title dihapus.' : '$title disimpan.',
      icon: Icons.check_rounded,
    );
  }

  Future<void> _editAllocation(Category category, int? current) async {
    final value = await _askAmount(
      context,
      title: 'Alokasi ${category.name}',
      current: current,
      emptyMeansRemove: true,
    );
    if (value == null && current == null) return;
    if (!mounted) return;
    if (value == null) {
      await widget.repository.removeBudget(category.id);
    } else {
      await widget.repository.setBudget(category.id, value);
    }
    if (!mounted) return;
    questSnack(
      context,
      value == null
          ? 'Alokasi ${category.name} dihapus.'
          : 'Alokasi ${category.name} disimpan.',
      icon: Icons.check_rounded,
    );
  }
}

/// Dialog input nominal rupiah. Kosong + [emptyMeansRemove] → null (hapus).
/// Tutup dialog tanpa menyimpan → mengembalikan sentinel `cancelled`.
Future<int?> _askAmount(
  BuildContext context, {
  required String title,
  required int? current,
  required bool emptyMeansRemove,
}) {
  final ctrl = TextEditingController(text: current == null ? '' : '$current');
  const cancelled = -1;
  return showQuestDialog<int>(
    context,
    title: title,
    content: TextField(
      controller: ctrl,
      autofocus: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: 'Nominal (rupiah)',
        hintText: emptyMeansRemove ? 'Kosongkan untuk hapus' : 'Contoh: 500000',
      ),
    ),
    actions: [
      QuestButton(
        label: 'Batal',
        tone: QuestTone.secondary,
        onPressed: () => Navigator.pop(context, cancelled),
      ),
      QuestButton(
        label: 'Simpan',
        icon: Icons.check_rounded,
        onPressed: () => Navigator.pop(
          context,
          ctrl.text.trim().isEmpty ? null : Money.parseGroup(ctrl.text),
        ),
      ),
    ],
  ).then((value) => value == cancelled ? current : value);
}

class _LimitRow extends StatelessWidget {
  const _LimitRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.onEdit,
  });

  final String label;
  final String hint;
  final int? value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestPress(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: Spacing.s),
        decoration: BoxDecoration(
          color: q.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: q.line, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.qTitle(14)),
                  Text(hint, style: TextStyle(color: q.muted, fontSize: 11)),
                ],
              ),
            ),
            Text(
              value == null ? 'Tidak diatur' : Money.format(value!),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: value == null ? q.muted : q.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: Spacing.s),
            Icon(Icons.edit_rounded, size: 18, color: q.muted),
          ],
        ),
      ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({
    required this.name,
    required this.used,
    required this.limit,
    required this.onEdit,
  });

  final String name;
  final int used;
  final int? limit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final line = LimitLine(label: name, used: used, limit: limit);
    return QuestPress(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: Spacing.s),
        decoration: BoxDecoration(
          color: q.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: line.level == BudgetLevel.over ? q.bad : q.line,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(name, style: context.qTitle(14))),
                Text(
                  limit == null
                      ? 'Belum dialokasikan · terpakai ${Money.format(used)}'
                      : '${Money.format(used)} / ${Money.format(limit!)}'
                            ' (${line.usedPercent}%)',
                  style: TextStyle(
                    fontSize: 12,
                    color: line.level == BudgetLevel.over ? q.bad : q.muted,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.s),
            QuestBar(
              value: line.fraction,
              height: 10,
              color: switch (line.level) {
                BudgetLevel.over => q.bad,
                BudgetLevel.warning => q.honey,
                BudgetLevel.ok => q.good,
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.label,
    required this.amount,
    required this.previous,
    required this.incoming,
  });

  final String label;
  final int amount;
  final int previous;
  final bool incoming;

  /// Masuk naik = membaik; keluar naik = memburuk. Toleransi ±5% = datar.
  TrendDirection _trend() {
    final (current, baseline) = incoming
        ? (amount, previous)
        : (previous, amount);
    if (current <= 0 && baseline <= 0) return TrendDirection.flat;
    if (baseline <= 0) {
      return incoming ? TrendDirection.better : TrendDirection.worse;
    }
    if (current >= baseline * 1.05) {
      return incoming ? TrendDirection.better : TrendDirection.worse;
    }
    if (current <= baseline * 0.95) {
      return incoming ? TrendDirection.worse : TrendDirection.better;
    }
    return TrendDirection.flat;
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final trend = _trend();
    final good = trend == TrendDirection.better;
    final color = trend == TrendDirection.flat
        ? q.muted
        : good
        ? q.good
        : q.bad;
    final icon = switch (trend) {
      TrendDirection.better => Icons.trending_up_rounded,
      TrendDirection.worse => Icons.trending_down_rounded,
      TrendDirection.flat => Icons.trending_flat_rounded,
    };
    return QuestCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.qEyebrow()),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(Money.format(amount), style: context.qDisplay(22)),
          ),
          const SizedBox(height: Spacing.s),
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'bulan lalu: ${Money.format(previous)}',
                  style: TextStyle(fontSize: 11, color: q.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
