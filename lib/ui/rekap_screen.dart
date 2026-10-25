import 'package:flutter/material.dart';

import '../core/dates_id.dart';
import '../core/money.dart';
import '../core/rekap_filter.dart';
import '../game/progress.dart';
import '../models.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'month_picker.dart';
import 'quest.dart';
import 'range_calendar.dart';
import 'rekap_donat.dart';
import 'rekap_kalender.dart';
import 'rekap_transaksi.dart';
import 'rekap_tren.dart';

/// Layar Rekap: pil periode (bulan/rentang) di atas segmen; segmen
/// Transaksi tampil default. State filter (RekapFilter) dimiliki di
/// sini dan mengalir ke tiap segmen.
class RekapScreen extends StatefulWidget {
  const RekapScreen({
    super.key,
    required this.repository,
    this.progress,
  });

  final LedgerRepository repository;

  /// Agar hero Beranda ikut segar setelah catat dari tab ini.
  final ProgressService? progress;

  @override
  State<RekapScreen> createState() => RekapScreenState();
}

enum RekapSegment { transaksi, donat, tren, kalender }

enum _RekapPeriod { month, custom }

class RekapScreenState extends State<RekapScreen> {
  /// Donat = segmen default (mockup v2.1): "uangku ke mana?" adalah
  /// pertanyaan pertama saat membuka Rekap.
  RekapSegment _segment = RekapSegment.donat;

  /// Deep-link dari shell (mis. "Lihat semua" Beranda): pastikan segmen
  /// yang dijanjikan labelnya benar-benar terbuka.
  void openSegment(RekapSegment segment) {
    if (_segment != segment) setState(() => _segment = segment);
  }

