import 'dart:async';

import 'package:flutter/material.dart';

import '../core/dates_id.dart';
import '../core/money.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';
import 'transaction_tile.dart';

/// Segmen Kalender pada layar Rekap: grid 6×7 Senin-awal untuk [month],
/// sel berisi tanggal + nominal keluar ringkas, heat intensitas madu
/// berdasar kuantil nominal dalam bulan (tanpa engine — keputusan plan).
/// Tap hari → panel rincian hari di bawah + tombol "Lihat di Transaksi"
/// ([onDayTap]; shell yang menerapkan filter + pindah segmen).
class RekapKalender extends StatefulWidget {
  const RekapKalender({
    super.key,
    required this.repository,
    required this.month,
    required this.onDayTap,
  });

  final LedgerRepository repository;
  final DateTime month;
  final ValueChanged<DateTime> onDayTap;

  @override
  State<RekapKalender> createState() => _RekapKalenderState();
}

class _RekapKalenderState extends State<RekapKalender> {
  late DateTime _month = DateTime(widget.month.year, widget.month.month);
  DateTime? _selected;

  @override
  void didUpdateWidget(RekapKalender old) {
    super.didUpdateWidget(old);
    // Ikuti periode shell bila bulannya berganti (pil periode).
    if (widget.month.year != old.month.year ||
        widget.month.month != old.month.month) {
      _month = DateTime(widget.month.year, widget.month.month);
      _selected = null;
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(_month.year, _month.month);

    return StreamBuilder<Map<DateTime, int>>(
      stream: _effectiveOutByDay(monthStart),
      builder: (context, snapshot) {
        final sums = snapshot.data ?? const <DateTime, int>{};
        return ListView(
          padding: EdgeInsets.fromLTRB(
            Spacing.m,
            Spacing.s,
            Spacing.m,
            Spacing.m + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            QuestCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      QuestIconButton(
                        icon: Icons.chevron_left_rounded,
                        tooltip: 'Bulan sebelumnya',
                        onPressed: () => _shiftMonth(-1),
                      ),
                      Expanded(
                        child: Text(
                          idMonthYear(_month),
                          textAlign: TextAlign.center,
                          style: context.qTitle(15),
                        ),
                      ),
                      QuestIconButton(
                        icon: Icons.chevron_right_rounded,
                        tooltip: 'Bulan berikutnya',
                        onPressed: () => _shiftMonth(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.s),
                  _CalendarGrid(
                    month: _month,
                    sums: sums,
                    selected: _selected,
                    onDayTap: (day) => setState(() => _selected = day),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.m),
            if (_selected != null) ...[
              _DayDetail(
                repository: widget.repository,
                day: _selected!,
                // Total keluar EFEKTIF hari itu (ruling 5) — bukan jumlah
                // seluruh baris (transfer biasa tak masuk).
                effectiveOut: sums[_selected!] ?? 0,
                onClear: () => setState(() => _selected = null),
                onSeeInTransactions: () => widget.onDayTap(_selected!),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Keluaran per hari = belanja murni (transfer biasa tak terlihat).
  /// Reaktivitas memakai watchOutSumByDaySince sebagai pemicu (query
  /// tunggal tak ber-stream).
  Stream<Map<DateTime, int>> _effectiveOutByDay(DateTime since) {
    return widget.repository
        .watchOutSumByDaySince(since)
        .asyncMap((_) => widget.repository.outSpendByDaySince(since));
  }
}

/// Grid 6×7 Senin-awal (pola QuestRangeCalendar): sel di luar bulan
/// kosong; sel berisi tanggal + nominal ringkas; hari ini berbingkai.
class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.sums,
    required this.selected,
    required this.onDayTap,
  });

  final DateTime month;
  final Map<DateTime, int> sums;
  final DateTime? selected;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final first = DateTime(month.year, month.month);
    final weekdayOffset = first.weekday - 1; // Senin = kolom pertama
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Heat: kuantil nominal dalam bulan → alpha madu. Hari tanpa
    // keluaran tanpa heat; terkecil mulai 0,10, terbesar 0,45.
    final values = <int>[
      for (var d = 1; d <= daysInMonth; d++)
        if ((sums[DateTime(month.year, month.month, d)] ?? 0) > 0)
          sums[DateTime(month.year, month.month, d)]!,
    ]..sort();
    double alphaFor(int sum) {
      if (sum <= 0 || values.isEmpty) return 0;
      final rank = values.indexWhere((v) => v >= sum);
      final t = values.length == 1 ? 1 : rank / (values.length - 1);
      return 0.10 + 0.35 * t;
    }

    return Column(
      children: [
        Row(
          children: [
            for (final d in const ['S', 'S', 'R', 'K', 'J', 'S', 'M'])
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: context.qSmall(10)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        for (var row = 0; row < 6; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final index = row * 7 + col - weekdayOffset;
                      if (index < 0 || index >= daysInMonth) {
                        return const SizedBox(height: 56);
                      }
                      final day = DateTime(month.year, month.month, index + 1);
                      final sum = sums[day] ?? 0;
                      final isSelected =
                          selected != null && _sameDay(day, selected!);
                      return _KalenderCell(
                        day: day,
                        label: sum > 0 ? _shortMoney(sum) : null,
                        heat: q.honey.withValues(alpha: alphaFor(sum)),
                        isToday: _sameDay(day, today),
                        isSelected: isSelected,
                        onTap: () => onDayTap(day),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Satu sel kalender: tanggal di atas, nominal ringkas di bawah.
class _KalenderCell extends StatelessWidget {
  const _KalenderCell({
    required this.day,
    required this.label,
    required this.heat,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final String? label;
  final Color heat;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestPress(
      onTap: onTap,
      child: Container(
        height: 56,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isSelected ? q.honey : heat,
          borderRadius: BorderRadius.circular(AppRadius.cell),
          border: Border.all(
            color: isSelected || isToday ? q.text : q.line,
            width: isToday || isSelected ? 1.5 : 0,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: Spacing.xxs, vertical: Spacing.xs),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isToday || isSelected ? FontWeight.w800 : FontWeight.w400,
                color: isSelected ? q.honeyInk : q.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (label != null)
              Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.qSmall(9).copyWith(
                      color: isSelected ? q.honeyInk : q.muted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Panel rincian satu hari: total keluar + daftar transaksi hari itu,
/// plus tombol "Lihat di Transaksi".
class _DayDetail extends StatelessWidget {
  const _DayDetail({
    required this.repository,
    required this.day,
    required this.effectiveOut,
    required this.onClear,
    required this.onSeeInTransactions,
  });

  final LedgerRepository repository;
  final DateTime day;
  final int effectiveOut;
  final VoidCallback onClear;
  final VoidCallback onSeeInTransactions;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return StreamBuilder<List<TxWithCategory>>(
      stream: repository.watchBetweenWithCategory(
        day,
        DateTime(day.year, day.month, day.day + 1),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const QuestSkeleton(rows: 2, height: 56);
        }
        final rows = snapshot.data ?? const <TxWithCategory>[];
        return QuestCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(idFullDate(day), style: context.qTitle(15)),
                    const SizedBox(height: Spacing.xxs),
                        Text(
                          rows.isEmpty
                              ? 'Tidak ada transaksi'
                              : 'Keluar ${Money.format(effectiveOut)}',
                          style: context.qSmall(11).copyWith(color: q.muted),
                        ),
                      ],
                    ),
                  ),
                  QuestIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Tutup rincian',
                    onPressed: onClear,
                  ),
                ],
              ),
              if (rows.isNotEmpty) ...[
                const SizedBox(height: Spacing.s),
                for (final r in rows)
                  TransactionTile(item: r, repository: repository),
              ],
              const SizedBox(height: Spacing.m),
              QuestButton(
                label: 'Lihat di Transaksi',
                onPressed: onSeeInTransactions,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Rupiah ringkas untuk sel kalender (pola `_shortMoney` home_cards):
/// -Rp78.000 → '-78rb', Rp11.002.000 → '11,0jt'.
String _shortMoney(int v) {
  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  if (a >= 1000000) {
    final jt = a / 1000000;
    final s = jt >= 10
        ? jt.round().toString()
        : jt.toStringAsFixed(1).replaceFirst('.', ',');
    return '$sign${s}jt';
  }
  if (a >= 1000) return '$sign${(a / 1000).round()}rb';
  return Money.format(v);
}
