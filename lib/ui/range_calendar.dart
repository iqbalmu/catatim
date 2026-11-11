import 'package:flutter/material.dart';

import '../core/dates_id.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Kalender pilih rentang tanggal, gaya Quest — langsung tampil di sheet,
/// tanpa pindah layar. [QuestRangeCalendar.onChanged] mengirim rentang
/// inklusif (sama dengan kontrak `showDateRangePicker`).
class QuestRangeCalendar extends StatefulWidget {
  const QuestRangeCalendar({
    super.key,
    required this.initialRange,
    required this.onChanged,
  });

  final DateTimeRange? initialRange;

  /// Terpanggil tiap kali rentang berubah (termasuk sebelum "Terapkan").
  final ValueChanged<DateTimeRange> onChanged;

  @override
  State<QuestRangeCalendar> createState() => _QuestRangeCalendarState();
}

class _QuestRangeCalendarState extends State<QuestRangeCalendar> {
  late DateTime _month = widget.initialRange != null
      ? DateTime(
          widget.initialRange!.start.year,
          widget.initialRange!.start.month,
        )
      : DateTime(
          DateTime.now().year,
          DateTime.now().month,
        );
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRange;
    if (r != null) {
      _start = DateTime(r.start.year, r.start.month, r.start.day);
      _end = DateTime(r.end.year, r.end.month, r.end.day);
    }
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _tapDay(DateTime day) {
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        _start = day;
        _end = null;
      } else if (day.isBefore(_start!)) {
        _end = _start;
        _start = day;
      } else {
        _end = day;
      }
    });
    if (_start != null && _end != null) {
      widget.onChanged(DateTimeRange(start: _start!, end: _end!));
    }
  }

  void _applyPreset(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: days - 1));
    setState(() {
      _start = start;
      _end = today;
      _month = DateTime(start.year, start.month);
    });
    widget.onChanged(DateTimeRange(start: start, end: today));
  }

  void _thisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1, 0);
    setState(() {
      _start = start;
      _end = end;
      _month = start;
    });
    widget.onChanged(DateTimeRange(start: start, end: end));
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month);
    final weekdayOffset = first.weekday - 1; // Senin = kolom pertama
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: bulan + navigasi
        Row(
          children: [
            QuestIconButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Bulan sebelumnya',
              onPressed: () => _shiftMonth(-1),
            ),
            Expanded(
              child: Text(
                '${idMonthsShort[_month.month - 1]} ${_month.year}',
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
        // Nama hari
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
        // Grid tanggal
        ...[
          for (var row = 0; row < 6; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final index = row * 7 + col - weekdayOffset;
                        if (index < 0 || index >= daysInMonth) {
                          return const SizedBox(height: 44);
                        }
                        final day = DateTime(
                          _month.year,
                          _month.month,
                          index + 1,
                        );
                        return _DayCell(
                          day: day,
                          start: _start,
                          end: _end,
                          onTap: () => _tapDay(day),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
        const SizedBox(height: Spacing.s),
        // Preset cepat
        Wrap(
          spacing: Spacing.s,
          children: [
            QuestChip(
              label: '7 hari',
              selected: false,
              onTap: () => _applyPreset(7),
            ),
            QuestChip(
              label: '30 hari',
              selected: false,
              onTap: () => _applyPreset(30),
            ),
            QuestChip(
              label: 'Bulan ini',
              selected: false,
              onTap: _thisMonth,
            ),
          ],
        ),
        const SizedBox(height: Spacing.s),
        // Ringkasan rentang terpilih
        if (_start != null && _end != null)
          Text(
            '${idDayMonth(_start!)} – ${idDayMonth(_end!)}',
            style: context.qSmall(),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.start,
    required this.end,
    required this.onTap,
  });

  final DateTime day;
  final DateTime? start;
  final DateTime? end;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final isStart = start != null && _sameDay(day, start!);
    final isEnd = end != null && _sameDay(day, end!);
    final inRange =
        start != null && end != null && day.isAfter(start!) && day.isBefore(end!);
    final isEdge = isStart || isEnd;

    final Color bg;
    final Color fg;
    if (isEdge) {
      bg = q.primarySolid;
      fg = q.onPrimary;
    } else if (inRange) {
      bg = q.primaryLight;
      fg = q.primaryText;
    } else {
      bg = Colors.transparent;
      fg = q.text;
    }

    final dateLabel =
        '${day.day}/${day.month}/${day.year}';
    return Semantics(
      button: true,
      selected: isEdge,
      label: isEdge
          ? dateLabel
          : inRange
              ? '$dateLabel, dalam rentang'
              : dateLabel,
      child: QuestPress(
        onTap: onTap,
        child: Container(
          height: 44,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: bg,
            shape: isEdge ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isEdge ? null : BorderRadius.circular(AppRadius.cell),
            border: Border.all(color: q.line, width: isEdge ? 2 : 0),
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isEdge ? FontWeight.w800 : FontWeight.w400,
              color: fg,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
