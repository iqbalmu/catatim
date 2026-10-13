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
/// Tap membuka Rencana·Batas.
class AlertStrip extends StatelessWidget {
  const AlertStrip({
    super.key,
    required this.repository,
    required this.service,
    this.onOpenBatas,
  });

  final LedgerRepository repository;
  final ProgressService service;

  /// Deep-link ke Rencana·Batas (diisi Beranda). Null = layar Anggaran lama.
  final VoidCallback? onOpenBatas;

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
                onOpenBatas: onOpenBatas,
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
    this.onOpenBatas,
  });

  final LimitLine line;
  final LedgerRepository repository;
  final ProgressService service;
  final VoidCallback? onOpenBatas;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final over = line.level == BudgetLevel.over;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.m),
      child: QuestPress(
        onTap:
            onOpenBatas ??
            () => Navigator.push(
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

/// Pita Jejak Duit: 30 titik hari aktif dari data streak — rantai visual
/// yang tak ingin diputus. Tanpa query tambahan.
class JejakStrip extends StatelessWidget {
  const JejakStrip({super.key, required this.service});

  final ProgressService service;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final p = service.latest;
        if (p == null) return const SizedBox.shrink();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final active = p.activeDays;
        return QuestCard(
          radius: 18,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('JEJAK 30 HARI', style: context.qEyebrow()),
                  const Spacer(),
                  Text(
                    '${active.length}/30',
                    style: context.qSmall(11),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.s),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 29; i >= 0; i--)
                    _JejakDot(
                      day: today.subtract(Duration(days: i)),
                      today: today,
                      active: active,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _JejakDot extends StatelessWidget {
  const _JejakDot({
    required this.day,
    required this.today,
    required this.active,
  });

  final DateTime day;
  final DateTime today;
  final Set<DateTime> active;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final isToday = day == today;
    final on = active.contains(day);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: on ? q.honey : q.surface2,
        shape: BoxShape.circle,
        border: isToday && !on ? Border.all(color: q.text, width: 1.5) : null,
      ),
    );
  }
}

/// Pita kewajiban: bon belum lunas (jumlah + umur tertua + total).
/// Tap → tab Bon. Kosong → hilang agar dashboard tenang.
class KewajibanStrip extends StatelessWidget {
  const KewajibanStrip({
    super.key,
    required this.repository,
    required this.onOpenBon,
  });

  final LedgerRepository repository;
  final VoidCallback onOpenBon;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Bon>>(
      stream: repository.watchBons(),
      builder: (context, snap) {
        final open = [
          for (final b in snap.data ?? const <Bon>[])
            if (b.settledAt == null) b,
        ];
        if (open.isEmpty) return const SizedBox.shrink();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        var oldest = open.first.occurredAt;
        var total = 0;
        for (final b in open) {
          if (b.occurredAt.isBefore(oldest)) oldest = b.occurredAt;
          total += b.amount;
        }
        final age = today
            .difference(DateTime(oldest.year, oldest.month, oldest.day))
            .inDays;
        return Padding(
          padding: const EdgeInsets.only(bottom: Spacing.m),
          child: QuestPress(
            onTap: onOpenBon,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: context.q.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: context.q.shadow,
                    offset: const Offset(0, 6),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.handshake_outlined,
                    size: 18,
                    color: context.q.text,
                  ),
                  const SizedBox(width: Spacing.s),
                  Expanded(
                    child: Text(
                      '${open.length} bon · tertua $age hari · '
                      '${Money.format(total)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: context.q.muted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Kartu ke mana perginya: 3 bar kategori terbesar bulan ini.
/// Tap → Laporan.
class KategoriCard extends StatelessWidget {
  const KategoriCard({
    super.key,
    required this.repository,
    required this.onOpenReports,
  });

  final LedgerRepository repository;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);
    return QuestCard(
      onTap: onOpenReports,
      radius: 18,
      padding: const EdgeInsets.all(12),
      child: StreamBuilder<Map<({int? category, int? account}), int>>(
        stream: repository.watchOutPairsBetween(monthStart, monthEnd),
        builder: (context, usageSnap) {
          return StreamBuilder<List<Category>>(
            stream: repository.watchCategories(),
            builder: (context, catSnap) {
              final rows = _topRows(usageSnap.data, catSnap.data);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('KE MANA PERGINYA', style: context.qEyebrow()),
                  const SizedBox(height: Spacing.s),
                  if (rows.isEmpty)
                    Text(
                      'Belum ada pengeluaran bulan ini.',
                      style: context.qSmall(),
                    ),
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: r.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: Spacing.s),
                          SizedBox(
                            width: 86,
                            child: Text(
                              r.name,
                              style: context.qSmall(12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            child: QuestBar(
                              value: r.fraction,
                              height: 8,
                              color: r.color,
                            ),
                          ),
                          const SizedBox(width: Spacing.s),
                          SizedBox(
                            width: 64,
                            child: Text(
                              _shortMoney(r.total),
                              style: context.qSmall(12),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
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

class _TopRow {
  const _TopRow({
    required this.name,
    required this.total,
    required this.color,
    required this.fraction,
  });

  final String name;
  final int total;
  final Color color;
  final double fraction;
}

List<_TopRow> _topRows(
  Map<({int? category, int? account}), int>? usage,
  List<Category>? categories,
) {
  if (usage == null || categories == null) return const [];
  final byId = {for (final c in categories) c.id: c};
  final byCategory = <int, int>{};
  for (final e in usage.entries) {
    final cat = e.key.category;
    if (cat == null) continue;
    byCategory.update(cat, (v) => v + e.value, ifAbsent: () => e.value);
  }
  if (byCategory.isEmpty) return const [];
  final sorted = byCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final maxValue = sorted.first.value;
  return [
    for (final e in sorted.take(3))
      _TopRow(
        name: byId[e.key]?.name ?? 'Lainnya',
        total: e.value,
        color: SeedColors.categoryColor(byId[e.key]?.colorIndex ?? 8),
        fraction: maxValue == 0 ? 0 : e.value / maxValue,
      ),
  ];
}

/// Kartu batas Beranda (HARIAN/MINGGUAN/BULANAN): sisa besar + bar fraksi
/// + sub "dipakai X dari Y · reset …". Tap → Rencana·Batas (via [onTap]).
class LimitCard extends StatelessWidget {
  const LimitCard({
    super.key,
    required this.label,
    required this.limit,
    required this.used,
    required this.safe,
    required this.onTap,
  });

  /// Judul periode: 'HARIAN', 'MINGGUAN', atau 'BULANAN'.
  final String label;

  /// Plafon rupiah; null/<=0 = tanpa batas.
  final int? limit;

  /// Terpakai efektif (belanja murni + sisihan pos target).
  final int used;

  /// Sisa = limit - used; negatif = OVER. Diabaikan bila tanpa batas.
  final int safe;

  final VoidCallback onTap;

  String get _reset {
    final upper = label.toUpperCase();
    if (upper.contains('MINGGU')) return 'reset Senin';
    if (upper.contains('BULAN')) return 'reset tanggal 1';
    return 'reset tengah malam';
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final line = LimitLine(label: label, used: used, limit: limit);
    final hasLimit = limit != null && limit! > 0;
    final over = hasLimit && safe < 0;
    final barColor = switch (line.level) {
      BudgetLevel.over => q.bad,
      BudgetLevel.warning => q.honey,
      BudgetLevel.ok => q.good,
    };
    return QuestCard(
      onTap: onTap,
      radius: 18,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.qEyebrow()),
          const SizedBox(height: 2),
          Text(
            hasLimit
                ? (over
                      ? '${Money.format(safe)} · OVER'
                      : 'Sisa ${Money.format(safe)}')
                : 'Tanpa batas',
            style: context.qTitle(22).copyWith(
                  color: over
                      ? q.bad
                      : hasLimit
                          ? q.text
                          : q.muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          const SizedBox(height: 6),
          QuestBar(value: line.fraction, height: 8, color: barColor),
          const SizedBox(height: 4),
          Text(
            hasLimit
                ? 'dipakai ${Money.format(used)} dari '
                    '${Money.format(limit!)} · $_reset'
                : 'Belum ada batas · ketuk untuk atur',
            style: context.qSmall(11),
          ),
        ],
      ),
    );
  }
}

/// Ringkas keluar + masuk bulan berjalan: nominal + delta vs bulan lalu.
/// Tap → Rekap (via [onTap]).
class MiniInOut extends StatelessWidget {
  const MiniInOut({super.key, required this.service, this.onTap});

  final ProgressService service;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final snap = service.latest;
        if (snap == null) {
          return const QuestCard(
            radius: 18,
            padding: EdgeInsets.all(12),
            child: SizedBox(height: 64),
          );
        }
        final shot = snap.snapshot;
        final now = DateTime.now();
        final lastShort = idMonthsShort[(now.month + 10) % 12];
        final q = context.q;
        return QuestCard(
          onTap: onTap,
          radius: 18,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: _MiniSide(
                  label: 'KELUAR',
                  amount: snap.monthOut,
                  previous: shot.lastMonthOut,
                  lastShort: lastShort,
                  incoming: false,
                ),
              ),
              const SizedBox(width: Spacing.s),
              Container(width: 1, height: 48, color: q.line),
              const SizedBox(width: Spacing.s),
              Expanded(
                child: _MiniSide(
                  label: 'MASUK',
                  amount: snap.monthIn,
                  previous: shot.lastMonthIn,
                  lastShort: lastShort,
                  incoming: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniSide extends StatelessWidget {
  const _MiniSide({
    required this.label,
    required this.amount,
    required this.previous,
    required this.lastShort,
    required this.incoming,
  });

  final String label;
  final int amount;
  final int previous;
  final String lastShort;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final delta = deltaLabel(amount, previous);
    final up = previous > 0 && amount > previous;
    final down = previous > 0 && amount < previous;
    final deltaColor = delta == null
        ? q.muted
        : up
            ? (incoming ? q.good : q.bad)
            : down
                ? (incoming ? q.bad : q.good)
                : q.muted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.qEyebrow()),
        const SizedBox(height: 2),
        Text(
          Money.format(amount),
          style: context.qTitle(19).copyWith(
                color: incoming ? q.good : q.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
        const SizedBox(height: 2),
        Text(
          delta == null ? 'bulan pertama' : '$delta · $lastShort',
          style: context.qSmall(11).copyWith(color: deltaColor),
        ),
      ],
    );
  }
}

/// Baris SALDO Beranda: total + ringkas per akun. Tap → Kelola Akun.
class SaldoRow extends StatelessWidget {
  const SaldoRow({super.key, required this.repository});

  final LedgerRepository repository;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AccountManageScreen(repository: repository),
        ),
      ),
      radius: 18,
      padding: const EdgeInsets.all(12),
      child: StreamBuilder<List<Account>>(
        stream: repository.watchAccounts(),
        builder: (context, accSnap) {
          return StreamBuilder<Map<int, int>>(
            stream: repository.watchAccountBalances(),
            builder: (context, balSnap) {
              final accounts = accSnap.data ?? const <Account>[];
              final balances = balSnap.data ?? const <int, int>{};
              final total = balances.values.fold(0, (a, b) => a + b);
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SALDO', style: context.qEyebrow()),
                        const SizedBox(height: 2),
                        Text(
                          Money.format(total),
                          style: context.qTitle(19).copyWith(
                                color: total < 0 ? q.bad : q.text,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
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
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: q.muted,
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
