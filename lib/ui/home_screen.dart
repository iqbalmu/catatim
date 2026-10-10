import 'package:flutter/material.dart';

import '../capture/pipeline.dart';
import '../core/money.dart';
import '../models.dart';
import '../storage/repository.dart';
import '../theme/tokens.dart';
import 'backup_screen.dart';
import 'capture_log_screen.dart';
import 'report_screen.dart';
import 'transaction_sheet.dart';

const _daysShort = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Shell utama: bottom navigation Beranda | Laporan.
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
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _BerandaTab(repository: widget.repository, pipeline: widget.pipeline),
          ReportTab(repository: widget.repository),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Laporan',
          ),
        ],
      ),
    );
  }
}

class _BerandaTab extends StatelessWidget {
  const _BerandaTab({required this.repository, required this.pipeline});

  final LedgerRepository repository;
  final CapturePipeline pipeline;

  @override
  Widget build(BuildContext context) {
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
              future: pipeline.channel.isListenerEnabled(),
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? false;
                return Badge(
                  isLabelVisible: !enabled,
                  backgroundColor: Theme.of(context).colorScheme.error,
                  child: const Icon(Icons.notifications_active_outlined),
                );
              },
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CaptureLogScreen(
                  repository: repository,
                  channel: pipeline.channel,
                  engine: pipeline.engine,
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'backup') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BackupScreen(repository: repository),
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'backup',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.backup_outlined),
                  title: Text('Backup & pulihkan'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.m),
        children: [
          StreamBuilder<List<TxWithCategory>>(
            stream: repository.watchBetweenWithCategory(monthStart, monthEnd),
            builder: (context, snapshot) {
              var incoming = 0;
              var outgoing = 0;
              for (final r in snapshot.data ?? const <TxWithCategory>[]) {
                if (r.tx.direction == Direction.incoming) {
                  incoming += r.tx.amount;
                } else {
                  outgoing += r.tx.amount;
                }
              }
              return _SummaryCard(incoming: incoming, outgoing: outgoing);
            },
          ),
          const SizedBox(height: Spacing.l),
          Text('Transaksi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.s),
          StreamBuilder<List<TxWithCategory>>(
            stream: repository.watchRecentWithCategory(),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <TxWithCategory>[];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: Spacing.xl),
                  child: Center(child: Text('Belum ada transaksi.')),
                );
              }
              // Kelompokkan per hari.
              final byDay = <DateTime, List<TxWithCategory>>{};
              for (final item in items) {
                final t = item.tx.occurredAt;
                byDay
                    .putIfAbsent(DateTime(t.year, t.month, t.day), () => [])
                    .add(item);
              }
              final days = byDay.keys.toList()
                ..sort((a, b) => b.compareTo(a));
              return Column(
                children: [
                  for (final day in days) ...[
                    _DayHeader(day: day),
                    for (final item in byDay[day]!)
                      _TransactionTile(item: item, repository: repository),
                  ],
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => TransactionSheet.show(context, repository),
        icon: const Icon(Icons.add),
        label: const Text('Catat'),
      ),
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
      DateTime d when d == today.subtract(const Duration(days: 1)) =>
        'Kemarin',
      _ =>
        '${_daysShort[day.weekday - 1]}, ${day.day} ${_monthsShort[day.month - 1]}',
    };
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.m, bottom: Spacing.xs),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
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
        Text(label, style: Theme.of(context).textTheme.labelMedium),
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

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.item, required this.repository});

  final TxWithCategory item;
  final LedgerRepository repository;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tx = item.tx;
    final incoming = tx.direction == Direction.incoming;
    final category = item.category;
    final title = (tx.counterparty != null && tx.counterparty!.isNotEmpty)
        ? tx.counterparty!
        : tx.kind.label;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: category == null
            ? scheme.secondaryContainer
            : SeedColors.categoryColor(category.colorIndex).withAlpha(60),
        foregroundColor: category == null
            ? scheme.onSecondaryContainer
            : SeedColors.categoryColor(category.colorIndex),
        child: Icon(_iconFor(tx.kind)),
      ),
      title: Text(title, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: category == null
                  ? scheme.outlineVariant
                  : SeedColors.categoryColor(category.colorIndex),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${category?.name ?? tx.kind.label} · ${tx.bankId} · '
              '${tx.source.label}',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
      trailing: Text(
        '${incoming ? '+' : '−'} ${Money.format(tx.amount)}',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: incoming ? SeedColors.incoming : SeedColors.outgoing,
              fontWeight: FontWeight.w600,
            ),
      ),
      onTap: () => TransactionSheet.show(context, repository, existing: item),
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
