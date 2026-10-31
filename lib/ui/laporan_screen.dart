import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/buckets.dart' show AmountPoint, TrendBucket;
import '../core/buckets.dart' as bkt;
import '../core/dates_id.dart';
import '../game/progress.dart';
import '../models.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'month_picker.dart';
import 'range_calendar.dart';
import 'transaction_sheet.dart';
import 'transaction_tile.dart';
import 'quest.dart';
const _tabular = [FontFeature.tabularFigures()];

const List<String> _idMonthsFull = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// Halaman Laporan Finansial terstruktur:
/// 01 · Ringkasan Arus Kas (Neraca, Rasio Masuk/Keluar, KPI Harian)
/// 02 · Tren Arus Kas (Grafik Batang Interaktif dengan Skala & Inspector)
/// 03 · Komposisi Kategori (Stacked Bar Proporsional & Tabel Kategori)
/// 04 · Pengeluaran Terbesar (Top 5 Transaksi Periode Ini)
class LaporanScreen extends StatefulWidget {
  const LaporanScreen({
    super.key,
    required this.repository,
    this.progress,
  });

  final LedgerRepository repository;
  final ProgressService? progress;

  @override
  State<LaporanScreen> createState() => LaporanScreenState();
}

class LaporanScreenState extends State<LaporanScreen> {
  late DateTime _month;
  DateTimeRange? _customRange;
  int? _accountId;
  bool _showIncomingCategories = false;
  int? _selectedBucketIndex;

