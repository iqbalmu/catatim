part of '../home_cards.dart';

/// Kartu Transaksi Terbaru (5 transaksi terakhir)

class RecentTransactionsCard extends StatefulWidget {
  const RecentTransactionsCard({
    super.key,
    required this.repository,
    this.progress,
    required this.onSeeAll,
  });

  final LedgerRepository repository;
  final ProgressService? progress;
  final VoidCallback onSeeAll;

  @override
  State<RecentTransactionsCard> createState() =>
      _RecentTransactionsCardState();
}

class _RecentTransactionsCardState extends State<RecentTransactionsCard> {
  LedgerRepository get repository => widget.repository;
  ProgressService? get progress => widget.progress;
  VoidCallback get onSeeAll => widget.onSeeAll;

  late final Stream<List<TxWithCategory>> _recentStream;

  @override
  void initState() {
    super.initState();
    _recentStream = widget.repository.watchRecentWithCategory(limit: 5);
  }

  @override
  void didUpdateWidget(covariant RecentTransactionsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _recentStream = widget.repository.watchRecentWithCategory(limit: 5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.m, Spacing.m, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestTabEnter(
            index: 3,
            child: Row(
              children: [
                Expanded(
                  child: Text('Transaksi Terbaru', style: context.qTitle(16)),
                ),
                QuestPress(
                  onTap: onSeeAll,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(
                      'Lihat Semua',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: q.primaryText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.s),

          StreamBuilder<List<TxWithCategory>>(
            stream: _recentStream,
            builder: (context, snapshot) {
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return QuestTabEnter(
                  index: 4,
                  child: QuestCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.m,
                      vertical: Spacing.l,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 28,
                            color: q.muted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            'Belum ada transaksi',
                            style: context.qTitle(14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap tombol (+) di bawah untuk mulai mencatat',
                            style: context.qSmall(11.5),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < items.length; i++)
                    QuestTabEnter(
                      index: 4 + i,
                      child: TransactionTile(
                        item: items[i],
                        repository: repository,
                        progress: progress,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
