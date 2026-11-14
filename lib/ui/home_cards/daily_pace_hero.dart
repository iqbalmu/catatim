part of '../home_cards.dart';

/// Kartu Hero Utama Beranda: jatah belanja hari ini & status anggaran
/// Menjawab langsung: "Boleh habis berapa hari ini?" dan status kesehatan anggaran.
class DailyPaceHeroCard extends StatelessWidget {
  const DailyPaceHeroCard({
    super.key,
    required this.progress,
    required this.onTap,
    this.margin,
  });

  final ProgressService progress;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return Padding(
      padding: margin ?? const EdgeInsets.fromLTRB(Spacing.m, Spacing.s, Spacing.m, 0),
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final summary = progress.latest;
          final snapshot = summary?.snapshot;
          final LimitLine? monthlyLine = snapshot?.lines
              .cast<LimitLine?>()
              .firstWhere(
                (l) => l?.label == LimitScope.monthly.label,
                orElse: () => null,
              );

          final LimitLine? dailyLine = snapshot?.lines
              .cast<LimitLine?>()
              .firstWhere(
                (l) => l?.label == LimitScope.daily.label,
                orElse: () => null,
              );

          final pace = summary?.dailyPace;
          final int? safe = pace?.safeToSpend;
          final int dayOut = summary?.dayOut ?? 0;
          final int monthOut = summary?.monthOut ?? 0;
          final int? monthlyLimit = monthlyLine?.limit;
          final int? dailyLimit = dailyLine?.limit;

          final bool hasBudget = safe != null ||
              (dailyLimit != null && dailyLimit > 0) ||
              (monthlyLimit != null && monthlyLimit > 0);

          if (!hasBudget) {
            return _buildEmptyState(context, q);
          }

          final bool isOver = safe != null && safe < 0;

          // Hitung status semantik
          final String statusLabel;
          final Color statusColor;
          final IconData statusIcon;

          if (isOver) {
            statusLabel = 'Defisit';
            statusColor = q.bad;
            statusIcon = Icons.warning_amber_rounded;
          } else if (monthlyLimit != null &&
              monthlyLimit > 0 &&
              (monthOut / monthlyLimit) > 0.85) {
            statusLabel = 'Waspada';
            statusColor = q.warn;
            statusIcon = Icons.info_outline_rounded;
          } else {
            statusLabel = 'Aman';
            statusColor = q.good;
            statusIcon = Icons.check_circle_outline_rounded;
          }

          final double monthlyFraction = (monthlyLimit != null && monthlyLimit > 0)
              ? (monthOut / monthlyLimit).clamp(0.0, 1.0)
              : 0.0;
          final bool isMonthOver =
              monthlyLimit != null && monthlyLimit > 0 && monthOut > monthlyLimit;
          final Color monthProgressColor = isMonthOver
              ? q.bad
              : (monthlyFraction >= 0.85 ? q.warn : q.good);

          return QuestCard(
            variant: QuestCardVariant.hero,
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: judul kartu & status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Jatah hari ini',
                      style: context.qSmall(12.5).copyWith(
                            fontWeight: FontWeight.w700,
                            color: q.muted,
                          ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.s),

                // Hero Number
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: QuestMoney(
                    amount: safe != null ? safe.abs() : 0,
                    tone: isOver ? MoneyTone.outgoing : null,
                    duration: const Duration(milliseconds: 500),
                    style: context.qDisplay(32).copyWith(
                          color: isOver ? q.bad : q.text,
                        ),
                  ),
                ),
                const SizedBox(height: Spacing.xxs),

                Text(
                  isOver ? 'Melebihi jatah hari ini' : 'Sisa yang boleh dipakai hari ini',
                  style: context.qSmall().copyWith(
                        color: q.muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: Spacing.s),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Keluar hari ini: ${Money.format(dayOut)}',
                      style: context.qSmall(11.5).copyWith(
                            fontWeight: FontWeight.w700,
                            color: q.text,
                          ),
                    ),
                    if (pace != null)
                      Text(
                        'Hari ${pace.dayOfMonth} dari ${pace.daysInMonth}',
                        style: context.qSmall(11).copyWith(color: q.muted),
                      ),
                  ],
                ),
                if (dailyLine?.scopeNote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Dihitung dari: ${dailyLine!.scopeNote}',
                      style: context.qSmall(10.5).copyWith(color: q.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                if (monthlyLimit != null && monthlyLimit > 0) ...[
                  const SizedBox(height: Spacing.m),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: q.line.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: Spacing.s),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total bulan ini: ${Money.format(monthOut)} / ${Money.format(monthlyLimit)}',
                        style: context.qSmall(11).copyWith(color: q.muted),
                      ),
                      Text(
                        '${((monthOut * 100 / monthlyLimit)).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: monthProgressColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  QuestProgressBar(
                    value: monthlyFraction,
                    color: monthProgressColor,
                    backgroundColor: q.surface2,
                    minHeight: 6,
                  ),
                  if (monthlyLine?.scopeNote != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Dihitung dari: ${monthlyLine!.scopeNote}',
                        style: context.qSmall(10.5).copyWith(color: q.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Empty state interaktif saat belum ada batas anggaran yang diatur
  Widget _buildEmptyState(BuildContext context, QuestPalette q) {
    return QuestCard(
      variant: QuestCardVariant.hero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Jatah hari ini belum diatur',
                  style: context.qTitle(14.5),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: q.muted, size: 20),
            ],
          ),
          const SizedBox(height: Spacing.m),
          Text(
            'Atur batas harian atau bulanan, lalu CatatIM menghitung sisa uang yang boleh dipakai tiap hari.',
            style: context.qBody(12.5).copyWith(color: q.muted),
          ),
          const SizedBox(height: Spacing.s),
          Text(
            'Atur Batas Anggaran',
            style: context.qSmall(12.5).copyWith(
                  color: q.primaryText,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
