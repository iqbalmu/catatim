import 'package:flutter/material.dart';

import '../core/dates_id.dart';
import '../core/money.dart';
import '../game/progress.dart';
import '../models.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';
import 'transaction_sheet.dart';

/// Header hari ("Hari ini", "Kemarin", "Sen, 11 Okt").
class TransactionDayHeader extends StatelessWidget {
  const TransactionDayHeader({
    super.key,
    required this.day,
    required this.first,
    this.totalOut,
  });

  final DateTime day;
  final bool first;

  /// Total keluar hari itu — audit cepat per grup. Null = sembunyikan.
  final int? totalOut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : Spacing.m, bottom: Spacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              idRelativeDay(day, DateTime.now()).toUpperCase(),
              style: context.qEyebrow(),
            ),
          ),
          if (totalOut != null && totalOut! > 0)
            Text(
              '-${Money.format(totalOut!)}',
              style: context.qSmall(11).copyWith(color: context.q.bad),
            ),
        ],
      ),
    );
  }
}

/// Kelompokkan transaksi per hari (tanggal lokal), terbaru dulu.
Map<DateTime, List<TxWithCategory>> groupTxByDay(List<TxWithCategory> items) {
  final byDay = <DateTime, List<TxWithCategory>>{};
  for (final item in items) {
    final t = item.tx.occurredAt;
    byDay.putIfAbsent(DateTime(t.year, t.month, t.day), () => []).add(item);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return {for (final d in days) d: byDay[d]!};
}

/// Satu baris transaksi. Tap = ubah.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.item,
    required this.repository,
    this.progress,
  });

  final TxWithCategory item;
  final LedgerRepository repository;
  final ProgressService? progress;

  @override
  Widget build(BuildContext context) {
    final tx = item.tx;
    final incoming = tx.direction == Direction.incoming;
    final category = item.category;
    final title = (tx.counterparty != null && tx.counterparty!.isNotEmpty)
        ? tx.counterparty!
        : tx.kind.label;
    final dotColor = category == null
        ? context.q.muted
        : SeedColors.categoryColor(category.colorIndex);

    return QuestPress(
      onTap: () => TransactionSheet.show(
        context,
        repository,
        existing: item,
        progress: progress,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: Spacing.s),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.q.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: context.q.shadow,
              offset: const Offset(0, 6),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconFor(tx.kind), color: dotColor, size: 22),
            ),
            const SizedBox(width: Spacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: context.qTitle(15),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${category?.name ?? tx.kind.label} · ${tx.bankId} · '
                          '${tx.source.label}',
                          overflow: TextOverflow.ellipsis,
                          style: context.qSmall(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.s),
            QuestAmount(amount: tx.amount, incoming: incoming),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(TxKind kind) => switch (kind) {
    TxKind.transfer => Icons.swap_horiz_rounded,
    TxKind.payment => Icons.receipt_long_rounded,
    TxKind.topup => Icons.add_card_rounded,
    TxKind.withdrawal => Icons.local_atm_rounded,
    TxKind.other => Icons.circle_outlined,
  };
}
