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
import 'transaction_tile.dart';

/// Cocokkan transaksi dengan query: pihak, kategori, bank, jenis, nominal.
bool matchesQuery(TxWithCategory item, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final tx = item.tx;
  final haystacks = [
    tx.counterparty ?? '',
    item.category?.name ?? '',
    tx.bankId,
    tx.kind.label,
    tx.amount.toString(),
  ].map((s) => s.toLowerCase());
  return haystacks.any((h) => h.contains(q));
}

class TransaksiScreen extends StatefulWidget {
  const TransaksiScreen({
    super.key,
    required this.repository,
    this.progress,
    this.pipeline,
    this.ruleSet,
  });

  final LedgerRepository repository;
  final ProgressService? progress;
  final CapturePipeline? pipeline;
  final RuleSet? ruleSet;

  @override
  State<TransaksiScreen> createState() => TransaksiScreenState();
}

class TransaksiScreenState extends State<TransaksiScreen> {
  bool handleBack() {
    if (_showBonView) {
      setState(() => _showBonView = false);
      return true;
    }
    return false;
  }

  void showBon() {
    setState(() => _showBonView = true);
  }
  late DateTime _selectedMonth;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int? _selectedAccountId;
  Direction? _selectedDirection;
  bool _showBonView = false;
  int _bonSubTab = 0; // 0 = Belum Lunas, 1 = Lunas

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
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
  }

  void _openMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.q.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(Spacing.m),
        child: QuestMonthPicker(
          initialMonth: _selectedMonth,
          onChanged: (m) {
            Navigator.pop(ctx);
            setState(() => _selectedMonth = m);
          },
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
        child: _showBonView ? _buildBonView() : _buildTransactionsView(),
      ),
    );
  }

  Widget _buildTransactionsView() {
    final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month);
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);

    return Column(
      children: [
        // Top Header
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.m, Spacing.m, Spacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Transaksi', style: context.qTitle(20)),
                    Text(
                      'Riwayat lengkap pengeluaran & pemasukan',
                      style: context.qSmall(),
                    ),
                  ],
                ),
              ),

              // Button Bon Shortcut
              StreamBuilder<List<Bon>>(
                stream: widget.repository.watchBons(),
                builder: (context, snapshot) {
                  final bons = snapshot.data ?? const [];
                  final unsettledCount = bons.where((b) => b.settledAt == null).length;

                  return InkWell(
                    onTap: () => setState(() => _showBonView = true),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: unsettledCount > 0 ? const Color(0xFFFEF3C7) : context.q.surface2,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: unsettledCount > 0 ? const Color(0xFFFDE68A) : context.q.line,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.handshake_outlined,
                            size: 16,
                            color: unsettledCount > 0 ? const Color(0xFFD97706) : context.q.text,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Bon',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: unsettledCount > 0 ? const Color(0xFF92400E) : context.q.text,
                            ),
                          ),
                          if (unsettledCount > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: const BoxDecoration(
                                color: Color(0xFFD97706),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$unsettledCount',
                                style: const TextStyle(
                                  fontSize: 10,
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
            ],
          ),
        ),

        // Month Picker Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.m, vertical: Spacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _shiftMonth(-1),
              ),
              InkWell(
                onTap: _openMonthPicker,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        idMonthYear(_selectedMonth),
                        style: context.qTitle(15),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: context.q.muted),
                    ],
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => _shiftMonth(1),
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
                return const Center(child: CircularProgressIndicator());
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
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 52,
                        color: context.q.muted.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: Spacing.s),
                      Text(
                        'Tidak ada transaksi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.q.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Coba kata kunci pencarian yang lain.'
                            : 'Belum ada transaksi di bulan ${idMonthYear(_selectedMonth)}.',
                        style: context.qSmall(12),
                      ),
                    ],
                  ),
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
                onPressed: () => setState(() => _showBonView = false),
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
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Catat Bon'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.q.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                onPressed: () => BonSheet.show(context, widget.repository),
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
                      padding: const EdgeInsets.all(Spacing.m),
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
                              Text('PIUTANG', style: context.qEyebrow(10)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Money.format(piutangTotal),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: context.q.good,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text('Orang berutang ke kita', style: context.qSmall(10.5)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.s),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(Spacing.m),
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
                              Text('UTANG', style: context.qEyebrow(10)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Money.format(utangTotal),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: context.q.bad,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text('Kita berutang ke orang', style: context.qSmall(10.5)),
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

        // Sub Tabs: [Belum Lunas] vs [Lunas]
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.m),
          child: Container(
            decoration: BoxDecoration(
              color: context.q.surface2,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _bonSubTab = 0),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _bonSubTab == 0 ? context.q.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: _bonSubTab == 0 ? AppShadows.card : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Belum Lunas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _bonSubTab == 0 ? FontWeight.w800 : FontWeight.w600,
                          color: _bonSubTab == 0 ? context.q.text : context.q.muted,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _bonSubTab = 1),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _bonSubTab == 1 ? context.q.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: _bonSubTab == 1 ? AppShadows.card : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Lunas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _bonSubTab == 1 ? FontWeight.w800 : FontWeight.w600,
                          color: _bonSubTab == 1 ? context.q.text : context.q.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.s),

        // Bon List
        Expanded(
          child: StreamBuilder<List<Bon>>(
            stream: widget.repository.watchBons(),
            builder: (context, snapshot) {
              final allBons = snapshot.data ?? const [];
              final filtered = _bonSubTab == 0
                  ? allBons.where((b) => b.settledAt == null).toList()
                  : allBons.where((b) => b.settledAt != null).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    _bonSubTab == 0
                        ? 'Semua bon sudah lunas!'
                        : 'Belum ada riwayat bon yang dilunasi.',
                    style: context.qSmall(13),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  Spacing.m,
                  Spacing.xs,
                  Spacing.m,
                  96 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final bon = filtered[i];
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
                                Text(
                                  Money.format(bon.amount),
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    color: isPiutang ? context.q.good : context.q.bad,
                                    fontFeatures: const [FontFeature.tabularFigures()],
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
            },
          ),
        ),
      ],
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
