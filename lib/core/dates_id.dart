/// Konstanta + format tanggal Bahasa Indonesia, satu sumber kebenaran.
///
/// Sebelumnya `_daysShort`/`_monthsShort` diduplikasi di 4 file UI.
const List<String> idDaysShort = [
  'Sen',
  'Sel',
  'Rab',
  'Kam',
  'Jum',
  'Sab',
  'Min',
];

const List<String> idMonthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// 'Sen, 11 Okt 2026'
String idFullDate(DateTime dt) =>
    '${idDaysShort[dt.weekday - 1]}, ${dt.day} '
    '${idMonthsShort[dt.month - 1]} ${dt.year}';

/// 'Sen, 11 Okt'
String idShortDate(DateTime dt) =>
    '${idDaysShort[dt.weekday - 1]}, ${dt.day} '
    '${idMonthsShort[dt.month - 1]}';

/// '11 Okt'
String idDayMonth(DateTime dt) => '${dt.day} ${idMonthsShort[dt.month - 1]}';

/// '11/10 14:05'
String idDateTime(DateTime dt) =>
    '${dt.day}/${dt.month} '
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}';

/// Label hari relatif: 'Hari ini', 'Kemarin', atau 'Sen, 11 Okt'.
String idRelativeDay(DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return 'Hari ini';
  if (day == today.subtract(const Duration(days: 1))) return 'Kemarin';
  return idShortDate(day);
}
