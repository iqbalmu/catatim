import 'package:flutter/material.dart';

import '../core/budget.dart';
import '../core/money.dart';
import '../game/mascot.dart';
import '../game/progress.dart';
import '../models.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import '../ui/quest.dart';

/// Hero beranda gaya Playful Rapi: zona madu (Duit + sisa aman hari ini)
/// di atas kartu sekunder ringkasan bulan.
class GameHeroCard extends StatelessWidget {
  const GameHeroCard({
    super.key,
    required this.service,
    required this.repository,
  });

  final ProgressService service;
  final LedgerRepository repository;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final progress = service.latest;
        return Column(
          children: [
            _HeroZone(progress: progress),
            const SizedBox(height: Spacing.s),
            StreamBuilder<List<TxWithCategory>>(
              stream: repository.watchBetweenWithCategory(monthStart, monthEnd),
              builder: (context, snapshot) {
                var incoming = 0;
                var outgoing = 0;
                for (final r in snapshot.data ?? const <TxWithCategory>[]) {
                  if (r.tx.direction == Direction.incoming) {
                    incoming += r.tx.amount;
                  } else {
                    outgoing += r.tx.amount;
                  }
                }
                return QuestCard(
                  radius: 20,
                  child: progress == null
                      ? const SizedBox(height: 96)
                      : _MonthBody(
                          progress: progress,
                          incoming: incoming,
                          outgoing: outgoing,
                        ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Zona madu: Duit + sisa aman hari ini + pill streak.
class _HeroZone extends StatelessWidget {
  const _HeroZone({required this.progress});

  final ProgressSummary? progress;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final p = progress;
    final pace = p?.dailyPace;
    final safe = pace?.safeToSpend;
    final over = safe != null && safe < 0;
    final hasStreak = (p?.streakDays ?? 0) > 0;

    return Container(
      padding: const EdgeInsets.all(Spacing.m),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SeedColors.honey50, SeedColors.honey100],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: p == null || pace == null
          ? const SizedBox(height: 80)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RepaintBoundary(child: Mascot(mood: p.mood, size: 64)),
                const SizedBox(width: Spacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SISA AMAN HARI INI',
                        style: context.qEyebrow().copyWith(color: q.honeyInk),
                      ),
                      const SizedBox(height: 4),
                      if (safe == null)
                        Text(
                          'Tanpa batas',
                          style: context.qTitle(18).copyWith(color: q.muted),
                        )
                      else
                        FittedBox(
                          child: Text(
                            Money.format(safe),
                            style: context.qDisplay(34)
                                .copyWith(color: over ? q.bad : q.text),
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        'tgl ${pace.dayOfMonth} · '
                        'ideal ${pace.idealUsedPercent}%',
                        style: context.qSmall().copyWith(color: q.honeyInk),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.moodLine,
                        style: context.qSmall(12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.s),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: q.surface,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: q.shadow,
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 14,
                        color: hasStreak ? SeedColors.honeyDeep : q.muted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${p.streakDays}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: hasStreak ? q.text : q.muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Kartu sekunder: keluar/masuk bulan + garis anggaran + tren.
class _MonthBody extends StatelessWidget {
  const _MonthBody({
    required this.progress,
    required this.incoming,
    required this.outgoing,
  });

  final ProgressSummary progress;
  final int incoming;
  final int outgoing;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('KELUAR · BULAN INI', style: context.qEyebrow()),
                  const SizedBox(height: 2),
                  Text(Money.format(outgoing), style: context.qTitle(18)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('MASUK', style: context.qEyebrow()),
                const SizedBox(height: 2),
                Text(
                  '+ ${Money.format(incoming)}',
                  style: context.qTitle(18).copyWith(color: q.good),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: Spacing.m),
        _BudgetRow(progress: progress),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.progress});

  final ProgressSummary progress;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final snapshot = progress.snapshot;
    final total = snapshot.lines
        .where((l) => l.label == 'Total bulan ini')
        .firstOrNull;
    final trend = snapshot.outTrend;

    final Color trendColor;
    final IconData trendIcon;
    switch (trend) {
      case TrendDirection.better:
        trendColor = q.good;
        trendIcon = Icons.trending_down_rounded;
      case TrendDirection.worse:
        trendColor = q.bad;
        trendIcon = Icons.trending_up_rounded;
      case TrendDirection.flat:
        trendColor = q.muted;
        trendIcon = Icons.trending_flat_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total?.limit != null) ...[
          QuestBar(
            value: total!.fraction,
            color: switch (total.level) {
              BudgetLevel.over => q.bad,
              BudgetLevel.warning => q.honey,
              BudgetLevel.ok => q.good,
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Anggaran: ${Money.format(total.used)} / '
                '${Money.format(total.limit!)} (${total.usedPercent}%)',
                style: context.qSmall(),
              ),
              const Spacer(),
              if (total.level != BudgetLevel.ok)
                Text(
                  'OVER',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: q.bad,
                  ),
                ),
            ],
          ),
        ] else
          Text(
            'Belum ada anggaran — atur di menu ⋯ → Anggaran',
            style: context.qSmall(),
          ),
        const SizedBox(height: Spacing.s),
        Wrap(
          spacing: Spacing.s,
          runSpacing: Spacing.s,
          children: [
            _TrendChip(
              icon: trendIcon,
              color: trendColor,
              label: 'keluar ${trendLabel(trend, incoming: false)}',
            ),
            _TrendChip(
              icon: Icons.savings_rounded,
              color: snapshot.inTrend == TrendDirection.worse
                  ? q.bad
                  : q.good,
              label: 'masuk ${trendLabel(snapshot.inTrend, incoming: true)}',
            ),
          ],
        ),
      ],
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: q.line, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: q.text,
            ),
          ),
        ],
      ),
    );
  }
}
