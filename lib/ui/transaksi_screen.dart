import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../core/dates_id.dart';
import '../core/money.dart';
import '../game/progress.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'month_picker.dart';
import 'quest.dart';
import 'transaction_tile.dart';

part 'transaksi/cashflow_summary.dart';
part 'transaksi/filter_sheet.dart';
part 'transaksi/flat_items.dart';

/// Cocokkan transaksi dengan query: pihak, kategori, bank, jenis, nominal.
bool matchesQuery(TxWithCategory item, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final cleanQ = q.replaceAll(RegExp(r'[^0-9a-z]'), '');
  final tx = item.tx;
  final haystacks = [
    tx.counterparty ?? '',
    item.category?.name ?? '',
    tx.bankId,
    tx.kind.label,
    tx.amount.toString(),
    Money.format(tx.amount),
  ].map((s) => s.toLowerCase());
  return haystacks.any((h) => h.contains(q) || (cleanQ.isNotEmpty && h.replaceAll(RegExp(r'[^0-9a-z]'), '').contains(cleanQ)));
}
class TransaksiScreen extends StatefulWidget {
  const TransaksiScreen({
    super.key,
    required this.repository,
    this.progress,
    this.pipeline,
    this.ruleSet,
    this.onBonViewChanged,
  });
  final LedgerRepository repository;
  final ProgressService? progress;
  final CapturePipeline? pipeline;
  final RuleSet? ruleSet;
  final ValueChanged<bool>? onBonViewChanged;
  @override
  State<TransaksiScreen> createState() => TransaksiScreenState();
}

class TransaksiScreenState extends State<TransaksiScreen> {
  int _filterRevision = 0;

  bool handleBack() => false;
  void showBon() {}

