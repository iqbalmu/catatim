part of '../transaksi_screen.dart';

class _CashflowSummaryCard extends StatelessWidget {
  const _CashflowSummaryCard({
    required this.totalIn,
    required this.totalOut,
    required this.netCashflow,
    required this.filterRevision,
  });

  final int totalIn;
  final int totalOut;
  final int netCashflow;
  final int filterRevision;

  @override
  Widget build(BuildContext context) {
    return QuestTabEnter(
      index: 3,
      replayKey: filterRevision,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.m, 0, Spacing.m, Spacing.s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: context.q.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: context.q.line.withValues(alpha: 0.7),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PEMASUKAN',
                      style: context.qEyebrow(11.5).copyWith(
                        color: context.q.good,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '+${Money.format(totalIn)}',
                        style: TextStyle(
                          fontSize: 18.5,
                          fontWeight: FontWeight.w900,
                          color: context.q.good,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: context.q.line.withValues(alpha: 0.6),
              ),
              const SizedBox(width: Spacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PENGELUARAN',
                      style: context.qEyebrow(11.5).copyWith(
                        color: context.q.bad,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '-${Money.format(totalOut)}',
                        style: TextStyle(
                          fontSize: 18.5,
                          fontWeight: FontWeight.w900,
                          color: context.q.bad,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: context.q.line.withValues(alpha: 0.6),
              ),
              const SizedBox(width: Spacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELISIH',
                      style: context.qEyebrow(11.5).copyWith(
                        color: context.q.muted,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        (netCashflow >= 0 ? '+' : '') + Money.format(netCashflow),
                        style: TextStyle(
                          fontSize: 18.5,
                          fontWeight: FontWeight.w900,
                          color: netCashflow >= 0 ? context.q.text : context.q.bad,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