  int _reportRevision = 0;
  String _streamKey = '';
  late Stream<List<TxWithCategory>> _currentStream;
  late Stream<List<TxWithCategory>> _prevStream;
  late Stream<List<Account>> _accountsStream;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _accountsStream = widget.repository.watchAccounts();
    _syncStreams();
  }

  @override
  void didUpdateWidget(covariant LaporanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _accountsStream = widget.repository.watchAccounts();
      _streamKey = '';
      _syncStreams();
    }
  }

  ({DateTime start, DateTime end}) get _window {
    if (_customRange != null) {
      final s = _customRange!.start;
      final e = _customRange!.end;
      return (
        start: DateTime(s.year, s.month, s.day),
        end: DateTime(e.year, e.month, e.day + 1),
      );
    }
    return (
      start: DateTime(_month.year, _month.month),
      end: DateTime(_month.year, _month.month + 1),
    );
  }

  void _syncStreams() {
    final win = _window;
    final key = '${win.start.millisecondsSinceEpoch}|'
        '${win.end.millisecondsSinceEpoch}|$_accountId';
    if (key == _streamKey) return;
    _streamKey = key;

    _currentStream = widget.repository.watchBetweenWithCategory(
      win.start,
      win.end,
      accountId: _accountId,
    );

    final ({DateTime start, DateTime end}) prevWin;
    if (_customRange == null) {
      final prevMonth = DateTime(_month.year, _month.month - 1);
      final now = DateTime.now();
      final isCurrentMonth =
          _month.year == now.year && _month.month == now.month;
      if (isCurrentMonth) {
        final daysElapsed = now.day;
        final prevMonthEnd = DateTime(prevMonth.year, prevMonth.month + 1);
        final fairEnd = DateTime(prevMonth.year, prevMonth.month, daysElapsed + 1);
        prevWin = (
          start: prevMonth,
          end: fairEnd.isBefore(prevMonthEnd) ? fairEnd : prevMonthEnd,
        );
      } else {
        prevWin = (
          start: prevMonth,
          end: DateTime(prevMonth.year, prevMonth.month + 1),
        );
      }
    } else {
      final span = win.end.difference(win.start);
      prevWin = (start: win.start.subtract(span), end: win.start);
    }

    _prevStream = widget.repository.watchBetweenWithCategory(
      prevWin.start,
      prevWin.end,
      accountId: _accountId,
    );
  }

  String get _periodLabel {
    if (_customRange != null) {
      final s = _customRange!.start;
      final e = _customRange!.end;
      if (s.year == e.year) {
        return '${idDayMonth(s)} – ${idDayMonth(e)} ${e.year}';
      }
      return '${idDayMonth(s)} ${s.year} – ${idDayMonth(e)} ${e.year}';
    }
    final now = DateTime.now();
    final base = '${_idMonthsFull[_month.month - 1]} ${_month.year}';
    if (_month.year == now.year && _month.month == now.month) {
      return '$base (Bulan Ini)';
    }
    return base;
  }

  void _shiftMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      final base = _customRange != null
          ? DateTime(_customRange!.start.year, _customRange!.start.month)
          : _month;
      _customRange = null;
      _month = DateTime(base.year, base.month + delta);
      _selectedBucketIndex = null;
      _reportRevision++;
      _syncStreams();
    });
  }

  Future<void> _openPeriodPicker() async {
    final picked = await showModalBottomSheet<({DateTime? month, DateTimeRange? range})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.q.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (_) => _LaporanPeriodSheet(
        initialMonth: _month,
        initialRange: _customRange,
      ),
    );
    if (picked == null || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (picked.range != null) {
        _customRange = picked.range;
      } else if (picked.month != null) {
        _customRange = null;
        _month = picked.month!;
      }
      _selectedBucketIndex = null;
      _reportRevision++;
      _syncStreams();
    });
  }

  Future<void> _openAccountPicker(List<Account> accounts) async {
    final selected = await showModalBottomSheet<({int? id})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.q.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.s, Spacing.m, Spacing.m),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Text('Filter Rekening / Akun', style: context.qTitle(16)),
                const SizedBox(height: Spacing.s),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AccountOptionTile(
                          label: 'Semua Akun',
                          subtitle: 'Gabungan seluruh bank, e-wallet & tunai',
                          icon: Icons.layers_outlined,
                          selected: _accountId == null,
                          onTap: () => Navigator.pop(ctx, (id: null)),
                        ),
                        for (final acc in accounts)
                          _AccountOptionTile(
                            label: acc.name,
                            subtitle: switch (acc.kind) {
                              AccountKind.bank => 'Rekening Bank',
                              AccountKind.ewallet => 'E-Wallet',
                              AccountKind.cash => 'Dompet Tunai',
                            },
                            icon: switch (acc.kind) {
                              AccountKind.bank => Icons.account_balance_rounded,
                              AccountKind.ewallet => Icons.phone_android_rounded,
                              AccountKind.cash => Icons.payments_outlined,
                            },
                            selected: _accountId == acc.id,
                            onTap: () => Navigator.pop(ctx, (id: acc.id)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _accountId = selected.id;
      _reportRevision++;
      _syncStreams();
    });
  }

  void _openCategorySheet(_CategoryStat stat) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.q.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.s, Spacing.m, Spacing.s),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.q.muted.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  const SizedBox(height: Spacing.m),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: stat.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(stat.icon, color: stat.color, size: 20),
                      ),
                      const SizedBox(width: Spacing.s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stat.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.qTitle(16),
                            ),
                            Text(
                              '${stat.items.length} transaksi · $_periodLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.qSmall(12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Spacing.s),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: QuestMoney(
                            amount: stat.amount,
                            alignment: Alignment.centerRight,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: context.q.text,
                              fontFeatures: _tabular,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: context.q.line),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(Spacing.m),
                itemCount: stat.items.length,
                itemBuilder: (ctx, i) => TransactionTile(
                  item: stat.items[i],
                  repository: widget.repository,
                  progress: widget.progress,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncStreams();
    final win = _window;
    final parentToken = QuestStage.ofOrNull(context)?.token ?? 0;
    final reportStageToken = parentToken * 1000 + _reportRevision;

    return Scaffold(
      backgroundColor: context.q.bg,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Account>>(
          stream: _accountsStream,
          builder: (context, accSnap) {
            final accounts = accSnap.data ?? const <Account>[];
            final activeAccount = _accountId == null
                ? null
                : accounts
                      .cast<Account?>()
                      .firstWhere((a) => a?.id == _accountId, orElse: () => null);

            return StreamBuilder<List<TxWithCategory>>(
              stream: _currentStream,
              builder: (context, curSnap) {
                return StreamBuilder<List<TxWithCategory>>(
                  stream: _prevStream,
                  builder: (context, prevSnap) {
                    final waiting =
                        curSnap.connectionState == ConnectionState.waiting &&
                        !curSnap.hasData;
                    final rows = curSnap.data ?? const <TxWithCategory>[];
                    final prevRows = prevSnap.data ?? const <TxWithCategory>[];

                    final report = _ReportMetrics.compute(
                      rows: rows,
                      prevRows: prevRows,
                      start: win.start,
                      endExclusive: win.end,
                    );

                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        Spacing.m,
                        Spacing.m,
                        Spacing.m,
                        104 + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        // ── Top Bar: Title + Account Filter ────────────────
                        QuestTabEnter(
                          index: 0,
                          child:
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Laporan', style: context.qTitle(22)),
                                  Text(
                                    'Evaluasi arus kas & struktur pengeluaran',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.qSmall(12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: Spacing.s),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Material(
                                color: context.q.surface,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                child: InkWell(
                                  onTap: () => _openAccountPicker(accounts),
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppRadius.pill),
                                      border: Border.all(
                                        color: activeAccount != null
                                            ? context.q.primary.withValues(alpha: 0.4)
                                            : context.q.line,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.account_balance_wallet_outlined,
                                          size: 15,
                                          color: activeAccount != null
                                              ? context.q.primary
                                              : context.q.muted,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            activeAccount?.name ?? 'Semua Akun',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: activeAccount != null
                                                  ? context.q.primary
                                                  : context.q.text,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 16,
                                          color: context.q.muted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        ),
                        const SizedBox(height: Spacing.s + 4),

                        // ── Dedicated Full-Width Period Navigator Bar ──────
                        QuestTabEnter(
                          index: 1,
                          child:
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: context.q.surface,
                            borderRadius: BorderRadius.circular(AppRadius.tile),
                            border: Border.all(color: context.q.line),
                            boxShadow: AppShadows.card,
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
                                  onTap: _openPeriodPicker,
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
                                                _periodLabel,
                                                key: ValueKey(_periodLabel),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w800,
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
                        ),
                        const SizedBox(height: Spacing.l),

                        if (waiting)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(Spacing.xl),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else ...[
                          QuestStage(
                            token: reportStageToken,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ── 01 · RINGKASAN ARUS KAS ────────────────
                                QuestTabEnter(
                                  index: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const _ReportSectionHeader(
                                        step: '01',
                                        title: 'RINGKASAN ARUS KAS',
                                      ),
                                      const SizedBox(height: Spacing.xs + 2),
                                      _ExecutiveSummaryCard(metrics: report),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: Spacing.l),

                                if (!report.hasAnyActivity)
                                  QuestTabEnter(
                                    index: 3,
                                    child: _EmptyPeriodCard(
                                      periodLabel: _periodLabel,
                                    ),
                                  )
                                else ...[
                                  // ── 02 · TREN ARUS KAS ───────────────────
                                  QuestTabEnter(
                                    index: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const _ReportSectionHeader(
                                          step: '02',
                                          title: 'TREN ARUS KAS',
                                        ),
                                        const SizedBox(height: Spacing.xs + 2),
                                        _InteractiveTrendCard(
                                          buckets: report.trendBuckets,
                                          isMonthlyGranularity:
                                              report.isMonthlyTrend,
                                          selectedIndex: _selectedBucketIndex,
                                          onSelectIndex: (idx) {
                                            if (_selectedBucketIndex == idx) {
                                              return;
                                            }
                                            HapticFeedback.selectionClick();
                                            setState(
                                              () => _selectedBucketIndex = idx,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: Spacing.l),

                                  // ── 03 · KOMPOSISI KATEGORI ──────────────
                                  QuestTabEnter(
                                    index: 4,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const _ReportSectionHeader(
                                          step: '03',
                                          title: 'KOMPOSISI KATEGORI',
                                        ),
                                        const SizedBox(height: Spacing.xs + 2),
                                        _CategoryStructureCard(
                                          showIncoming: _showIncomingCategories,
                                          onToggleMode: (val) {
                                            if (_showIncomingCategories ==
                                                val) {
                                              return;
                                            }
                                            HapticFeedback.selectionClick();
                                            setState(
                                              () => _showIncomingCategories =
                                                  val,
                                            );
                                          },
                                          outStats: report.outCategories,
                                          inStats: report.inCategories,
                                          totalOut: report.totalOut,
                                          totalIn: report.totalIn,
                                          outTxCount: report.outCount,
                                          inTxCount: report.inCount,
                                          onCategoryTap: _openCategorySheet,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ── 04 · PENGELUARAN TERBESAR ────────────
                                  if (report.topExpenses.isNotEmpty) ...[
                                    const SizedBox(height: Spacing.l),
                                    QuestTabEnter(
                                      index: 5,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const _ReportSectionHeader(
                                            step: '04',
                                            title: 'PENGELUARAN TERBESAR',
                                          ),
                                          const SizedBox(
                                            height: Spacing.xs + 2,
                                          ),
                                          _TopExpensesTableCard(
                                            items: report.topExpenses,
                                            totalOut: report.totalOut,
                                            repository: widget.repository,
                                            progress: widget.progress,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA COMPUTATION MODEL
// ═══════════════════════════════════════════════════════════════════════════

class _CategoryStat {
  const _CategoryStat({
    required this.id,
    required this.name,
    required this.amount,
    required this.color,
    required this.icon,
    required this.items,
  });

  final int? id;
  final String name;
  final int amount;
  final Color color;
  final IconData icon;
  final List<TxWithCategory> items;
}

class _ReportMetrics {
  const _ReportMetrics({
    required this.totalIn,
    required this.totalOut,
    required this.inCount,
    required this.outCount,
    required this.prevIn,
    required this.prevOut,
    required this.activeDaysSpan,
    required this.outCategories,
    required this.inCategories,
    required this.trendBuckets,
    required this.isMonthlyTrend,
    required this.topExpenses,
  });

  final int totalIn;
  final int totalOut;
  final int inCount;
  final int outCount;
  final int prevIn;
  final int prevOut;
  final int activeDaysSpan;
  final List<_CategoryStat> outCategories;
  final List<_CategoryStat> inCategories;
  final List<TrendBucket> trendBuckets;
  final bool isMonthlyTrend;
  final List<TxWithCategory> topExpenses;

  int get net => totalIn - totalOut;
  bool get isSurplus => net >= 0;
  bool get hasAnyActivity => inCount > 0 || outCount > 0;

  int? get savingsRatePercent {
    if (totalIn <= 0) return null;
    return ((net / totalIn) * 100).round();
  }

  int get avgDailyOut =>
      activeDaysSpan > 0 ? (totalOut / activeDaysSpan).round() : 0;

  int get avgPerOutTx => outCount > 0 ? (totalOut / outCount).round() : 0;

  int? get outDeltaPercent {
    if (prevOut <= 0) return null;
    return (((totalOut - prevOut) * 100) / prevOut).round();
  }

  int? get inDeltaPercent {
    if (prevIn <= 0) return null;
    return (((totalIn - prevIn) * 100) / prevIn).round();
  }

  static _ReportMetrics compute({
    required List<TxWithCategory> rows,
    required List<TxWithCategory> prevRows,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    var totalIn = 0;
    var totalOut = 0;
    var inCount = 0;
    var outCount = 0;

    final outByCat = <int?, List<TxWithCategory>>{};
    final inByCat = <int?, List<TxWithCategory>>{};
    final catMeta = <int?, Category?>{};
    final points = <AmountPoint>[];
    final pureExpenses = <TxWithCategory>[];

    for (final r in rows) {
      if (r.tx.direction == Direction.incoming) {
        totalIn += r.tx.amount;
        inCount++;
        final key = r.category?.id;
        catMeta[key] = r.category;
        inByCat.putIfAbsent(key, () => []).add(r);
        points.add((
          at: r.tx.occurredAt,
          direction: Direction.incoming,
          amount: r.tx.amount,
        ));
      } else if (r.tx.kind != TxKind.transfer) {
        totalOut += r.tx.amount;
        outCount++;
        final key = r.category?.id;
        catMeta[key] = r.category;
        outByCat.putIfAbsent(key, () => []).add(r);
        pureExpenses.add(r);
        points.add((
          at: r.tx.occurredAt,
          direction: Direction.outgoing,
          amount: r.tx.amount,
        ));
      }
    }

    var prevIn = 0;
    var prevOut = 0;
    for (final r in prevRows) {
      if (r.tx.direction == Direction.incoming) {
        prevIn += r.tx.amount;
      } else if (r.tx.kind != TxKind.transfer) {
        prevOut += r.tx.amount;
      }
    }

    List<_CategoryStat> buildStats(Map<int?, List<TxWithCategory>> grouped) {
      final list = <_CategoryStat>[];
      for (final entry in grouped.entries) {
        final cat = catMeta[entry.key];
        final sum = entry.value.fold<int>(0, (s, e) => s + e.tx.amount);
        final sortedItems = [...entry.value]
          ..sort((a, b) => b.tx.occurredAt.compareTo(a.tx.occurredAt));
        list.add(
          _CategoryStat(
            id: cat?.id,
            name: cat?.name ?? 'Tanpa Kategori',
            amount: sum,
            color: cat == null
                ? const Color(0xFF94A3B8)
                : SeedColors.categoryColor(cat.colorIndex),
            icon: _iconForCategory(cat),
            items: sortedItems,
          ),
        );
      }
      list.sort((a, b) => b.amount.compareTo(a.amount));
      return list;
    }

    pureExpenses.sort((a, b) => b.tx.amount.compareTo(a.tx.amount));

    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day + 1);
    final effectiveEnd =
        endExclusive.isAfter(todayEnd) && start.isBefore(todayEnd)
            ? todayEnd
            : endExclusive;
    final activeDays = math.max(1, effectiveEnd.difference(start).inDays);

    final endInclusive = endExclusive.subtract(const Duration(days: 1));
    final spanDays = endInclusive.difference(start).inDays;
    final buckets = bkt.trendBuckets(points, start, endInclusive);

    return _ReportMetrics(
      totalIn: totalIn,
      totalOut: totalOut,
      inCount: inCount,
      outCount: outCount,
      prevIn: prevIn,
      prevOut: prevOut,
      activeDaysSpan: activeDays,
      outCategories: buildStats(outByCat),
      inCategories: buildStats(inByCat),
      trendBuckets: buckets,
      isMonthlyTrend: spanDays > 62,
      topExpenses: pureExpenses.take(5).toList(),
    );
  }
}

IconData _iconForCategory(Category? cat) {
  if (cat == null) return Icons.label_outline_rounded;
  final lower = cat.name.toLowerCase();
  if (lower.contains('makan') ||
      lower.contains('minum') ||
      lower.contains('kopi')) {
    return Icons.restaurant_rounded;
  }
  if (lower.contains('transport') ||
      lower.contains('bensin') ||
      lower.contains('ojek')) {
    return Icons.directions_car_rounded;
  }
  if (lower.contains('tagihan') ||
      lower.contains('listrik') ||
      lower.contains('internet')) {
    return Icons.receipt_long_rounded;
  }
  if (lower.contains('belanja') || lower.contains('pasar')) {
    return Icons.shopping_bag_rounded;
  }
  if (lower.contains('hiburan') || lower.contains('game')) {
    return Icons.movie_rounded;
  }
  if (lower.contains('sehat') || lower.contains('obat')) {
    return Icons.favorite_rounded;
  }
  if (lower.contains('gaji') || lower.contains('upah')) {
    return Icons.payments_rounded;
  }
  if (lower.contains('transfer')) {
    return Icons.swap_horiz_rounded;
  }
  return switch (cat.colorIndex % 9) {
    0 => Icons.restaurant_rounded,
    1 => Icons.directions_car_rounded,
    2 => Icons.receipt_long_rounded,
    3 => Icons.shopping_bag_rounded,
    4 => Icons.movie_rounded,
    5 => Icons.favorite_rounded,
    6 => Icons.payments_rounded,
    7 => Icons.swap_horiz_rounded,
    _ => Icons.category_rounded,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION HEADER & CARDS
// ═══════════════════════════════════════════════════════════════════════════

class _ReportSectionHeader extends StatelessWidget {
  const _ReportSectionHeader({
    this.step,
    required this.title,
  });

  final String? step;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.s),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.qEyebrow(11),
      ),
    );
  }
}

/// 01 · Kartu Ringkasan Arus Kas Terstruktur
class _ExecutiveSummaryCard extends StatelessWidget {
  const _ExecutiveSummaryCard({required this.metrics});

  final _ReportMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final isSurplus = metrics.isSurplus;
    final savingsPct = metrics.savingsRatePercent;
    final badgeText = !metrics.hasAnyActivity
        ? 'Belum ada aktivitas'
        : isSurplus
            ? (savingsPct != null && savingsPct > 0
                ? 'Surplus · Hemat $savingsPct%'
                : 'Surplus')
            : 'Defisit';

    final sumFlow = metrics.totalIn + metrics.totalOut;

    return Container(
      decoration: BoxDecoration(
        color: context.q.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.q.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Net Cashflow Block
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.m, Spacing.m, Spacing.s + 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Selisih Arus Kas Bersih',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.qSmall(12.5),
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: !metrics.hasAnyActivity
                              ? context.q.surface2
                              : isSurplus
                                  ? SeedColors.incomingTint
                                  : SeedColors.outgoingTint,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          badgeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: !metrics.hasAnyActivity
                                ? context.q.muted
                                : isSurplus
                                    ? context.q.good
                                    : context.q.bad,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: QuestMoney(
                    amount: metrics.net.abs(),
                    prefix: metrics.net == 0
                        ? ''
                        : (isSurplus ? '+' : '−'),
                    style: context.qDisplay(28).copyWith(
                      color: metrics.net == 0
                          ? context.q.text
                          : isSurplus
                              ? context.q.good
                              : context.q.bad,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.s + 4),

                // Proportional Dual Bar (Pemasukan vs Pengeluaran)
                _SegmentedBar(
                  height: 8,
                  emptyColor: context.q.surface2,
                  segments: sumFlow == 0
                      ? const []
                      : [
                          if (metrics.totalIn > 0)
                            (weight: metrics.totalIn, color: context.q.good),
                          if (metrics.totalOut > 0)
                            (weight: metrics.totalOut, color: context.q.bad),
                        ],
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 1, color: context.q.line),

          // Middle 2-Column Grid: Pemasukan | Pengeluaran
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _FlowHalfCell(
                    label: 'PEMASUKAN',
                    amount: metrics.totalIn,
                    txCount: metrics.inCount,
                    deltaPercent: metrics.inDeltaPercent,
                    deltaGoodWhenPositive: true,
                    color: context.q.good,
                    icon: Icons.south_west_rounded,
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: context.q.line),
                Expanded(
                  child: _FlowHalfCell(
                    label: 'PENGELUARAN',
                    amount: metrics.totalOut,
                    txCount: metrics.outCount,
                    deltaPercent: metrics.outDeltaPercent,
                    deltaGoodWhenPositive: false,
                    color: context.q.bad,
                    icon: Icons.north_east_rounded,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 1, color: context.q.line),

          // Bottom KPI Strip: Rata-rata Harian | Rata-rata per Transaksi
          Container(
            decoration: BoxDecoration(
              color: context.q.surface2.withValues(alpha: 0.55),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.card),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.m,
                        vertical: 11,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rata-rata Keluar / Hari',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.qSmall(11),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: QuestMoney(
                              amount: metrics.avgDailyOut,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: context.q.text,
                                fontFeatures: _tabular,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: context.q.line),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.m,
                        vertical: 11,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rata-rata / Transaksi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.qSmall(11),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: QuestMoney(
                              amount: metrics.avgPerOutTx,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: context.q.text,
                                fontFeatures: _tabular,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowHalfCell extends StatelessWidget {
  const _FlowHalfCell({
    required this.label,
    required this.amount,
    required this.txCount,
    required this.deltaPercent,
    required this.deltaGoodWhenPositive,
    required this.color,
    required this.icon,
  });

  final String label;
  final int amount;
  final int txCount;
  final int? deltaPercent;
  final bool deltaGoodWhenPositive;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final delta = deltaPercent;
    final bool? isGood = delta == null || delta == 0
        ? null
        : (delta > 0 ? deltaGoodWhenPositive : !deltaGoodWhenPositive);

    return Padding(
      padding: const EdgeInsets.all(Spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.qEyebrow(10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: QuestMoney(
              amount: amount,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: context.q.text,
                fontFeatures: _tabular,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '$txCount trx',
                style: context.qSmall(11),
              ),
              if (delta != null && delta != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: (isGood ?? true)
                        ? SeedColors.incomingTint
                        : SeedColors.outgoingTint,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${delta > 0 ? '↑' : '↓'}${delta.abs()}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: (isGood ?? true) ? context.q.good : context.q.bad,
                      fontFeatures: _tabular,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 02 · Kartu Tren Arus Kas Interaktif
class _InteractiveTrendCard extends StatelessWidget {
  const _InteractiveTrendCard({
    required this.buckets,
    required this.isMonthlyGranularity,
    required this.selectedIndex,
    required this.onSelectIndex,
  });

  final List<TrendBucket> buckets;
  final bool isMonthlyGranularity;
  final int? selectedIndex;
  final ValueChanged<int> onSelectIndex;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return const SizedBox.shrink();

    int defaultIdx = buckets.length - 1;
    for (var i = buckets.length - 1; i >= 0; i--) {
      if (buckets[i].incoming > 0 || buckets[i].outgoing > 0) {
        defaultIdx = i;
        break;
      }
    }
    final activeIdx = (selectedIndex != null &&
            selectedIndex! >= 0 &&
            selectedIndex! < buckets.length)
        ? selectedIndex!
        : defaultIdx;
    final activeBucket = buckets[activeIdx];
    final maxVal = buckets.fold<int>(
      0,
      (m, b) => math.max(m, math.max(b.incoming, b.outgoing)),
    );

    return Container(
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
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                isMonthlyGranularity ? 'Perbandingan Bulanan' : 'Perbandingan Mingguan',
                style: context.qTitle(15),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniLegend(color: context.q.good, label: 'Masuk'),
                  const SizedBox(width: 10),
                  _MiniLegend(color: context.q.bad, label: 'Keluar'),
                ],
              ),
            ],
          ),
          const SizedBox(height: Spacing.s + 2),

          // Selected Bucket Inspector Strip (Wrap = zero overflow)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: context.q.surface2,
              borderRadius: BorderRadius.circular(AppRadius.cell),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                QuestSwap(
                  slide: false,
                  child: Text(
                    isMonthlyGranularity
                        ? 'Bulan ${activeBucket.label}'
                        : 'Mulai ${activeBucket.label}',
                    key: ValueKey('lbl-$activeIdx-${activeBucket.label}'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: context.q.text,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    QuestMoney(
                      amount: activeBucket.incoming,
                      prefix: '+',
                      duration: QuestMotion.medium,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.q.good,
                        fontFeatures: _tabular,
                      ),
                    ),
                    QuestMoney(
                      amount: activeBucket.outgoing,
                      prefix: '−',
                      duration: QuestMotion.medium,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.q.bad,
                        fontFeatures: _tabular,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),

          // Interactive Chart Canvas
          SizedBox(
            height: 176,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const yAxisWidth = 46.0;
                final plotWidth = math.max(1.0, constraints.maxWidth - yAxisWidth);

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final dx = details.localPosition.dx - yAxisWidth;
                    if (dx < 0) return;
                    final idx = (dx / (plotWidth / buckets.length))
                        .floor()
                        .clamp(0, buckets.length - 1);
                    onSelectIndex(idx);
                  },
                  child: QuestReplay(
                    duration:
                        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
                        ? Duration.zero
                        : const Duration(milliseconds: 720),
                    curve: Curves.linear,
                    builder: (context, chartProgress) => CustomPaint(
                      size: Size(constraints.maxWidth, 176),
                      painter: _StructuredTrendPainter(
                        buckets: buckets,
                        maxValue: maxVal,
                        selectedIndex: activeIdx,
                        progress: chartProgress,
                        yAxisWidth: yAxisWidth,
                        inColor: context.q.good,
                        outColor: context.q.bad,
                        gridColor: context.q.line,
                        highlightColor:
                            SeedColors.primaryLight.withValues(alpha: 0.7),
                        labelColor: context.q.muted,
                        activeLabelColor: context.q.primary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLegend extends StatelessWidget {
  const _MiniLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: context.qSmall(11)),
      ],
    );
  }
}

class _StructuredTrendPainter extends CustomPainter {
  _StructuredTrendPainter({
    required this.buckets,
    required this.maxValue,
    required this.selectedIndex,
    required this.progress,
    required this.yAxisWidth,
    required this.inColor,
    required this.outColor,
    required this.gridColor,
    required this.highlightColor,
    required this.labelColor,
    required this.activeLabelColor,
  });

  final List<TrendBucket> buckets;
  final int maxValue;
  final int selectedIndex;
  final double progress;
  final double yAxisWidth;
  final Color inColor;
  final Color outColor;
  final Color gridColor;
  final Color highlightColor;
  final Color labelColor;
  final Color activeLabelColor;

  static String _compactAxis(int v) {
    if (v <= 0) return '0';
    if (v >= 1000000000) {
      return '${(v / 1000000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
    if (v >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1).replaceAll('.0', '')}jt';
    }
    if (v >= 1000) {
      return '${(v / 1000).round()}rb';
    }
    return '$v';
  }

  @override
  void paint(Canvas canvas, Size size) {
    const topPad = 8.0;
    const bottomAxisH = 24.0;
    final chartH = size.height - topPad - bottomAxisH;
    final plotW = math.max(1.0, size.width - yAxisWidth);
    final effectiveMax = maxValue > 0 ? maxValue : 100000;

    // 1. Horizontal Gridlines + Y-Axis Labels (Top, Mid, Zero)
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final levels = [
      (y: topPad, val: effectiveMax),
      (y: topPad + chartH / 2, val: (effectiveMax / 2).round()),
      (y: topPad + chartH, val: 0),
    ];

    for (final lvl in levels) {
      canvas.drawLine(
        Offset(yAxisWidth, lvl.y),
        Offset(size.width, lvl.y),
        gridPaint,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: _compactAxis(lvl.val),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: labelColor,
            fontFeatures: _tabular,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: yAxisWidth - 6);
      tp.paint(
        canvas,
        Offset(yAxisWidth - tp.width - 6, lvl.y - tp.height / 2),
      );
    }

    if (buckets.isEmpty) return;

    final groupW = plotW / buckets.length;
    final barW = (groupW * 0.28).clamp(5.0, 16.0);
    const barGap = 3.0;
    final labelStride = buckets.length > 8 ? (buckets.length / 5).ceil() : 1;

    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final groupLeft = yAxisWidth + i * groupW;
      final centerX = groupLeft + groupW / 2;
      final isSelected = i == selectedIndex;

      // Active column highlight band
      if (isSelected) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(groupLeft + 2, 0, math.max(0, groupW - 4), chartH + topPad),
            const Radius.circular(8),
          ),
          Paint()..color = highlightColor,
        );
      }

      final baseY = topPad + chartH;
      final spread =
          buckets.length > 1 ? (i / (buckets.length - 1)) * 0.34 : 0.0;
      final localRaw = ((progress - spread) / (1.0 - spread)).clamp(0.0, 1.0);
      final barProgress = Curves.easeOutCubic.transform(localRaw);

      // Incoming bar
      if (b.incoming > 0 && maxValue > 0 && barProgress > 0) {
        final h =
            math.max(4.0, (b.incoming / maxValue) * chartH) * barProgress;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(centerX - barGap / 2 - barW, baseY - h, barW, h),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()..color = inColor,
        );
      }

      // Outgoing bar
      if (b.outgoing > 0 && maxValue > 0 && barProgress > 0) {
        final h =
            math.max(4.0, (b.outgoing / maxValue) * chartH) * barProgress;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(centerX + barGap / 2, baseY - h, barW, h),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()..color = outColor,
        );
      }

      // X-axis label (strided so labels never collide)
      if (i % labelStride == 0 || isSelected || i == buckets.length - 1) {
        if (!isSelected &&
            i == buckets.length - 1 &&
            labelStride > 1 &&
            (i % labelStride) < (labelStride ~/ 2)) {
          continue;
        }
        final xTp = TextPainter(
          text: TextSpan(
            text: b.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? activeLabelColor : labelColor,
            ),
          ),
          maxLines: 1,
          ellipsis: '…',
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: math.max(groupW * labelStride - 2, 36));
        final double clampedX = (centerX - xTp.width / 2)
            .clamp(yAxisWidth, math.max(yAxisWidth, size.width - xTp.width))
            .toDouble();
        xTp.paint(canvas, Offset(clampedX, baseY + 6));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StructuredTrendPainter oldDelegate) =>
      oldDelegate.maxValue != maxValue ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.progress != progress ||
      oldDelegate.buckets.length != buckets.length;
}

/// 03 · Kartu Komposisi Kategori (Stacked Bar + Tabel Terstruktur)
class _CategoryStructureCard extends StatelessWidget {
  const _CategoryStructureCard({
    required this.showIncoming,
    required this.onToggleMode,
    required this.outStats,
    required this.inStats,
    required this.totalOut,
    required this.totalIn,
    required this.outTxCount,
    required this.inTxCount,
    required this.onCategoryTap,
  });

  final bool showIncoming;
  final ValueChanged<bool> onToggleMode;
  final List<_CategoryStat> outStats;
  final List<_CategoryStat> inStats;
  final int totalOut;
  final int totalIn;
  final int outTxCount;
  final int inTxCount;
  final ValueChanged<_CategoryStat> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final activeStats = showIncoming ? inStats : outStats;
    final activeTotal = showIncoming ? totalIn : totalOut;

    return Container(
      decoration: BoxDecoration(
        color: context.q.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.q.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                QuestSegmented<bool>(
                  selected: showIncoming,
                  onChanged: onToggleMode,
                  options: [
                    (
                      value: false,
                      label: 'Pengeluaran ($outTxCount)',
                      icon: null,
                    ),
                    (
                      value: true,
                      label: 'Pemasukan ($inTxCount)',
                      icon: null,
                    ),
                  ],
                ),

                if (activeStats.isEmpty || activeTotal <= 0) ...[
                  const SizedBox(height: Spacing.l),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Spacing.m),
                      child: Column(
                        children: [
                          Icon(
                            Icons.pie_chart_outline_rounded,
                            size: 36,
                            color: context.q.muted.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            showIncoming
                                ? 'Belum ada pemasukan di periode ini'
                                : 'Belum ada pengeluaran di periode ini',
                            textAlign: TextAlign.center,
                            style: context.qSmall(12.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: Spacing.m),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          showIncoming
                              ? 'Distribusi ${activeStats.length} Kategori Masuk'
                              : 'Distribusi ${activeStats.length} Kategori Keluar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.qSmall(12),
                        ),
                      ),
                      const SizedBox(width: Spacing.s),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: QuestMoney(
                            amount: activeTotal,
                            alignment: Alignment.centerRight,
                            replayKey: showIncoming,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: context.q.text,
                              fontFeatures: _tabular,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Multi-Segment Proportional Stacked Bar
                  _SegmentedBar(
                    height: 12,
                    emptyColor: context.q.surface2,
                    replayKey: showIncoming,
                    segments: [
                      for (final s in activeStats)
                        (weight: s.amount, color: s.color),
                    ],
                  ),
                ],
              ],
            ),
          ),

          AnimatedSize(
            duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
                ? Duration.zero
                : QuestMotion.medium,
            curve: QuestMotion.easeOut,
            alignment: Alignment.topCenter,
            child: (activeStats.isNotEmpty && activeTotal > 0)
                ? Column(
                    children: [
                      Divider(height: 1, thickness: 1, color: context.q.line),
                      for (var i = 0; i < activeStats.length; i++) ...[
                        _CategoryTableRow(
                          stat: activeStats[i],
                          grandTotal: activeTotal,
                          replayKey: showIncoming,
                          onTap: () => onCategoryTap(activeStats[i]),
                        ),
                        if (i < activeStats.length - 1)
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 66,
                            color: context.q.line,
                          ),
                      ],
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _CategoryTableRow extends StatelessWidget {
  const _CategoryTableRow({
    required this.stat,
    required this.grandTotal,
    required this.onTap,
    this.replayKey,
  });

  final _CategoryStat stat;
  final int grandTotal;
  final VoidCallback onTap;
  final Object? replayKey;
  @override
  Widget build(BuildContext context) {
    final share = grandTotal > 0 ? (stat.amount / grandTotal).clamp(0.0, 1.0) : 0.0;
    final pct = (share * 100).round();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.m, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: stat.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(stat.icon, size: 19, color: stat.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: context.q.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 125),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: QuestMoney(
                            amount: stat.amount,
                            alignment: Alignment.centerRight,
                            replayKey: replayKey,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: context.q.text,
                              fontFeatures: _tabular,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: QuestProgressBar(
                          value: share,
                          color: stat.color,
                          minHeight: 5,
                          replayKey: replayKey,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 96),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: QuestCountUp(
                            value: pct,
                            replayKey: replayKey,
                            builder: (context, currentPct) => Text(
                              '$currentPct% · ${stat.items.length} trx',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.q.muted,
                                fontFeatures: _tabular,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.q.muted.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// 04 · Tabel 5 Pengeluaran Terbesar
class _TopExpensesTableCard extends StatelessWidget {
  const _TopExpensesTableCard({
    required this.items,
    required this.totalOut,
    required this.repository,
    this.progress,
  });

  final List<TxWithCategory> items;
  final int totalOut;
  final LedgerRepository repository;
  final ProgressService? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.q.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.q.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _TopExpenseRow(
              rank: i + 1,
              item: items[i],
              totalOut: totalOut,
              onTap: () => TransactionSheet.show(
                context,
                repository,
                existing: items[i],
                progress: progress,
              ),
            ),
            if (i < items.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 56,
                color: context.q.line,
              ),
          ],
        ],
      ),
    );
  }
}

class _TopExpenseRow extends StatelessWidget {
  const _TopExpenseRow({
    required this.rank,
    required this.item,
    required this.totalOut,
    required this.onTap,
  });

  final int rank;
  final TxWithCategory item;
  final int totalOut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tx = item.tx;
    final party = (tx.counterparty != null && tx.counterparty!.trim().isNotEmpty)
        ? tx.counterparty!.trim()
        : (tx.rawTitle != null && tx.rawTitle!.trim().isNotEmpty)
            ? tx.rawTitle!.trim()
            : tx.kind.label;
    final catName = item.category?.name ?? 'Tanpa Kategori';
    final sharePct = totalOut > 0 ? ((tx.amount / totalOut) * 100).round() : 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.m, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rank == 1 ? SeedColors.outgoingTint : context.q.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: rank == 1 ? context.q.bad : context.q.muted,
                  fontFeatures: _tabular,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    party,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: context.q.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${idDayMonth(tx.occurredAt)} · $catName · $sharePct% total',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.qSmall(11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: QuestMoney(
                  amount: tx.amount,
                  prefix: '−',
                  alignment: Alignment.centerRight,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: context.q.bad,
                    fontFeatures: _tabular,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPeriodCard extends StatelessWidget {
  const _EmptyPeriodCard({required this.periodLabel});

  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.l, vertical: Spacing.xl),
      decoration: BoxDecoration(
        color: context.q.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.q.line),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.q.surface2,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.insert_chart_outlined_rounded,
              color: context.q.muted,
              size: 24,
            ),
          ),
          const SizedBox(height: Spacing.s + 4),
          Text(
            'Belum ada data untuk $periodLabel',
            textAlign: TextAlign.center,
            style: context.qTitle(15),
          ),
          const SizedBox(height: 4),
          Text(
            'Catat pemasukan atau pengeluaran menggunakan tombol (+) di bawah untuk melihat grafik tren dan komposisi kategori.',
            textAlign: TextAlign.center,
            style: context.qSmall(12),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHEETS: ACCOUNT OPTION & PERIOD PICKER
// ═══════════════════════════════════════════════════════════════════════════

class _AccountOptionTile extends StatelessWidget {
  const _AccountOptionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected ? SeedColors.primaryLight : context.q.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? context.q.primary : context.q.muted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.q.text,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.qSmall(11.5),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: context.q.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _LaporanPeriodSheet extends StatefulWidget {
  const _LaporanPeriodSheet({
    required this.initialMonth,
    required this.initialRange,
  });

  final DateTime initialMonth;
  final DateTimeRange? initialRange;

  @override
  State<_LaporanPeriodSheet> createState() => _LaporanPeriodSheetState();
}

class _LaporanPeriodSheetState extends State<_LaporanPeriodSheet> {
  late bool _customMode = widget.initialRange != null;
  late DateTimeRange? _range = widget.initialRange;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
            Text('Pilih Periode Laporan', style: context.qTitle(16)),
            const SizedBox(height: Spacing.s),
            QuestSegmented<bool>(
              selected: _customMode,
              onChanged: (val) => setState(() => _customMode = val),
              options: const [
                (value: false, label: 'Per Bulan', icon: null),
                (value: true, label: 'Rentang Tanggal', icon: null),
              ],
            ),
            const SizedBox(height: Spacing.m),
            AnimatedSize(
              duration: QuestMotion.fast,
              curve: QuestMotion.easeOut,
              alignment: Alignment.topCenter,
              child: !_customMode
                  ? QuestMonthPicker(
                      initialMonth: widget.initialMonth,
                      onChanged: (m) => Navigator.pop(context, (month: m, range: null)),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QuestRangeCalendar(
                          initialRange: _range,
                          onChanged: (r) => setState(() => _range = r),
                        ),
                        const SizedBox(height: Spacing.m),
                        QuestButton(
                          label: 'Terapkan Rentang',
                          icon: Icons.check_rounded,
                          onPressed: _range == null
                              ? null
                              : () => Navigator.pop(context, (month: null, range: _range)),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({
    required this.height,
    required this.emptyColor,
    required this.segments,
    this.replayKey,
  });

  final double height;
  final Color emptyColor;
  final List<({int weight, Color color})> segments;
  final Object? replayKey;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: QuestReplay(
          duration: reduced ? Duration.zero : QuestMotion.grow,
          replayKey: replayKey,
          builder: (context, progress) => CustomPaint(
            painter: _SegmentedBarPainter(
              emptyColor: emptyColor,
              segments: segments,
              progress: progress,
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedBarPainter extends CustomPainter {
  const _SegmentedBarPainter({
    required this.emptyColor,
    required this.segments,
    required this.progress,
  });

  final Color emptyColor;
  final List<({int weight, Color color})> segments;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    // Selalu gambar track latar terlebih dahulu agar progres 0→target terlihat jelas.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = emptyColor,
    );
    final nonZero = segments.where((s) => s.weight > 0).toList();
    final total = nonZero.fold<int>(0, (sum, s) => sum + s.weight);
    if (nonZero.isEmpty || total <= 0 || progress <= 0) {
      return;
    }
    const gap = 2.5;
    final totalGap = math.max(0, nonZero.length - 1) * gap;
    final avail = math.max(0.0, size.width - totalGap);
    var x = 0.0;
    for (var i = 0; i < nonZero.length; i++) {
      final seg = nonZero[i];
      final w = i == nonZero.length - 1
          ? math.min(
              math.max(0.0, size.width - x),
              avail * (seg.weight / total) * progress,
            )
          : avail * (seg.weight / total) * progress;
      canvas.drawRect(
        Rect.fromLTWH(x, 0, w, size.height),
        Paint()..color = seg.color,
      );
      x += w + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedBarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.emptyColor != emptyColor ||
      oldDelegate.segments.length != segments.length ||
      [
        for (var i = 0; i < segments.length; i++)
          oldDelegate.segments[i].weight != segments[i].weight ||
              oldDelegate.segments[i].color != segments[i].color,
      ].any((changed) => changed);
}
