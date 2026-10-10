import 'package:flutter/material.dart';

import '../core/money.dart';
import '../game/mascot.dart';
import '../game/progress.dart';
import '../models.dart';
import '../storage/repository.dart';
import '../theme/tokens.dart';

const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

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
    final scheme = Theme.of(context).colorScheme;
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
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SeedColors.ink, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x333B3630),
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: progress == null
                  ? const SizedBox(height: 96)
                  : _Body(progress: progress, incoming: incoming, outgoing: outgoing),
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
    final streakLabel = progress.streakDays > 0
        ? '🔥${progress.streakDays}'
        : '🔥0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_monthsShort[now.month - 1].toUpperCase()} ${now.year} · '
                'HARI KE-${now.day}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 2,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            Icon(
              Icons.local_fire_department,
              size: 16,
              color: progress.streakDays > 0
                  ? SeedColors.honey
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(width: 2),
            Text(
              streakLabel,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: Spacing.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Mascot(mood: progress.mood, size: 76),
            const SizedBox(width: Spacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    progress.moodLine,
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    child: Text(
                      Money.format(outgoing),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    'keluar · masuk ${Money.format(incoming)}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.m),
        // XP bar ke level berikutnya
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.level.progressFraction,
            minHeight: 10,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: const AlwaysStoppedAnimation(SeedColors.honey),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              'Level: ${progress.level.name}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            Text(
              progress.level.xpLevelSpan <= 0
                  ? '${progress.xp} XP · MAX'
                  : '${progress.level.xpIntoLevel}/'
                      '${progress.level.xpLevelSpan} XP ke '
                      '${kLevelNames[progress.level.index + 1]}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
