part of '../laporan_screen.dart';

class _ReportSectionHeader extends StatelessWidget {
  const _ReportSectionHeader({this.step, required this.title});

  final String? step;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.s),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.qTitle(14).copyWith(letterSpacing: -0.2),
      ),
    );
  }
}

/// 01 · Kartu Ringkasan Arus Kas Terstruktur
class _ExecutiveSummaryCard extends StatelessWidget {
  const _ExecutiveSummaryCard({required this.metrics});

  final _ReportMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final isSurplus = metrics.isSurplus;
    final savingsPct = metrics.savingsRatePercent;
    final badgeText = !metrics.hasAnyActivity
        ? 'Belum ada aktivitas'
        : isSurplus
        ? (savingsPct != null && savingsPct > 0
              ? 'Surplus · Hemat $savingsPct%'
              : 'Surplus')
        : 'Defisit';

    final sumFlow = metrics.totalIn + metrics.totalOut;

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
          // Top Net Cashflow Block
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.m,
              Spacing.m,
              Spacing.m,
              Spacing.s + 4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Selisih Arus Kas Bersih',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.qSmall(12.5),
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: !metrics.hasAnyActivity
                              ? context.q.surface2
                              : isSurplus
                              ? context.q.incomingTint
                              : context.q.outgoingTint,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          badgeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: !metrics.hasAnyActivity
                                ? context.q.muted
                                : isSurplus
                                ? context.q.good
                                : context.q.bad,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: QuestMoney(
                    amount: metrics.net.abs(),
                    tone: metrics.net == 0
                        ? null
                        : (isSurplus ? MoneyTone.incoming : MoneyTone.outgoing),
                    style: context
                        .qDisplay(28)
                        .copyWith(
                          color: metrics.net == 0
                              ? context.q.text
                              : isSurplus
                              ? context.q.good
                              : context.q.bad,
                        ),
                  ),
                ),
                const SizedBox(height: Spacing.s + 4),

                // Proportional Dual Bar (Pemasukan vs Pengeluaran)
                _SegmentedBar(
                  height: 8,
                  emptyColor: context.q.surface2,
                  segments: sumFlow == 0
                      ? const []
                      : [
                          if (metrics.totalIn > 0)
                            (weight: metrics.totalIn, color: context.q.good),
                          if (metrics.totalOut > 0)
                            (weight: metrics.totalOut, color: context.q.bad),
                        ],
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 1, color: context.q.line),

          // Middle 2-Column Grid: Pemasukan | Pengeluaran
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _FlowHalfCell(
                    label: 'PEMASUKAN',
                    amount: metrics.totalIn,
                    txCount: metrics.inCount,
                    deltaPercent: metrics.inDeltaPercent,
                    deltaGoodWhenPositive: true,
                    color: context.q.good,
                    icon: Icons.south_west_rounded,
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: context.q.line),
                Expanded(
                  child: _FlowHalfCell(
                    label: 'PENGELUARAN',
                    amount: metrics.totalOut,
                    txCount: metrics.outCount,
                    deltaPercent: metrics.outDeltaPercent,
                    deltaGoodWhenPositive: false,
                    color: context.q.bad,
                    icon: Icons.north_east_rounded,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 1, color: context.q.line),

          // Bottom KPI Strip: Rata-rata Harian | Rata-rata per Transaksi
          Container(
            decoration: BoxDecoration(
              color: context.q.surface2.withValues(alpha: 0.55),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.card),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.m,
                        vertical: 11,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rata-rata Keluar / Hari',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.qSmall(11),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: QuestMoney(
                              amount: metrics.avgDailyOut,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: context.q.text,
                                fontFeatures: _tabular,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: context.q.line,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.m,
                        vertical: 11,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rata-rata / Transaksi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.qSmall(11),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: QuestMoney(
                              amount: metrics.avgPerOutTx,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: context.q.text,
                                fontFeatures: _tabular,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowHalfCell extends StatelessWidget {
  const _FlowHalfCell({
    required this.label,
    required this.amount,
    required this.txCount,
    required this.deltaPercent,
    required this.deltaGoodWhenPositive,
    required this.color,
    required this.icon,
  });

  final String label;
  final int amount;
  final int txCount;
  final int? deltaPercent;
  final bool deltaGoodWhenPositive;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final delta = deltaPercent;
    final bool? isGood = delta == null || delta == 0
        ? null
        : (delta > 0 ? deltaGoodWhenPositive : !deltaGoodWhenPositive);

    return Padding(
      padding: const EdgeInsets.all(Spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context
                      .qSmall(11.5)
                      .copyWith(
                        color: context.q.muted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: QuestMoney(
              amount: amount,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: context.q.text,
                fontFeatures: _tabular,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('$txCount trx', style: context.qSmall(11)),
              if (delta != null && delta != 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: (isGood ?? true)
                        ? context.q.incomingTint
                        : context.q.outgoingTint,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${delta > 0 ? '↑' : '↓'}${delta.abs()}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: (isGood ?? true) ? context.q.good : context.q.bad,
                      fontFeatures: _tabular,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 02 · Kartu Tren Arus Kas Interaktif

class _EmptyPeriodCard extends StatelessWidget {
  const _EmptyPeriodCard({required this.periodLabel});

  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.l,
        vertical: Spacing.xl,
      ),
      decoration: BoxDecoration(
        color: context.q.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.q.line),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.q.surface2,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.insert_chart_outlined_rounded,
              color: context.q.muted,
              size: 24,
            ),
          ),
          const SizedBox(height: Spacing.s + 4),
          Text(
            'Belum ada data untuk $periodLabel',
            textAlign: TextAlign.center,
            style: context.qTitle(15),
          ),
          const SizedBox(height: 4),
          Text(
            'Catat pemasukan atau pengeluaran pakai tombol (+) di bawah, nanti grafik tren & komposisi kategorinya muncul.',
            textAlign: TextAlign.center,
            style: context.qSmall(),
          ),
        ],
      ),
    );
  }
}
