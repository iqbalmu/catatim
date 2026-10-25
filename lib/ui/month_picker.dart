import 'package:flutter/material.dart';

import '../core/dates_id.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Pemilih bulan gaya Quest: navigasi tahun + grid 12 bulan, langsung
/// tampil di sheet tanpa pindah layar.
class QuestMonthPicker extends StatefulWidget {
  const QuestMonthPicker({
    super.key,
    required this.initialMonth,
    required this.onChanged,
  });

  /// Bulan terpilih, dinormalisasi ke tanggal 1; null = belum ada pilihan.
  final DateTime? initialMonth;

  /// Terpanggil tiap kali bulan dipilih (dinormalisasi ke tanggal 1).
  final ValueChanged<DateTime> onChanged;

  @override
  State<QuestMonthPicker> createState() => _QuestMonthPickerState();
}

class _QuestMonthPickerState extends State<QuestMonthPicker> {
  late int _year = widget.initialMonth?.year ?? DateTime.now().year;

  void _shiftYear(int delta) {
    setState(() => _year += delta);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.initialMonth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: tahun + navigasi
        Row(
          children: [
            QuestIconButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Tahun sebelumnya',
              onPressed: () => _shiftYear(-1),
            ),
            Expanded(
              child: Text(
                '$_year',
                textAlign: TextAlign.center,
                style: context.qTitle(15),
              ),
            ),
            QuestIconButton(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Tahun berikutnya',
              onPressed: () => _shiftYear(1),
            ),
          ],
        ),
        const SizedBox(height: Spacing.s),
        // Grid bulan: 4 baris x 3 kolom
        for (var row = 0; row < 4; row++)
          Row(
            children: [
              for (var col = 0; col < 3; col++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final month = row * 3 + col + 1;
                      final isSameMonth = selected != null &&
                          selected.year == _year &&
                          selected.month == month;
                      return _MonthCell(
                        label: idMonthsShort[month - 1],
                        selected: isSameMonth,
                        onTap: () =>
                            widget.onChanged(DateTime(_year, month)),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestPress(
      onTap: onTap,
      child: Container(
        height: 40,
        margin: const EdgeInsets.all(Spacing.xxs),
        decoration: BoxDecoration(
          color: selected ? q.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.cell),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
            color: selected ? Colors.white : q.text,
          ),
        ),
      ),
    );
  }
}
