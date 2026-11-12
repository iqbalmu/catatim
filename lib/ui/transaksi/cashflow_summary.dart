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
                      'Pemasukan',
                      style: context.qSmall(12).copyWith(
                        color: context.q.good,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: QuestMoney(
                        amount: totalIn,
                        tone: MoneyTone.incoming,
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
                      'Pengeluaran',
                      style: context.qSmall(12).copyWith(
                        color: context.q.bad,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: QuestMoney(
                        amount: totalOut,
                        tone: MoneyTone.outgoing,
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
                      'Selisih',
                      style: context.qSmall(12).copyWith(
                        color: context.q.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: QuestMoney(
                        amount: netCashflow,
                        tone: netCashflow > 0
                            ? MoneyTone.incoming
                            : (netCashflow < 0
                                  ? MoneyTone.outgoing
                                  : null),
                        style: TextStyle(
                          fontSize: 18.5,
                          fontWeight: FontWeight.w900,
                          color: netCashflow >= 0
                              ? context.q.text
                              : context.q.bad,
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
