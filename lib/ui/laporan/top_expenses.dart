part of '../laporan_screen.dart';

class _TopExpensesTableCard extends StatelessWidget {
  const _TopExpensesTableCard({
    required this.items,
    required this.totalOut,
    required this.repository,
    this.progress,
  });

  final List<TxWithCategory> items;
  final int totalOut;
  final LedgerRepository repository;
  final ProgressService? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.q.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.q.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _TopExpenseRow(
              rank: i + 1,
              item: items[i],
              totalOut: totalOut,
              onTap: () => TransactionSheet.show(
                context,
                repository,
                existing: items[i],
                progress: progress,
              ),
            ),
            if (i < items.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 56,
                color: context.q.line,
              ),
          ],
        ],
      ),
    );
  }
}

class _TopExpenseRow extends StatelessWidget {
  const _TopExpenseRow({
    required this.rank,
    required this.item,
    required this.totalOut,
    required this.onTap,
  });

  final int rank;
  final TxWithCategory item;
  final int totalOut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tx = item.tx;
    final party = (tx.counterparty != null && tx.counterparty!.trim().isNotEmpty)
        ? tx.counterparty!.trim()
        : (tx.rawTitle != null && tx.rawTitle!.trim().isNotEmpty)
            ? tx.rawTitle!.trim()
            : tx.kind.label;
    final catName = item.category?.name ?? 'Tanpa Kategori';
    final sharePct = totalOut > 0 ? ((tx.amount / totalOut) * 100).round() : 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.m, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rank == 1 ? context.q.outgoingTint : context.q.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: rank == 1 ? context.q.bad : context.q.muted,
                  fontFeatures: _tabular,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    party,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: context.q.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${idDayMonth(tx.occurredAt)} · $catName · $sharePct% total',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.qSmall(11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: QuestMoney(
                  amount: tx.amount,
                  prefix: '−',
                  alignment: Alignment.centerRight,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: context.q.bad,
                    fontFeatures: _tabular,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