  late RekapFilter _filter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filter = RekapFilter(month: DateTime(now.year, now.month));
  }

  bool get _isCustom => _filter.rangeStart != null && _filter.rangeEnd != null;

  String get _periodLabel {
    if (_isCustom) {
      return '${idDayMonth(_filter.rangeStart!)} – '
          '${idDayMonth(_filter.rangeEnd!)}';
    }
    return _monthLabel(_filter.month ?? DateTime.now());
  }

  /// 'Bulan ini' bila bulan berjalan, selain itu 'Okt 2026'.
  String _monthLabel(DateTime m) {
    final now = DateTime.now();
    if (m.year == now.year && m.month == now.month) return 'Bulan ini';
    return idMonthYear(m);
  }
  void _shiftMonth(int delta) {
    final current = _filter.month ?? DateTime.now();
    setState(() {
      _filter = RekapFilter(
        month: DateTime(current.year, current.month + delta),
        accountId: _filter.accountId,
        query: _filter.query,
      );
    });
  }

  Future<void> _openPeriodSheet() async {
    final result =
        await showQuestSheet<(_RekapPeriod, DateTime?, DateTimeRange?)>(
          context,
          (context) => _PeriodSheet(
            initialPeriod: _isCustom ? _RekapPeriod.custom : _RekapPeriod.month,
            initialMonth: _filter.month,
            initialCustom: _isCustom
                ? DateTimeRange(
                    start: _filter.rangeStart!,
                    end: _filter.rangeEnd!,
                  )
                : null,
          ),
        );
    if (result != null && mounted) {
      final (period, month, custom) = result;
      setState(() {
        _filter = RekapFilter(
          month: month,
          rangeStart: period == _RekapPeriod.custom ? custom?.start : null,
          rangeEnd: period == _RekapPeriod.custom ? custom?.end : null,
          accountId: _filter.accountId,
          query: _filter.query,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final win = _filter.window;
    final now = DateTime.now();
    final winStart = win?.start ?? DateTime(now.year, now.month);
    final winEnd = win?.end ?? DateTime(now.year, now.month + 1);

    return Scaffold(
      backgroundColor: context.q.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.only(
            bottom: 96 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            // 1. Top Header Bar with Month Quick Selector
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.m, Spacing.m, Spacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laporan Finansial',
                          style: context.qTitle(20),
                        ),
                        Text(
                          'Ringkasan arus kas & performa bulanan',
                          style: context.qSmall(12),
                        ),
                      ],
                    ),
                  ),
                  // Month Quick Jump Pill
                  Container(
                    decoration: BoxDecoration(
                      color: context.q.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: context.q.line),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.chevron_left_rounded, size: 18),
                          onPressed: () => _shiftMonth(-1),
                        ),
                        InkWell(
                          onTap: _openPeriodSheet,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _periodLabel,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: context.q.text,
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
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.chevron_right_rounded, size: 18),
                          onPressed: () => _shiftMonth(1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.s),

            // 2. Hero Cashflow Statement Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.m),
              child: StreamBuilder<List<TxWithCategory>>(
                stream: widget.repository.watchBetweenWithCategory(
                  winStart,
                  winEnd,
                  accountId: _filter.accountId,
                ),
                builder: (context, snapshot) {
                  final rows = snapshot.data ?? const [];
                  int totalIn = 0;
                  int totalOut = 0;
                  for (final r in rows) {
                    if (r.tx.direction == Direction.incoming) {
                      totalIn += r.tx.amount;
                    } else if (r.tx.direction == Direction.outgoing && r.tx.kind != TxKind.transfer) {
                      totalOut += r.tx.amount;
                    }
                  }
                  final net = totalIn - totalOut;
                  final isSurplus = net >= 0;
                  final savingsPct = totalIn > 0 ? ((net / totalIn) * 100).round() : null;

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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'ARUS KAS BERSIH',
                                style: context.qEyebrow(10.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSurplus ? SeedColors.incomingTint : SeedColors.outgoingTint,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSurplus ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                    size: 13,
                                    color: isSurplus ? context.q.good : context.q.bad,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isSurplus ? 'Surplus' : 'Defisit',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isSurplus ? context.q.good : context.q.bad,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.xs),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${isSurplus ? '+' : '−'}${Money.format(net.abs())}',
                            style: context.qDisplay(26).copyWith(
                              color: isSurplus ? context.q.good : context.q.bad,
                            ),
                          ),
                        ),
                        const SizedBox(height: Spacing.s),
                        Divider(height: 1, thickness: 1, color: context.q.line),
                        const SizedBox(height: Spacing.s),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.arrow_downward_rounded, size: 14, color: context.q.good),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Pemasukan',
                                          style: context.qSmall(11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      Money.format(totalIn),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: context.q.good,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 32, color: context.q.line),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: Spacing.s),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.arrow_upward_rounded, size: 14, color: context.q.bad),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Pengeluaran',
                                            style: context.qSmall(11),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        Money.format(totalOut),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: context.q.bad,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (savingsPct != null) ...[
                          const SizedBox(height: Spacing.s),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: LinearProgressIndicator(
                              value: (totalOut / totalIn).clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: SeedColors.incomingTint,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isSurplus ? context.q.good : context.q.bad,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isSurplus
                                ? '$savingsPct% dari pemasukan berhasil dihemat'
                                : 'Pengeluaran melebihi pemasukan bulan ini',
                            style: context.qSmall(11),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: Spacing.m),

            // 3. Segment Switcher (Pills)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.m),
              child: QuestSegmented<RekapSegment>(
                selected: _segment == RekapSegment.tren ? RekapSegment.tren : RekapSegment.donat,
                onChanged: (s) => setState(() {
                  _segment = s;
                  _filter = _filter.onSegmentSwitch();
                }),
                options: const [
                  (value: RekapSegment.donat, label: 'Distribusi Kategori', icon: null),
                  (value: RekapSegment.tren, label: 'Tren Arus Kas', icon: null),
                ],
              ),
            ),
            const SizedBox(height: Spacing.s),

            // 4. View Content
            if (_segment == RekapSegment.donat)
              RekapDonat(
                repository: widget.repository,
                filter: _filter,
                onCategoryTap: (f) => setState(() {
                  _filter = f;
                  _segment = RekapSegment.transaksi;
                }),
              )
            else if (_segment == RekapSegment.tren)
              RekapTren(
                repository: widget.repository,
                filter: _filter,
              )
            else if (_segment == RekapSegment.transaksi)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.m),
                child: RekapTransaksi(
                  repository: widget.repository,
                  filter: _filter,
                  onFilterChanged: (f) => setState(() => _filter = f),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.m),
                child: RekapKalender(
                  repository: widget.repository,
                  month: _filter.month ?? _filter.rangeStart ?? DateTime.now(),
                  onDayTap: (day) => setState(() {
                    _filter = _filter.applyKalenderTap(day);
                    _segment = RekapSegment.transaksi;
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sheet pemilih periode: segmented bulan/rentang + picker inline.
class _PeriodSheet extends StatefulWidget {
  const _PeriodSheet({
    required this.initialPeriod,
    required this.initialMonth,
    required this.initialCustom,
  });

  final _RekapPeriod initialPeriod;
  final DateTime? initialMonth;
  final DateTimeRange? initialCustom;

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  late _RekapPeriod _period;
  DateTime? _month;
  DateTimeRange? _custom;

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod;
    _month = widget.initialMonth;
    _custom = widget.initialCustom;
  }

  void _select(_RekapPeriod v) {
    setState(() {
      _period = v;
      if (v == _RekapPeriod.month && _month == null) {
        final now = DateTime.now();
        _month = DateTime(now.year, now.month);
      }
    });
  }

  void _apply() {
    // Rentang tanpa pilihan tanggal = fallback bulan berjalan, jangan
    // biarkan _custom! crash di build.
    final period = (_period == _RekapPeriod.custom && _custom == null)
        ? _RekapPeriod.month
        : _period;
    Navigator.pop(context, (period, _month, _custom));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Text('Pilih periode', style: context.qTitle(20))),
            const SizedBox(height: Spacing.m),
            QuestSegmented<_RekapPeriod>(
              selected: _period,
              onChanged: _select,
              options: const [
                (value: _RekapPeriod.month, label: 'Bulan', icon: null),
                (value: _RekapPeriod.custom, label: 'Rentang', icon: null),
              ],
            ),
            if (_period == _RekapPeriod.month) ...[
              const SizedBox(height: Spacing.m),
              QuestCard(

                child: QuestMonthPicker(
                  initialMonth: _month,
                  onChanged: (m) => setState(() => _month = m),
                ),
              ),
            ],
            if (_period == _RekapPeriod.custom) ...[
              const SizedBox(height: Spacing.m),
              QuestCard(

                child: QuestRangeCalendar(
                  initialRange: _custom,
                  onChanged: (r) => setState(() => _custom = r),
                ),
              ),
            ],
            const SizedBox(height: Spacing.l),
            QuestButton(
              label: 'Pakai periode ini',
              icon: Icons.check_rounded,
              onPressed: _apply,
            ),
            const SizedBox(height: Spacing.m),
          ],
        ),
      ),
    );
  }
}
