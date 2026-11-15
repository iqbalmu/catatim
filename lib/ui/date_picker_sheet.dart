import 'package:flutter/material.dart';

import '../core/dates_id.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Pemilih tanggal bergaya drawer Quest — menggantikan popup
/// `showDatePicker` agar konsisten dengan konvensi drawer aplikasi.
/// Mengembalikan tanggal yang dipilih (tanpa jam), null bila ditutup.
Future<DateTime?> showQuestDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showQuestSheet<DateTime>(
    context,
    (ctx) => QuestDatePicker(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

/// Pemilih jam & menit bergaya drawer Quest — pengganti popup
/// `showTimePicker`. Mengembalikan [TimeOfDay] terpilih, null bila ditutup.
Future<TimeOfDay?> showQuestTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  return showQuestSheet<TimeOfDay>(
    context,
    (ctx) => QuestTimePicker(initialTime: initialTime),
  );
}

class QuestDatePicker extends StatefulWidget {
  const QuestDatePicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<QuestDatePicker> createState() => _QuestDatePickerState();
}

class _QuestDatePickerState extends State<QuestDatePicker> {
  late DateTime _month = _clampMonth(
    DateTime(widget.initialDate.year, widget.initialDate.month),
  );
  late final DateTime _selected = _dateOnly(widget.initialDate);

  DateTime get _minMonth => _dateOnly(widget.firstDate);
  DateTime get _maxMonth => _dateOnly(widget.lastDate);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _clampMonth(DateTime month) {
    if (month.isBefore(
      DateTime(widget.firstDate.year, widget.firstDate.month),
    )) {
      return DateTime(widget.firstDate.year, widget.firstDate.month);
    }
    if (month.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month))) {
      return DateTime(widget.lastDate.year, widget.lastDate.month);
    }
    return month;
  }

  void _shiftMonth(int delta) {
    setState(
      () => _month = _clampMonth(DateTime(_month.year, _month.month + delta)),
    );
  }

  bool _inBounds(DateTime day) =>
      !day.isBefore(_dateOnly(widget.firstDate)) &&
      !day.isAfter(_dateOnly(widget.lastDate));

  void _pick(DateTime day) {
    if (!_inBounds(day)) return;
    Navigator.pop(context, day);
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month);
    final weekdayOffset = first.weekday - 1; // Senin = kolom pertama
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final today = _dateOnly(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, Spacing.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pilih Tanggal', style: context.qTitle()),
          const SizedBox(height: Spacing.s),
          Row(
            children: [
              QuestIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Bulan sebelumnya',
                onPressed: _month.isAfter(_minMonth)
                    ? () => _shiftMonth(-1)
                    : null,
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
                onPressed: _month.isBefore(_maxMonth)
                    ? () => _shiftMonth(1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: Spacing.s),
          Row(
            children: [
              for (final d in const ['S', 'S', 'R', 'K', 'J', 'S', 'M'])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: context
                          .qSmall(10)
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
                          return const SizedBox(height: 44);
                        }
                        final day = DateTime(
                          _month.year,
                          _month.month,
                          index + 1,
                        );
                        return _DateCell(
                          day: day,
                          selected: _sameDay(day, _selected),
                          isToday: _sameDay(day, today),
                          enabled: _inBounds(day),
                          onTap: () => _pick(day),
                        );
                      },
                    ),
                  ),
              ],
            ),
          const SizedBox(height: Spacing.s),
          Row(
            children: [
              if (_inBounds(today))
                QuestChip(
                  label: 'Hari ini',
                  selected: _sameDay(today, _selected),
                  onTap: () => _pick(today),
                ),
              const Spacer(),
              Text(idFullDate(_selected), style: context.qSmall()),
            ],
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.enabled,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final dateLabel = '${day.day}/${day.month}/${day.year}';
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$dateLabel, terpilih' : dateLabel,
      child: QuestPress(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 44,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: selected ? q.primarySolid : Colors.transparent,
            shape: selected || isToday ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: selected || isToday
                ? null
                : BorderRadius.circular(AppRadius.cell),
            border: Border.all(
              color: selected ? q.primarySolid : q.line,
              width: selected
                  ? 2
                  : isToday
                  ? 1.5
                  : 0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
              color: selected
                  ? q.onPrimary
                  : enabled
                  ? q.text
                  : q.muted.withValues(alpha: 0.45),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class QuestTimePicker extends StatefulWidget {
  const QuestTimePicker({super.key, required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<QuestTimePicker> createState() => _QuestTimePickerState();
}

class _QuestTimePickerState extends State<QuestTimePicker> {
  late int _hour = widget.initialTime.hour;
  late int _minute = widget.initialTime.minute;

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, Spacing.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pilih Waktu', style: context.qTitle()),
          const SizedBox(height: Spacing.xs),
          Center(
            child: Text(
              '${_two(_hour)}.${_two(_minute)}',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: q.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: Spacing.s),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const QuestFieldLabel('Jam'),
                  const SizedBox(height: Spacing.xs),
                  Wrap(
                    spacing: Spacing.s,
                    runSpacing: Spacing.s,
                    children: [
                      for (var h = 0; h < 24; h++)
                        QuestChip(
                          label: _two(h),
                          selected: _hour == h,
                          onTap: () => setState(() => _hour = h),
                        ),
                    ],
                  ),
                  const SizedBox(height: Spacing.m),
                  const QuestFieldLabel('Menit'),
                  const SizedBox(height: Spacing.xs),
                  Wrap(
                    spacing: Spacing.s,
                    runSpacing: Spacing.s,
                    children: [
                      for (var m = 0; m < 60; m++)
                        QuestChip(
                          label: _two(m),
                          selected: _minute == m,
                          onTap: () => setState(() => _minute = m),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.m),
          QuestButton(
            label: 'Terapkan',
            icon: Icons.check_rounded,
            onPressed: () =>
                Navigator.pop(context, TimeOfDay(hour: _hour, minute: _minute)),
          ),
        ],
      ),
    );
  }
}
