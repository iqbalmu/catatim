part of '../home_cards.dart';

/// Ringkasan Anggaran Bulan Ini: Ringkas, jelas, dengan bar progres semantik

class BudgetSummaryCard extends StatelessWidget {
  const BudgetSummaryCard({
    super.key,
    required this.progress,
    required this.onTap,
  });

  final ProgressService progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.m, Spacing.m, 0),
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final summary = progress.latest;
          final snapshot = summary?.snapshot;
          final LimitLine? monthlyLine = snapshot?.lines
              .cast<LimitLine?>()
              .firstWhere(
                (l) => l?.label == 'Total bulan ini',
                orElse: () => null,
              );
          final used = summary?.monthOut ?? 0;
          final int? limit = monthlyLine?.limit;
          final pace = summary?.dailyPace;
          final hasBudget = limit != null && limit > 0;
          final fraction = hasBudget ? (used / limit).clamp(0.0, 1.0) : 0.0;
          final isOver = hasBudget && used > limit;

          Color progressColor;
          if (isOver) {
            progressColor = q.bad;
          } else if (fraction >= 0.75) {
            progressColor = q.warn;
          } else {
            progressColor = q.good;
          }

          return QuestCard(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Row
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: q.primaryLight,
                        borderRadius: BorderRadius.circular(AppRadius.cell),
                      ),
                      child: Icon(
                        Icons.pie_chart_outline_rounded,
                        color: q.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: Spacing.s),
                    Expanded(
                      child: Text(
                        'Anggaran Bulan Ini',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.qTitle(15),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: q.muted, size: 20),
                  ],
                ),
                const SizedBox(height: Spacing.m),

                AnimatedSize(
                  duration:
                      (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
                      ? Duration.zero
                      : QuestMotion.medium,
                  curve: QuestMotion.easeOut,
                  alignment: Alignment.topCenter,
                  child: !hasBudget
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Batas anggaran bulanan belum diatur.',
                              style: context.qBody(13),
                            ),
                            const SizedBox(height: Spacing.xxs),
                            Text(
                              'Tap untuk mengatur batas pengeluaran agar keuangan terkontrol.',
                              style: context
                                  .qSmall(11.5)
                                  .copyWith(color: q.muted),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Numbers & Percentage
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: QuestCountUp(
                                      value: used,
                                      builder: (context, currentUsed) => RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: 'Terpakai ',
                                              style: context.qSmall(12),
                                            ),
                                            TextSpan(
                                              text: Money.format(currentUsed),
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                color: q.text,
                                                fontFeatures: const [
                                                  FontFeature.tabularFigures(),
                                                ],
                                              ),
                                            ),
                                            TextSpan(
                                              text:
                                                  ' dari ${Money.format(limit)}',
                                              style: context.qSmall(12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Spacing.s),
                                QuestReplay(
                                  builder: (context, t) => Text(
                                    '${((used * 100 / limit) * t).round()}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: progressColor,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Spacing.s),

                            // Progress Bar — tumbuh dari nol saat tampil.
                            QuestProgressBar(
                              value: fraction,
                              color: progressColor,
                              backgroundColor: q.surface2,
                            ),
                            const SizedBox(height: Spacing.s),

                            // Single Clean Summary Line
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isOver
                                        ? SeedColors.outgoingTint
                                        : SeedColors.incomingTint,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.pill,
                                    ),
                                  ),
                                  child: QuestMoney(
                                    amount: isOver
                                        ? used - limit
                                        : limit - used,
                                    prefix: isOver ? 'Over ' : 'Sisa ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isOver ? q.bad : q.good,
                                    ),
                                  ),
                                ),
                                if (pace?.safeToSpend != null &&
                                    pace!.safeToSpend! > 0) ...[
                                  const SizedBox(width: Spacing.s),
                                  Expanded(
                                    child: Text(
                                      '· Aman ~${Money.format(pace.safeToSpend!)} / hari',
                                      style: context
                                          .qSmall(11.5)
                                          .copyWith(color: q.muted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
