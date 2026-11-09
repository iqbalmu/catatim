part of '../transaksi_screen.dart';

sealed class _FlatTxItem {
  const _FlatTxItem();
  Key get key;
}

class _FlatDayHeaderItem extends _FlatTxItem {
  final DateTime day;
  final bool first;
  final int? totalOut;
  const _FlatDayHeaderItem({
    required this.day,
    required this.first,
    this.totalOut,
  });

  @override
  Key get key => ValueKey('day_${day.millisecondsSinceEpoch}');
}

class _FlatTxEntryItem extends _FlatTxItem {
  final TxWithCategory item;
  const _FlatTxEntryItem(this.item);

  @override
  Key get key => ValueKey('tx_${item.tx.id}');
}
