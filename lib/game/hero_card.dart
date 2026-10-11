import 'package:flutter/material.dart';

import '../core/money.dart';
import '../game/mascot.dart';
import '../game/progress.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';

/// Hero beranda kompak gaya dashboard: Duit + sisa aman + streak.
class GameHeroCard extends StatelessWidget {
  const GameHeroCard({super.key, required this.service});

  final ProgressService service;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) => _HeroCompact(progress: service.latest),
    );
  }
}

/// Zona putih kompak: Duit 52 + sisa aman + pill streak.
class _HeroCompact extends StatelessWidget {
  const _HeroCompact({required this.progress});

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
      padding: const EdgeInsets.all(Spacing.l),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SeedColors.honeyBright, SeedColors.honey],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: p == null || pace == null
          ? const SizedBox(height: 96)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SISA AMAN',
                          style:
                              context.qEyebrow().copyWith(color: q.honeyInk)),
                      const SizedBox(height: 2),
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
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.s),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: q.surface,
                        borderRadius: BorderRadius.circular(999),
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
                    const SizedBox(height: Spacing.s),
                    RepaintBoundary(
                        child: Mascot(mood: p.mood, size: 96)),
                  ],
                ),
              ],
            ),
    );
  }
}

