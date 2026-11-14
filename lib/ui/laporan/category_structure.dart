part of '../laporan_screen.dart';

class _CategoryStructureCard extends StatelessWidget {
  const _CategoryStructureCard({
    required this.showIncoming,
    required this.onToggleMode,
    required this.outStats,
    required this.inStats,
    required this.totalOut,
    required this.totalIn,
    required this.outTxCount,
    required this.inTxCount,
    required this.onCategoryTap,
  });

  final bool showIncoming;
  final ValueChanged<bool> onToggleMode;
  final List<_CategoryStat> outStats;
  final List<_CategoryStat> inStats;
  final int totalOut;
  final int totalIn;
  final int outTxCount;
  final int inTxCount;
  final ValueChanged<_CategoryStat> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final activeStats = showIncoming ? inStats : outStats;
    final activeTotal = showIncoming ? totalIn : totalOut;

    return Container(
      decoration: BoxDecoration(
        color: context.q.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.q.line),
        boxShadow: context.q.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                QuestSegmented<bool>(
                  selected: showIncoming,
                  onChanged: onToggleMode,
                  options: [
                    (
                      value: false,
                      label: 'Pengeluaran ($outTxCount)',
                      icon: null,
                    ),
                    (value: true, label: 'Pemasukan ($inTxCount)', icon: null),
                  ],
                ),

                if (activeStats.isEmpty || activeTotal <= 0) ...[
                  const SizedBox(height: Spacing.l),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Spacing.m),
                      child: Column(
                        children: [
                          Icon(
                            Icons.pie_chart_outline_rounded,
                            size: 36,
                            color: context.q.muted.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            showIncoming
                                ? 'Belum ada pemasukan di periode ini'
                                : 'Belum ada pengeluaran di periode ini',
                            textAlign: TextAlign.center,
                            style: context.qSmall(12.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: Spacing.m),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          showIncoming
                              ? 'Distribusi ${activeStats.length} Kategori Masuk'
                              : 'Distribusi ${activeStats.length} Kategori Keluar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.qSmall(),
                        ),
                      ),
                      const SizedBox(width: Spacing.s),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: QuestMoney(
                            amount: activeTotal,
                            alignment: Alignment.centerRight,
                            replayKey: showIncoming,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: context.q.text,
                              fontFeatures: _tabular,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Multi-Segment Proportional Stacked Bar
                  _SegmentedBar(
                    height: 12,
                    emptyColor: context.q.surface2,
                    replayKey: showIncoming,
                    segments: [
                      for (final s in activeStats)
                        (weight: s.amount, color: s.color),
                    ],
                  ),
                ],
              ],
            ),
          ),

          AnimatedSize(
            duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
                ? Duration.zero
                : QuestMotion.medium,
            curve: QuestMotion.easeOut,
            alignment: Alignment.topCenter,
            child: (activeStats.isNotEmpty && activeTotal > 0)
                ? Column(
                    children: [
                      Divider(height: 1, thickness: 1, color: context.q.line),
                      for (var i = 0; i < activeStats.length; i++) ...[
                        _CategoryTableRow(
                          stat: activeStats[i],
                          grandTotal: activeTotal,
                          replayKey: showIncoming,
                          onTap: () => onCategoryTap(activeStats[i]),
                        ),
                        if (i < activeStats.length - 1)
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 66,
                            color: context.q.line,
                          ),
                      ],
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _CategoryTableRow extends StatelessWidget {
  const _CategoryTableRow({
    required this.stat,
    required this.grandTotal,
    required this.onTap,
    this.replayKey,
  });

  final _CategoryStat stat;
  final int grandTotal;
  final VoidCallback onTap;
  final Object? replayKey;
  @override
  Widget build(BuildContext context) {
    final share = grandTotal > 0
        ? (stat.amount / grandTotal).clamp(0.0, 1.0)
        : 0.0;
    final pct = (share * 100).round();

    return Semantics(
      button: true,
      label:
          '${stat.name}, ${Money.format(stat.amount)}, $pct% dari total pengeluaran',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.m,
            vertical: 12,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: stat.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(stat.icon, size: 19, color: stat.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: context.q.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 125),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: QuestMoney(
                              amount: stat.amount,
                              alignment: Alignment.centerRight,
                              replayKey: replayKey,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: context.q.text,
                                fontFeatures: _tabular,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: QuestProgressBar(
                            value: share,
                            color: stat.color,
                            minHeight: 5,
                            replayKey: replayKey,
                          ),
                        ),
                        const SizedBox(width: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 96),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: QuestCountUp(
                              value: pct,
                              replayKey: replayKey,
                              builder: (context, currentPct) => Text(
                                '$currentPct% · ${stat.items.length} trx',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.q.muted,
                                  fontFeatures: _tabular,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.q.muted.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 04 · Tabel 5 Pengeluaran Terbesar
