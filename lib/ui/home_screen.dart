import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../core/money.dart';
import '../game/hero_card.dart';
import '../game/mascot.dart';
import '../game/progress.dart';
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
    required this.progress,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final ProgressService progress;

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
          _BerandaTab(
            repository: widget.repository,
            pipeline: widget.pipeline,
            progress: widget.progress,
          ),
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

class _BerandaTab extends StatefulWidget {
  const _BerandaTab({
    required this.repository,
    required this.pipeline,
    required this.progress,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final ProgressService progress;

  @override
  State<_BerandaTab> createState() => _BerandaTabState();
}

class _BerandaTabState extends State<_BerandaTab> {
  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_onProgressChanged);
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onProgressChanged);
    super.dispose();
  }

  void _onProgressChanged() {
    final level = widget.progress.consumePendingLevelUp();
    if (level != null && mounted) {
      HapticFeedback.mediumImpact();
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Mascot(mood: MascotMood.celebrate, size: 96),
              const SizedBox(height: Spacing.m),
              Text(
                'LEVEL UP!',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text('Kamu sekarang level "$level" 🎉'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Lanjut!'),
            ),
          ],
        ),
      );
      return;
    }
    final milestone = widget.progress.consumePendingMilestone();
    if (milestone != null && mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔥 $milestone hari beruntun mencatat — mantap!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  backgroundColor: Theme.of(context).colorScheme.error,
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
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'backup') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BackupScreen(repository: widget.repository),
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
          GameHeroCard(
            service: widget.progress,
            repository: widget.repository,
          ),
          const SizedBox(height: Spacing.l),
          Text('Transaksi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.s),
          StreamBuilder<List<TxWithCategory>>(
            stream: widget.repository.watchRecentWithCategory(),
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
                      _TransactionTile(
                          item: item, repository: widget.repository),
                  ],
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => TransactionSheet.show(
          context,
          widget.repository,
          progress: widget.progress,
        ),
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
