part of '../home_cards.dart';

/// Kartu Transaksi Terbaru (5 transaksi terakhir)

class RecentTransactionsCard extends StatelessWidget {
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(
                      'Lihat Semua →',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: q.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.s),

          StreamBuilder<List<TxWithCategory>>(
            stream: repository.watchRecentWithCategory(limit: 5),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return QuestTabEnter(
                  index: 4,
                  child: QuestEmpty(
                    title: 'Belum ada transaksi',
                    hint: 'Tap tombol (+) di bawah untuk mulai mencatat.',
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
