import 'package:flutter/material.dart';

import '../capture/pipeline.dart';
import '../core/money.dart';
import '../models.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/tokens.dart';
import 'capture_log_screen.dart';
import 'manual_add_sheet.dart';

const _daysShort = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.pipeline,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bukuduit'),
        actions: [
          IconButton(
            tooltip: 'Capture log',
            icon: FutureBuilder<bool>(
              future: widget.pipeline.channel.isListenerEnabled(),
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? false;
                return Badge(
                  isLabelVisible: !enabled,
                  backgroundColor: scheme.error,
                  child: const Icon(Icons.notifications_active_outlined),
                );
              },
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CaptureLogScreen(
                  repository: widget.repository,
                  channel: widget.pipeline.channel,
                  engine: widget.pipeline.engine,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.m),
        children: [
          StreamBuilder<List<Transaction>>(
            stream: widget.repository.watchBetween(monthStart, monthEnd),
            builder: (context, snapshot) {
              var incoming = 0;
              var outgoing = 0;
              for (final t in snapshot.data ?? const <Transaction>[]) {
                if (t.direction == Direction.incoming) {
                  incoming += t.amount;
                } else {
                  outgoing += t.amount;
                }
              }
              return _SummaryCard(incoming: incoming, outgoing: outgoing);
            },
          ),
          const SizedBox(height: Spacing.l),
          Text(
            'Transaksi',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.s),
          StreamBuilder<List<Transaction>>(
            stream: widget.repository.watchRecent(),
            builder: (context, snapshot) {
              final txs = snapshot.data ?? const <Transaction>[];
              if (txs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: Spacing.xl),
                  child: Center(child: Text('Belum ada transaksi.')),
                );
              }
              return _TransactionList(txs: txs);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ManualAddSheet.show(context, widget.repository),
        icon: const Icon(Icons.add),
        label: const Text('Catat'),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.incoming, required this.outgoing});

  final int incoming;
  final int outgoing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.m),
        child: Row(
          children: [
            Expanded(
              child: _AmountTile(
                label: 'Masuk bulan ini',
                amount: incoming,
                color: SeedColors.incoming,
              ),
            ),
            VerticalDivider(color: scheme.outlineVariant),
            Expanded(
              child: _AmountTile(
                label: 'Keluar bulan ini',
                amount: outgoing,
                color: SeedColors.outgoing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: Spacing.xs),
        FittedBox(
          child: Text(
            Money.format(amount),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.txs});

  final List<Transaction> txs;

  @override
  Widget build(BuildContext context) {
    final byDay = <DateTime, List<Transaction>>{};
    for (final t in txs) {
      final d = DateTime(
        t.occurredAt.year,
        t.occurredAt.month,
        t.occurredAt.day,
      );
      byDay.putIfAbsent(d, () => []).add(t);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        for (final day in days) ...[
          _DayHeader(day: day),
          for (final t in byDay[day]!) _TransactionTile(tx: t),
        ],
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final label = switch (day) {
      DateTime d when d == today => 'Hari ini',
      DateTime d when d == today.subtract(const Duration(days: 1)) => 'Kemarin',
      _ =>
        '${_daysShort[day.weekday - 1]}, ${day.day} ${_monthsShort[day.month - 1]}',
    };
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.m, bottom: Spacing.xs),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final incoming = tx.direction == Direction.incoming;
    final title = (tx.counterparty != null && tx.counterparty!.isNotEmpty)
        ? tx.counterparty!
        : tx.kind.label;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        child: Icon(_iconFor(tx.kind)),
      ),
      title: Text(title, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${tx.bankId} · ${tx.source.label}'
        '${tx.rawTitle != null ? ' · auto' : ''}',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      trailing: Text(
        '${incoming ? '+' : '−'} ${Money.format(tx.amount)}',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: incoming ? SeedColors.incoming : SeedColors.outgoing,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  IconData _iconFor(TxKind kind) => switch (kind) {
        TxKind.transfer => Icons.swap_horiz,
        TxKind.payment => Icons.receipt_long,
        TxKind.topup => Icons.add_card,
        TxKind.withdrawal => Icons.local_atm,
        TxKind.other => Icons.circle_outlined,
      };
}
