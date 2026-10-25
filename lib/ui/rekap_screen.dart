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
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Laporan',
              style: context.qTitle(20),
            ),
            const SizedBox(height: 2),
            Text(
              'Distribusi kategori & tren arus kas',
              style: context.qSmall(),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Period Selector Bar
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
                  onTap: _openPeriodSheet,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_outlined, color: context.q.primary, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _periodLabel,
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

          // Executive Financial Summary Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.m, vertical: Spacing.xs),
            child: Builder(
              builder: (context) {
                final win = _filter.window;
                final now = DateTime.now();
                final winStart = win?.start ?? DateTime(now.year, now.month);
                final winEnd = win?.end ?? DateTime(now.year, now.month + 1);

                return StreamBuilder<List<TxWithCategory>>(
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

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.m, vertical: 14),
                      decoration: BoxDecoration(
                        color: context.q.surface,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: context.q.line),
                        boxShadow: AppShadows.card,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.arrow_downward_rounded, size: 14, color: context.q.good),
                                    const SizedBox(width: 4),
                                    Text('PEMASUKAN', style: context.qEyebrow(9.5)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  Money.format(totalIn),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: context.q.good,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 32, color: context.q.line),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.arrow_upward_rounded, size: 14, color: context.q.bad),
                                      const SizedBox(width: 4),
                                      Text('PENGELUARAN', style: context.qEyebrow(9.5)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    Money.format(totalOut),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: context.q.bad,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(width: 1, height: 32, color: context.q.line),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isSurplus ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                        size: 14,
                                        color: isSurplus ? context.q.good : context.q.bad,
                                      ),
                                      const SizedBox(width: 4),
                                      Text('ARUS BERSIH', style: context.qEyebrow(9.5)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${isSurplus ? '+' : '−'}${Money.format(net.abs())}',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      color: isSurplus ? context.q.good : context.q.bad,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Two visual options: Kategori & Tren
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.m, vertical: Spacing.xs),
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
          Expanded(
            child: switch (_segment) {
              RekapSegment.transaksi => RekapTransaksi(
                repository: widget.repository,
                filter: _filter,
                onFilterChanged: (f) => setState(() => _filter = f),
              ),
              RekapSegment.donat => RekapDonat(
                repository: widget.repository,
                filter: _filter,
                // Deep-link kategori (alur B): filter hasil applyDonatTap
                // + pindah segmen ke Transaksi.
                onCategoryTap: (f) => setState(() {
                  _filter = f;
                  _segment = RekapSegment.transaksi;
                }),
              ),
              RekapSegment.tren => RekapTren(
                repository: widget.repository,
                filter: _filter,
              ),
              // Deep-link kalender: filter satu tanggal (applyKalenderTap
              // di shell, field lain dipertahankan) + pindah segmen.
              RekapSegment.kalender => RekapKalender(
                repository: widget.repository,
                month: _filter.month ?? _filter.rangeStart ?? DateTime.now(),
                onDayTap: (day) => setState(() {
                  _filter = _filter.applyKalenderTap(day);
                  _segment = RekapSegment.transaksi;
                }),
              ),
            },
          ),
        ],
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
