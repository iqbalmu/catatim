import 'package:flutter/material.dart';

import '../core/money.dart';
import '../game/mascot.dart';
import '../game/progress.dart';
import '../models.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import '../ui/quest.dart';
import '../core/dates_id.dart';

/// Hero card gaya board-game: maskot + streak + angka bulan + XP bar.
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
        return StreamBuilder<List<TxWithCategory>>(
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
              radius: 24,
              child: progress == null
                  ? const SizedBox(height: 96)
                  : _Body(
                      progress: progress,
                      incoming: incoming,
                      outgoing: outgoing,
                    ),
            );
          },
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.progress,
    required this.incoming,
    required this.outgoing,
  });

  final GameProgress progress;
  final int incoming;
  final int outgoing;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hasStreak = progress.streakDays > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${idMonthsShort[now.month - 1].toUpperCase()} ${now.year} · '
                'HARI KE-${now.day}',
                style: context.qEyebrow(),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: hasStreak ? context.q.honey : context.q.surface2,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: context.q.line, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 14,
                    color: hasStreak ? context.q.honeyInk : context.q.muted,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${progress.streakDays}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: hasStreak ? context.q.honeyInk : context.q.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RepaintBoundary(child: Mascot(mood: progress.mood, size: 76)),
            const SizedBox(width: Spacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    progress.moodLine,
                    style: context.qSmall(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    child: Text(
                      Money.format(outgoing),
                      style: context.qDisplay(38),
                    ),
                  ),
                  Text(
                    'keluar · masuk ${Money.format(incoming)}',
                    style: context.qSmall(13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.m),
        QuestBar(value: progress.level.progressFraction),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('Level: ${progress.level.name}', style: context.qTitle(14)),
            const Spacer(),
            Text(
              progress.level.xpLevelSpan <= 0
                  ? '${progress.xp} XP · MAX'
                  : '${progress.level.xpIntoLevel}/'
                        '${progress.level.xpLevelSpan} XP ke '
                        '${kLevelNames[progress.level.index + 1]}',
              style: context.qSmall(),
            ),
          ],
        ),
      ],
    );
  }
}
