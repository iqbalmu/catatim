import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/buckets.dart' show AmountPoint, TrendBucket;
import '../core/buckets.dart' as bkt;
import '../core/dates_id.dart';
import '../core/money.dart';
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

// Bagian-bagian kartu laporan dipecah ke part files (audit I-01) —
// satu library, nama privat tetap berlaku lintas file.
part 'laporan/metrics.dart';
part 'laporan/executive_summary.dart';
part 'laporan/trend_card.dart';
part 'laporan/category_structure.dart';
part 'laporan/top_expenses.dart';
part 'laporan/period_sheet.dart';

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
    this.showBack = false,
  });

  final LedgerRepository repository;
  final ProgressService? progress;
  final bool showBack;

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
                      uncategorizedColor: context.q.muted,
                    );

                    final isPushed = widget.showBack || Navigator.canPop(context);

                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        Spacing.m,
                        Spacing.m,
                        Spacing.m,
                        (isPushed ? Spacing.xl : 104) + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        // ── Top Bar: Title + Account Filter ────────────────
                        QuestTabEnter(
                          index: 0,
                          child:
                        Row(
                          children: [
                            if (isPushed) ...[
                              Padding(
                                padding: const EdgeInsets.only(right: Spacing.s),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: context.q.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: context.q.line),
                                    boxShadow: context.q.cardShadow,
                                  ),
                                  child: IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Kembali',
                                    icon: Icon(
                                      Icons.arrow_back_rounded,
                                      color: context.q.text,
                                      size: 20,
                                    ),
                                    onPressed: () => Navigator.maybePop(context),
                                  ),
                                ),
                              ),
                            ],
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
                                child: Semantics(
                                  button: true,
                                  label:
                                      'Filter akun, ${activeAccount?.name ?? 'semua akun'}',
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
                            boxShadow: context.q.cardShadow,
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
                                child: Semantics(
                                  button: true,
                                  label: 'Pilih periode laporan',
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
                                            color: context.q.primaryText,
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
