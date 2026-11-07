import 'package:drift/drift.dart' show Value;
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
  int _subViewRevision = 0;
  int _filterRevision = 0;

  void _setBonView(bool show) {
    if (_showBonView != show) {
      HapticFeedback.selectionClick();
      setState(() {
        _showBonView = show;
        _subViewRevision++;
      });
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

  Future<void> _settleBon(Bon bon) async {
    if (bon.settledAt != null) {
      await widget.repository.updateBon(
        bon.id,
        const BonsCompanion(settledAt: Value(null)),
      );
      if (mounted) questSnack(context, 'Status lunas dibatalkan.');
      return;
    }

    final accounts = await widget.repository.getAccounts();
    if (!mounted) return;
    int? selectedAccountId = accounts.firstOrNull?.id;
    bool recordTx = accounts.isNotEmpty;

    final shouldSettle = await showQuestDialog<bool>(
      context,
      title: 'Lunasi Bon',
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          final isLent = bon.direction == BonDirection.lent;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tandai bon ${bon.person} (${Money.format(bon.amount)}) sebagai lunas?',
                style: context.qBody(13),
              ),
              if (accounts.isNotEmpty) ...[
                const SizedBox(height: Spacing.m),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: recordTx,
                  title: Text(
                    isLent
                        ? 'Catat uang masuk ke rekening'
                        : 'Catat uang keluar dari rekening',
                    style: context.qTitle(13),
                  ),
                  onChanged: (val) =>
                      setDialogState(() => recordTx = val ?? true),
                ),
                if (recordTx) ...[
                  const SizedBox(height: Spacing.xs),
                  DropdownButtonFormField<int>(
                    initialValue: selectedAccountId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Pilih Akun'),
                    items: [
                      for (final a in accounts)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.name} · ${a.kind.label}'),
                        ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => selectedAccountId = v),
                  ),
                ],
              ],
            ],
          );
        },
      ),
      actions: [
        QuestButton(
          label: 'Batal',
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context, false),
        ),
        QuestButton(
          label: 'Lunasi',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (shouldSettle != true || !mounted) return;

    await widget.repository.updateBon(
      bon.id,
      BonsCompanion(settledAt: Value(DateTime.now())),
    );

    if (recordTx && selectedAccountId != null) {
      final isLent = bon.direction == BonDirection.lent;
      final otherCatId = (await widget.repository.getCategories())
          .where((c) => c.name.toLowerCase() == 'lainnya')
          .firstOrNull
          ?.id;
      await widget.repository.addManual(
        amount: bon.amount,
        direction: isLent ? Direction.incoming : Direction.outgoing,
        kind: TxKind.payment,
        counterparty: isLent
            ? 'Pelunasan piutang: ${bon.person}'
            : 'Bayar utang ke: ${bon.person}',
        accountId: selectedAccountId,
        categoryId: otherCatId,
        occurredAt: DateTime.now(),
      );
      await widget.progress?.onTransactionRecorded();
    }

    if (mounted) {
      questSnack(context, 'Bon ${bon.person} berhasil dilunasi!');
    }
  }
  late DateTime _selectedMonth;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isSearchVisible = false;
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
    final effectiveToken = parentToken * 1000 + _subViewRevision;

    return Scaffold(
      backgroundColor: context.q.bg,
      body: SafeArea(
        bottom: false,
        child: QuestStage(
          token: effectiveToken,
          child: AnimatedSwitcher(
            duration: QuestMotion.medium,
            switchInCurve: QuestMotion.easeOut,
            switchOutCurve: QuestMotion.easeOut,
            child: KeyedSubtree(
              key: ValueKey<bool>(_showBonView),
              child: _showBonView ? _buildBonView() : _buildTransactionsView(),
            ),
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
                StreamBuilder<List<Bon>>(
                  stream: widget.repository.watchBons(),
                  builder: (context, snapshot) {
                    final bons = snapshot.data ?? const [];
                    final unsettledCount =
                        bons.where((b) => b.settledAt == null).length;

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                        const SizedBox(width: Spacing.xs),
                        // Bon Shortcut
                        QuestPress(
                          onTap: () => _setBonView(true),
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: unsettledCount > 0
                                  ? context.q.warnTint
                                  : context.q.surface,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                color: unsettledCount > 0
                                    ? context.q.warn.withValues(alpha: 0.3)
                                    : context.q.line.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.handshake_outlined,
                                  size: 15,
                                  color: unsettledCount > 0
                                      ? context.q.warn
                                      : context.q.muted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Bon',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: unsettledCount > 0
                                        ? context.q.warn
                                        : context.q.text,
                                  ),
                                ),
                                if (unsettledCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.q.warn,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '',
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
                        ),
                      ],
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

              Widget? summaryWidget;
              if (allItems.isNotEmpty) {
                summaryWidget = QuestTabEnter(
                  index: 3,
                  replayKey: _filterRevision,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Spacing.m, 0, Spacing.m, Spacing.s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.q.surface,
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                        border: Border.all(
                          color: context.q.line.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PEMASUKAN',
                                  style: context.qEyebrow(9).copyWith(color: context.q.good),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '+${Money.format(totalIn)}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: context.q.good,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 22,
                            color: context.q.line.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: Spacing.s),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PENGELUARAN',
                                  style: context.qEyebrow(9).copyWith(color: context.q.bad),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '-${Money.format(totalOut)}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: context.q.bad,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 22,
                            color: context.q.line.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: Spacing.s),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SELISIH',
                                  style: context.qEyebrow(9).copyWith(color: context.q.muted),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    (netCashflow >= 0 ? '+' : '') + Money.format(netCashflow),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: netCashflow >= 0 ? context.q.text : context.q.bad,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

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
              final days = grouped.keys.toList();

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
                      itemCount: days.length,
                      itemBuilder: (context, i) {
                        final day = days[i];
                        final items = grouped[day]!;
                        final dayTotalOut = items
                            .where((item) => item.tx.direction == Direction.outgoing)
                            .fold<int>(0, (sum, item) => sum + item.tx.amount);

                        final group = Column(
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
                        if (i >= 8) return group;
                        return QuestTabEnter(
                          index: 4 + i,
                          replayKey: _filterRevision,
                          child: group,
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

  // ── Sub-view Bon Utang & Piutang ──────────────────────────────────
  Widget _buildBonView() {
    return Column(
      children: [
        // Sub-view Header
        QuestTabEnter(
          index: 0,
          child: Padding(
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
                    child: QuestTabEnter(
                      index: 1,
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
                            child: QuestMoney(
                              amount: piutangTotal,
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
                  ),
                  const SizedBox(width: Spacing.s),
                  Expanded(
                    child: QuestTabEnter(
                      index: 2,
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
                            child: QuestMoney(
                              amount: utangTotal,
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
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: Spacing.s),

        // Sub Tabs: [Belum Lunas] vs [Lunas] via QuestSegmented
        QuestTabEnter(
          index: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.m),
            child: QuestSegmented<int>(
              selected: _bonSubTab,
              onChanged: (val) {
                HapticFeedback.selectionClick();
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
      return QuestTabEnter(
        index: 4,
        child: QuestEmpty(
          title: isLunas ? 'Belum ada riwayat bon lunas.' : 'Semua bon sudah lunas!',
          hint: isLunas
              ? 'Bon yang sudah dilunasi akan tercatat di sini.'
              : 'Catat bon baru jika ada pinjam-meminjam uang.',
        ),
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
        final card = Container(
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
                          child: QuestMoney(
                            amount: bon.amount,
                            alignment: Alignment.centerRight,
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
                        onTap: () => _settleBon(bon),
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
        if (i >= 8) return card;
        return QuestTabEnter(
          index: 4 + i,
          child: card,
        );
      },
    );
  }
}

class _TransactionFilterSheet extends StatefulWidget {
  const _TransactionFilterSheet({
    required this.initialDirection,
    required this.initialAccountId,
    required this.accounts,
  });

  final Direction? initialDirection;
  final int? initialAccountId;
  final List<Account> accounts;

  @override
  State<_TransactionFilterSheet> createState() =>
      _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<_TransactionFilterSheet> {
  late Direction? _direction;
  late int? _accountId;

  @override
  void initState() {
    super.initState();
    _direction = widget.initialDirection;
    _accountId = widget.initialAccountId;
  }

  bool get _hasFilter => _direction != null || _accountId != null;

  void _reset() {
    HapticFeedback.selectionClick();
    setState(() {
      _direction = null;
      _accountId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.l,
        Spacing.xs,
        Spacing.l,
        Spacing.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Judul + Reset
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filter Transaksi', style: context.qTitle(18)),
              if (_hasFilter)
                QuestPress(
                  onTap: _reset,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      'Reset',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: q.bad,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.m),

          // Section 1: Arah Transaksi
          Text(
            'JENIS TRANSAKSI',
            style: context.qEyebrow(10).copyWith(color: q.muted),
          ),
          const SizedBox(height: Spacing.xs),
          Row(
            children: [
              Expanded(
                child: _FilterOptionCard(
                  label: 'Semua',
                  icon: Icons.swap_vert_rounded,
                  selected: _direction == null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _direction = null);
                  },
                ),
              ),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: _FilterOptionCard(
                  label: 'Keluar',
                  icon: Icons.arrow_upward_rounded,
                  iconColor: q.bad,
                  selected: _direction == Direction.outgoing,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _direction = Direction.outgoing);
                  },
                ),
              ),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: _FilterOptionCard(
                  label: 'Masuk',
                  icon: Icons.arrow_downward_rounded,
                  iconColor: q.good,
                  selected: _direction == Direction.incoming,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _direction = Direction.incoming);
                  },
                ),
              ),
            ],
          ),

          if (widget.accounts.isNotEmpty) ...[
            const SizedBox(height: Spacing.m),
            // Section 2: Rekening / Akun
            Text(
              'AKUN / REKENING',
              style: context.qEyebrow(10).copyWith(color: q.muted),
            ),
            const SizedBox(height: Spacing.xs),
            Wrap(
              spacing: Spacing.xs,
              runSpacing: Spacing.xs,
              children: [
                _FilterOptionChip(
                  label: 'Semua Akun',
                  selected: _accountId == null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _accountId = null);
                  },
                ),
                for (final acc in widget.accounts)
                  _FilterOptionChip(
                    label: acc.name,
                    icon: switch (acc.kind) {
                      AccountKind.bank => Icons.account_balance_rounded,
                      AccountKind.ewallet => Icons.phone_android_rounded,
                      AccountKind.cash => Icons.payments_outlined,
                    },
                    selected: _accountId == acc.id,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _accountId = acc.id);
                    },
                  ),
              ],
            ),
          ],

          const SizedBox(height: Spacing.l),

          // Action Button
          QuestButton(
            label: 'Terapkan Filter',
            onPressed: () {
              Navigator.pop(
                context,
                (direction: _direction, accountId: _accountId),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterOptionCard extends StatelessWidget {
  const _FilterOptionCard({
    required this.label,
    required this.icon,
    this.iconColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color? iconColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: QuestMotion.fast,
        curve: QuestMotion.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? q.primary.withValues(alpha: 0.12) : q.surface,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(
            color: selected ? q.primary : q.line.withValues(alpha: 0.6),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? (iconColor ?? q.primary)
                  : (iconColor?.withValues(alpha: 0.7) ?? q.muted),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? q.primary : q.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterOptionChip extends StatelessWidget {
  const _FilterOptionChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: QuestMotion.fast,
        curve: QuestMotion.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? q.primary.withValues(alpha: 0.12) : q.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? q.primary : q.line.withValues(alpha: 0.6),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? q.primary : q.muted,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? q.primary : q.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
