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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: QuestMoney(
                amount: totalOut!,
                prefix: '-',
                alignment: Alignment.centerRight,
                style: context.qSmall(11).copyWith(color: context.q.bad),
              ),
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

    return Semantics(
      button: true,
      label: '$title, ${category?.name ?? tx.kind.label}, ${Money.format(tx.amount)}, ${incoming ? "pemasukan" : "pengeluaran"}',
      child: QuestPress(
        onTap: () => TransactionSheet.show(
          context,
          repository,
          existing: item,
          progress: progress,
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          margin: const EdgeInsets.only(bottom: Spacing.s),
          padding: Insets.tile,
          decoration: BoxDecoration(
            color: context.q.surface,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(
              color: context.q.line.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconFor(tx.kind), color: dotColor, size: 20),
              ),
              const SizedBox(width: Spacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: context.qTitle(14.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${category?.name ?? tx.kind.label} · ${tx.bankId}',
                      overflow: TextOverflow.ellipsis,
                      style: context.qSmall(11.5).copyWith(color: context.q.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.s),
              QuestAmount(amount: tx.amount, incoming: incoming),
            ],
          ),
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
