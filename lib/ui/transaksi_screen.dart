import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

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
import 'bon_screen.dart';
import 'month_picker.dart';
import 'quest.dart';
import 'transaction_tile.dart';

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
  void _setBonView(bool show) {
    if (_showBonView != show) {
      setState(() => _showBonView = show);
      widget.onBonViewChanged?.call(show);
    }
  }

  bool handleBack() {
    if (_showBonView) {
      _setBonView(false);
      return true;
    }
    return false;
  }

  void showBon() {
    _setBonView(true);
  }
  late DateTime _selectedMonth;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int? _selectedAccountId;
  Direction? _selectedDirection;
  bool _showBonView = false;
  int _bonSubTab = 0; // 0 = Belum Lunas, 1 = Lunas
  late final PageController _bonPageCtrl = PageController(initialPage: _bonSubTab);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _bonPageCtrl.dispose();
    super.dispose();
  }

  void _shiftMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
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
                  setState(() => _selectedMonth = m);
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
    return Scaffold(
      backgroundColor: context.q.bg,
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: QuestMotion.fast,
          switchInCurve: QuestMotion.easeOut,
          switchOutCurve: QuestMotion.easeOut,
          child: KeyedSubtree(
            key: ValueKey<bool>(_showBonView),
            child: _showBonView ? _buildBonView() : _buildTransactionsView(),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsView() {
    final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month);
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);

    return Column(
      children: [
        // Top Header: Title (Kiri) + Month Selector (Tengah) + Bon Shortcut (Kanan)
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.m, Spacing.m, Spacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Transaksi', style: context.qTitle(20)),
                ),
              ),

              // Month Selector Pill (Pas di Tengah)
              Container(
                decoration: BoxDecoration(
                  color: context.q.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: context.q.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      onPressed: () => _shiftMonth(-1),
                    ),
                    QuestPress(
                      onTap: _openMonthPicker,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: Text(
                          idMonthYear(_selectedMonth),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: context.q.text,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      onPressed: () => _shiftMonth(1),
                    ),
                  ],
                ),
              ),

              // Button Bon Shortcut (Kanan)
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: StreamBuilder<List<Bon>>(
                    stream: widget.repository.watchBons(),
                    builder: (context, snapshot) {
                      final bons = snapshot.data ?? const [];
                      final unsettledCount = bons.where((b) => b.settledAt == null).length;

                      return QuestPress(
                        onTap: () => _setBonView(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: unsettledCount > 0 ? context.q.warnTint : context.q.surface2,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: unsettledCount > 0
                                  ? context.q.warn.withValues(alpha: 0.3)
                                  : context.q.line,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.handshake_outlined,
                                 size: 16,
                                 color: unsettledCount > 0 ? context.q.warn : context.q.text,
                               ),
                               const SizedBox(width: 4),
                               Text(
                                 'Bon',
                                 style: TextStyle(
                                   fontSize: 12,
                                   fontWeight: FontWeight.w700,
                                   color: unsettledCount > 0 ? context.q.warn : context.q.text,
                                 ),
                               ),
                               if (unsettledCount > 0) ...[
                                 const SizedBox(width: 4),
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                   decoration: BoxDecoration(
                                     color: context.q.warn,
                                     shape: BoxShape.circle,
                                   ),
                                   child: Text(
                                     '$unsettledCount',
                                     style: const TextStyle(
                                       fontSize: 9.5,
                                       fontWeight: FontWeight.w800,
                                       color: Colors.white,
                                     ),
                                   ),
                                 ),
                               ],
                             ],
                           ),
                         ),
                       );
                     },
                   ),
                 ),
               ),
            ],
          ),
        ),
        // Search Input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.m, vertical: Spacing.xs),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: context.q.surface,
              borderRadius: BorderRadius.circular(AppRadius.tile),
              border: Border.all(color: context.q.line),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: context.qBody(13.5),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: context.q.muted),
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
                hintStyle: context.qSmall(13),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),

        // Filter Pills Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.m, vertical: Spacing.xs),
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // Direction Filter
              _FilterChip(
                label: 'Semua Arah',
                selected: _selectedDirection == null,
                onSelected: () => setState(() => _selectedDirection = null),
              ),
              const SizedBox(width: Spacing.xs),
              _FilterChip(
                label: 'Keluar (-)',
                selected: _selectedDirection == Direction.outgoing,
                onSelected: () => setState(() => _selectedDirection = Direction.outgoing),
              ),
              const SizedBox(width: Spacing.xs),
              _FilterChip(
                label: 'Masuk (+)',
                selected: _selectedDirection == Direction.incoming,
                onSelected: () => setState(() => _selectedDirection = Direction.incoming),
              ),
              const SizedBox(width: Spacing.s),
              Container(width: 1, height: 20, color: context.q.line),
              const SizedBox(width: Spacing.s),

              // Account Filter
              StreamBuilder<List<Account>>(
                stream: widget.repository.watchAccounts(),
                builder: (context, snapshot) {
                  final accounts = snapshot.data ?? const [];
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FilterChip(
                        label: 'Semua Akun',
                        selected: _selectedAccountId == null,
                        onSelected: () => setState(() => _selectedAccountId = null),
                      ),
                      for (final acc in accounts) ...[
                        const SizedBox(width: Spacing.xs),
                        _FilterChip(
                          label: acc.name,
                          selected: _selectedAccountId == acc.id,
                          onSelected: () => setState(() => _selectedAccountId = acc.id),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.xs),

        // Transactions Stream List
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

              if (filtered.isEmpty) {
                return QuestEmpty(
                  title: 'Tidak ada transaksi',
                  hint: _searchQuery.isNotEmpty
                      ? 'Coba kata kunci pencarian yang lain.'
                      : 'Belum ada transaksi di bulan ${idMonthYear(_selectedMonth)}.',
                );
              }

              final grouped = groupTxByDay(filtered);
              final days = grouped.keys.toList();

              return ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  Spacing.m,
                  0,
                  Spacing.m,
                  96 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: days.length,
                itemBuilder: (context, i) {
                  final day = days[i];
                  final items = grouped[day]!;
                  final dayTotalOut = items
                      .where((item) => item.tx.direction == Direction.outgoing)
                      .fold<int>(0, (sum, item) => sum + item.tx.amount);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TransactionDayHeader(
                        day: day,
                        first: i == 0,
                        totalOut: dayTotalOut > 0 ? dayTotalOut : null,
                      ),
                      for (final item in items)
                        TransactionTile(
                          item: item,
                          repository: widget.repository,
                          progress: widget.progress,
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Sub-view Bon Utang & Piutang ──────────────────────────────────
  Widget _buildBonView() {
    return Column(
      children: [
        // Sub-view Header
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.m, Spacing.m, Spacing.s),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => _setBonView(false),
              ),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bon & Utang-Piutang', style: context.qTitle(18)),
                    Text(
                      'Pencatatan pinjam-meminjam dengan orang lain',
                      style: context.qSmall(11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Piutang vs Utang Summary Cards
        StreamBuilder<List<Bon>>(
          stream: widget.repository.watchBons(),
          builder: (context, snapshot) {
            final bons = snapshot.data ?? const [];
            final piutangTotal = bons
                .where((b) => b.settledAt == null && b.direction == BonDirection.lent)
                .fold<int>(0, (sum, b) => sum + b.amount);
            final utangTotal = bons
                .where((b) => b.settledAt == null && b.direction == BonDirection.borrowed)
                .fold<int>(0, (sum, b) => sum + b.amount);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.m, vertical: Spacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: context.q.surface,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: context.q.line),
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: context.q.good,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'PIUTANG',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.qEyebrow(10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              Money.format(piutangTotal),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: context.q.good,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          Text(
                            'Orang berutang ke kita',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.qSmall(10.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.s),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: context.q.surface,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: context.q.line),
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: context.q.bad,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'UTANG',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.qEyebrow(10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              Money.format(utangTotal),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: context.q.bad,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          Text(
                            'Kita berutang ke orang',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.qSmall(10.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: Spacing.s),

        // Sub Tabs: [Belum Lunas] vs [Lunas] via QuestSegmented
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.m),
          child: QuestSegmented<int>(
            selected: _bonSubTab,
            onChanged: (val) {
              setState(() => _bonSubTab = val);
              if (_bonPageCtrl.hasClients) {
                _bonPageCtrl.animateToPage(
                  val,
                  duration: QuestMotion.medium,
                  curve: QuestMotion.easeOut,
                );
              }
            },
            options: const [
              (value: 0, label: 'Belum Lunas', icon: null),
              (value: 1, label: 'Lunas', icon: null),
            ],
          ),
        ),
        const SizedBox(height: Spacing.s),

        // Bon List via PageView for smooth horizontal slide transitions
        Expanded(
          child: StreamBuilder<List<Bon>>(
            stream: widget.repository.watchBons(),
            builder: (context, snapshot) {
              final allBons = snapshot.data ?? const [];
              final unpaid = allBons.where((b) => b.settledAt == null).toList();
              final paid = allBons.where((b) => b.settledAt != null).toList();

              return PageView(
                controller: _bonPageCtrl,
                onPageChanged: (page) => setState(() => _bonSubTab = page),
                children: [
                  _buildBonList(unpaid, isLunas: false, key: const PageStorageKey('bon_unpaid')),
                  _buildBonList(paid, isLunas: true, key: const PageStorageKey('bon_paid')),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBonList(List<Bon> bons, {required bool isLunas, Key? key}) {
    if (bons.isEmpty) {
      return QuestEmpty(
        title: isLunas ? 'Belum ada riwayat bon lunas.' : 'Semua bon sudah lunas!',
        hint: isLunas
            ? 'Bon yang sudah dilunasi akan tercatat di sini.'
            : 'Catat bon baru jika ada pinjam-meminjam uang.',
      );
    }

    return ListView.builder(
      key: key,
      padding: EdgeInsets.fromLTRB(
        Spacing.m,
        Spacing.xs,
        Spacing.m,
        96 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: bons.length,
      itemBuilder: (context, i) {
        final bon = bons[i];
        final isPiutang = bon.direction == BonDirection.lent;
        return Container(
          margin: const EdgeInsets.only(bottom: Spacing.s),
          decoration: BoxDecoration(
            color: context.q.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.q.line),
            boxShadow: AppShadows.card,
          ),
          child: InkWell(
            onTap: () => BonSheet.show(
              context,
              widget.repository,
              existing: bon,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.m),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isPiutang ? SeedColors.incomingTint : SeedColors.outgoingTint,
                      borderRadius: BorderRadius.circular(AppRadius.cell),
                    ),
                    child: Icon(
                      isPiutang ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded,
                      color: isPiutang ? context.q.good : context.q.bad,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: Spacing.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bon.person,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: context.q.text,
                          ),
                        ),
                        if (bon.note != null && bon.note!.isNotEmpty)
                          Text(
                            bon.note!,
                            style: context.qSmall(11.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          idDayMonth(bon.occurredAt),
                          style: context.qSmall(10.5),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            Money.format(bon.amount),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: isPiutang ? context.q.good : context.q.bad,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Quick Settle Button
                      InkWell(
                        onTap: () async {
                          if (bon.settledAt == null) {
                            await widget.repository.updateBon(
                              bon.id,
                              BonsCompanion(settledAt: Value(DateTime.now())),
                            );
                          } else {
                            await widget.repository.updateBon(
                              bon.id,
                              const BonsCompanion(settledAt: Value(null)),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: bon.settledAt == null
                                ? SeedColors.primaryLight
                                : context.q.surface2,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            bon.settledAt == null ? 'Lunasi' : 'Batal Lunas',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: bon.settledAt == null
                                  ? context.q.primary
                                  : context.q.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? context.q.primary : context.q.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? context.q.primary : context.q.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? Colors.white : context.q.text,
          ),
        ),
      ),
    );
  }
}