  Future<void> _openFilterSheet() async {
    final accounts = await widget.repository.getAccounts();
    if (!mounted) return;

    final result = await showQuestSheet<({Direction? direction, int? accountId})>(
      context,
      (ctx) => _TransactionFilterSheet(
        initialDirection: _selectedDirection,
        initialAccountId: _selectedAccountId,
        accounts: accounts,
      ),
    );

    if (result != null && mounted) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedDirection = result.direction;
        _selectedAccountId = result.accountId;
        _filterRevision++;
      });
    }
  }

  late DateTime _selectedMonth;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isSearchVisible = false;
  int? _selectedAccountId;
  Direction? _selectedDirection;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _shiftMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
      _filterRevision++;
    });
  }

  void _openMonthPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.q.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.s, Spacing.m, Spacing.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.q.muted.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.m),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pilih Bulan Transaksi', style: context.qTitle(16)),
                  QuestIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.s),
              Divider(height: 1, thickness: 1, color: context.q.line),
              const SizedBox(height: Spacing.m),
              QuestMonthPicker(
                initialMonth: _selectedMonth,
                onChanged: (m) {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedMonth = m;
                    _filterRevision++;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentToken = QuestStage.ofOrNull(context)?.token ?? 0;
    final effectiveToken = parentToken * 1000 + _filterRevision;

    return Scaffold(
      backgroundColor: context.q.bg,
      body: SafeArea(
        bottom: false,
        child: QuestStage(
          token: effectiveToken,
          child: _buildTransactionsView(),
        ),
      ),
    );
  }

  Widget _buildTransactionsView() {
    final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month);
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);

    return Column(
      children: [
        // Top Header: Title (Kiri) + Action Icons (Kanan)
        QuestTabEnter(
          index: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.m,
              Spacing.m,
              Spacing.m,
              Spacing.xs,
            ),
            child: Row(
              children: [
                Text('Transaksi', style: context.qTitle(20)),
                const Spacer(),
                // Search Toggle
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _isSearchVisible
                        ? context.q.primary.withValues(alpha: 0.12)
                        : context.q.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isSearchVisible
                          ? context.q.primary
                          : context.q.line.withValues(alpha: 0.6),
                    ),
                  ),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      _isSearchVisible
                          ? Icons.search_off_rounded
                          : Icons.search_rounded,
                      size: 18,
                      color: _isSearchVisible
                          ? context.q.primary
                          : context.q.text,
                    ),
                    tooltip: _isSearchVisible
                        ? 'Tutup Pencarian'
                        : 'Cari Transaksi',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _isSearchVisible = !_isSearchVisible;
                        if (!_isSearchVisible) {
                          _searchCtrl.clear();
                          _searchQuery = '';
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                // Filter Drawer Button
                Builder(
                  builder: (context) {
                    final hasFilter = _selectedDirection != null ||
                        _selectedAccountId != null;
                    return Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: hasFilter
                            ? context.q.primary.withValues(alpha: 0.12)
                            : context.q.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hasFilter
                              ? context.q.primary
                              : context.q.line.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.tune_rounded,
                              size: 18,
                              color: hasFilter
                                  ? context.q.primary
                                  : context.q.text,
                            ),
                            tooltip: 'Filter Transaksi',
                            onPressed: _openFilterSheet,
                          ),
                          if (hasFilter)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: context.q.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Search Input (Muncul saat ikon cari ditekan)
        if (_isSearchVisible)
          QuestTabEnter(
            index: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.m,
                0,
                Spacing.m,
                Spacing.xs,
              ),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: context.q.surface,
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  border: Border.all(
                    color: context.q.line.withValues(alpha: 0.6),
                  ),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: context.qBody(13.5),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: context.q.muted,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    hintText: 'Cari transaksi, toko, nominal...',
                    hintStyle: context.qSmall(12.5),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),

        // Full-Width Month Navigator Bar (seperti di Halaman Laporan)
        QuestTabEnter(
          index: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.m,
              Spacing.xs,
              Spacing.m,
              Spacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.q.surface,
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    border: Border.all(
                      color: context.q.line.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Bulan sebelumnya',
                        icon: Icon(
                          Icons.chevron_left_rounded,
                          color: context.q.text,
                          size: 22,
                        ),
                        onPressed: () => _shiftMonth(-1),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: _openMonthPicker,
                          borderRadius: BorderRadius.circular(AppRadius.cell),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 14,
                                    color: context.q.primary,
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: QuestSwap(
                                      child: Text(
                                        idMonthYear(_selectedMonth),
                                        key: ValueKey(idMonthYear(_selectedMonth)),
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Nunito',
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: context.q.text,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.unfold_more_rounded,
                                    size: 16,
                                    color: context.q.muted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Bulan berikutnya',
                        icon: Icon(
                          Icons.chevron_right_rounded,
                          color: context.q.text,
                          size: 22,
                        ),
                        onPressed: () => _shiftMonth(1),
                      ),
                    ],
                  ),
                ),

                // Active Filter Quick Reset Pill (bila ada filter arah/akun)
                if (_selectedDirection != null || _selectedAccountId != null) ...[
                  const SizedBox(height: Spacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: QuestPress(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedDirection = null;
                          _selectedAccountId = null;
                          _filterRevision++;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.q.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: context.q.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.filter_alt_outlined,
                              size: 12,
                              color: context.q.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _selectedDirection != null && _selectedAccountId != null
                                  ? '${_selectedDirection == Direction.outgoing ? 'Keluar' : 'Masuk'} · Filter Akun'
                                  : switch (_selectedDirection) {
                                      Direction.outgoing => 'Keluar',
                                      Direction.incoming => 'Masuk',
                                      null => 'Filter Akun',
                                    },
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: context.q.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.close_rounded,
                              size: 12,
                              color: context.q.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.xs),

        // Transactions Stream List & Monthly Cashflow Summary
        Expanded(
          child: StreamBuilder<List<TxWithCategory>>(
            stream: widget.repository.watchBetweenWithCategory(
              startOfMonth,
              endOfMonth,
              accountId: _selectedAccountId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(Spacing.m),
                  child: QuestSkeleton(rows: 4),
                );
              }

              final allItems = snapshot.data ?? const [];
              final filtered = allItems.where((item) {
                if (_selectedDirection != null && item.tx.direction != _selectedDirection) {
                  return false;
                }
                if (_searchQuery.isNotEmpty && !matchesQuery(item, _searchQuery)) {
                  return false;
                }
                return true;
              }).toList();

              int totalIn = 0;
              int totalOut = 0;
              for (final item in allItems) {
                if (item.tx.kind == TxKind.transfer) continue;
                if (item.tx.direction == Direction.incoming) {
                  totalIn += item.tx.amount;
                } else if (item.tx.direction == Direction.outgoing) {
                  totalOut += item.tx.amount;
                }
              }
              final netCashflow = totalIn - totalOut;

              final summaryWidget = allItems.isNotEmpty
                  ? _CashflowSummaryCard(
                      totalIn: totalIn,
                      totalOut: totalOut,
                      netCashflow: netCashflow,
                      filterRevision: _filterRevision,
                    )
                  : null;

              if (filtered.isEmpty) {
                return Column(
                  children: [
                    ?summaryWidget,
                    Expanded(
                      child: QuestTabEnter(
                        index: 4,
                        replayKey: _filterRevision,
                        child: QuestEmpty(
                          title: 'Tidak ada transaksi',
                          hint: _searchQuery.isNotEmpty
                              ? 'Coba kata kunci pencarian yang lain.'
                              : 'Belum ada transaksi di bulan ${idMonthYear(_selectedMonth)}.',
                        ),
                      ),
                    ),
                  ],
                );
              }

              final grouped = groupTxByDay(filtered);
              final flatItems = <_FlatTxItem>[];
              var isFirstDay = true;
              for (final entry in grouped.entries) {
                final day = entry.key;
                final items = entry.value;
                final dayTotalOut = items
                    .where((item) => item.tx.direction == Direction.outgoing)
                    .fold<int>(0, (sum, item) => sum + item.tx.amount);

                flatItems.add(_FlatDayHeaderItem(
                  day: day,
                  first: isFirstDay,
                  totalOut: dayTotalOut > 0 ? dayTotalOut : null,
                ));
                isFirstDay = false;

                for (final item in items) {
                  flatItems.add(_FlatTxEntryItem(item));
                }
              }

              return Column(
                children: [
                  ?summaryWidget,
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        Spacing.m,
                        0,
                        Spacing.m,
                        96 + MediaQuery.paddingOf(context).bottom,
                      ),
                      itemCount: flatItems.length,
                      findChildIndexCallback: (key) {
                        if (key is ValueKey<String>) {
                          final strKey = key.value;
                          for (var i = 0; i < flatItems.length; i++) {
                            final itemKey = flatItems[i].key;
                            if (itemKey is ValueKey<String> && itemKey.value == strKey) {
                              return i;
                            }
                          }
                        }
                        return null;
                      },
                      itemBuilder: (context, i) {
                        final entry = flatItems[i];
                        final Widget child = switch (entry) {
                          _FlatDayHeaderItem h => TransactionDayHeader(
                              key: h.key,
                              day: h.day,
                              first: h.first,
                              totalOut: h.totalOut,
                            ),
                          _FlatTxEntryItem t => TransactionTile(
                              key: t.key,
                              item: t.item,
                              repository: widget.repository,
                              progress: widget.progress,
                            ),
                        };

                        if (i >= 8) return child;
                        return QuestTabEnter(
                          key: ValueKey('tab_enter_${entry.key}'),
                          index: 4 + i,
                          replayKey: _filterRevision,
                          child: child,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
