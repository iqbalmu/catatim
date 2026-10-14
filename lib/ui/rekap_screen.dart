import 'package:flutter/material.dart';

import '../core/dates_id.dart';
import '../core/rekap_filter.dart';
import '../game/progress.dart';
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
import 'transaction_sheet.dart';

/// Layar Rekap: pil periode (bulan/rentang) di atas segmen; segmen
/// Transaksi tampil default. State filter (RekapFilter) dimiliki di
/// sini dan mengalir ke tiap segmen.
class RekapScreen extends StatefulWidget {
  const RekapScreen({
    super.key,
    required this.repository,
    this.progress,
    this.headerActions = const [],
  });

  final LedgerRepository repository;

  /// Agar hero Beranda ikut segar setelah catat dari tab ini.
  final ProgressService? progress;

  /// Aksi header global dari shell (lonceng + ⋯) — sama di semua tab.
  final List<Widget> headerActions;

  @override
  State<RekapScreen> createState() => _RekapScreenState();
}

enum _RekapSegment { transaksi, donat, tren, kalender }

enum _RekapPeriod { month, custom }

class _RekapScreenState extends State<RekapScreen> {
  _RekapSegment _segment = _RekapSegment.transaksi;
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
      appBar: QuestHeader(
        title: 'Rekap',
        subtitle: _periodLabel,
        actions: widget.headerActions,
      ),
      // FAB milik tab ini (bukan shell). Padding bawah agar melayang di
      // atas navbar floating.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: 110 + Spacing.s,
        ),
        child: QuestFab(
          label: 'Catat transaksi',
          icon: Icons.add_rounded,
          onTap: () => TransactionSheet.show(
            context,
            widget.repository,
            progress: widget.progress,
          ),
        ),
      ),
      // Kolom non-scroll: konten segmen (RekapTransaksi) yang menggulir,
      // jangan sarangkan dua ListView tanpa shrinkWrap. Inset bawah
      // diberikan sekali saja oleh ListView segmen.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.m,
              Spacing.s,
              Spacing.m,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pil periode kompak — buka sheet kalender (pola Laporan).
                QuestPress(
                  onTap: _openPeriodSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: context.q.surface,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: context.q.shadow,
                          offset: const Offset(0, 6),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_outlined, color: context.q.honeyInk),
                        const SizedBox(width: Spacing.s),
                        Expanded(
                          child: Text(_periodLabel, style: context.qTitle(15)),
                        ),
                        Icon(Icons.expand_more_rounded, color: context.q.muted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.m),
                QuestSegmented<_RekapSegment>(
                  selected: _segment,
                  onChanged: (s) => setState(() {
                    _segment = s;
                    // Periode/akun/cari dipertahankan; kategori/tanggal
                    // dihapus.
                    _filter = _filter.onSegmentSwitch();
                  }),
                  options: const [
                    (
                      value: _RekapSegment.transaksi,
                      label: 'Transaksi',
                      icon: null,
                    ),
                    (value: _RekapSegment.donat, label: 'Donat', icon: null),
                    (value: _RekapSegment.tren, label: 'Tren', icon: null),
                    (
                      value: _RekapSegment.kalender,
                      label: 'Kalender',
                      icon: null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),
          Expanded(
            child: switch (_segment) {
              _RekapSegment.transaksi => RekapTransaksi(
                repository: widget.repository,
                filter: _filter,
                onFilterChanged: (f) => setState(() => _filter = f),
              ),
              _RekapSegment.donat => RekapDonat(
                repository: widget.repository,
                filter: _filter,
                // Deep-link kategori (alur B): filter hasil applyDonatTap
                // + pindah segmen ke Transaksi.
                onCategoryTap: (f) => setState(() {
                  _filter = f;
                  _segment = _RekapSegment.transaksi;
                }),
              ),
              _RekapSegment.tren => RekapTren(
                repository: widget.repository,
                filter: _filter,
              ),
              // Deep-link kalender: filter satu tanggal (applyKalenderTap
              // di shell, field lain dipertahankan) + pindah segmen.
              _RekapSegment.kalender => RekapKalender(
                repository: widget.repository,
                month: _filter.month ?? _filter.rangeStart ?? DateTime.now(),
                onDayTap: (day) => setState(() {
                  _filter = _filter.applyKalenderTap(day);
                  _segment = _RekapSegment.transaksi;
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
            Center(child: Text('Periode', style: context.qTitle(20))),
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
                radius: 16,
                child: QuestMonthPicker(
                  initialMonth: _month,
                  onChanged: (m) => setState(() => _month = m),
                ),
              ),
            ],
            if (_period == _RekapPeriod.custom) ...[
              const SizedBox(height: Spacing.m),
              QuestCard(
                radius: 16,
                child: QuestRangeCalendar(
                  initialRange: _custom,
                  onChanged: (r) => setState(() => _custom = r),
                ),
              ),
            ],
            const SizedBox(height: Spacing.l),
            QuestButton(
              label: 'Terapkan',
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
