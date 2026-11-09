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

/// 'Okt 2026'
String idMonthYear(DateTime dt) => '${idMonthsShort[dt.month - 1]} ${dt.year}';

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

/// Format waktu relatif pendek untuk status/heartbeat ('Baru saja', '5m lalu', '2j lalu', dsb.).
String idTimeAgo(DateTime dt, [DateTime? now]) {
  final current = now ?? DateTime.now();
  final diff = current.difference(dt);
  if (diff.isNegative || diff.inSeconds < 45) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
  if (diff.inHours < 24) return '${diff.inHours}j lalu';
  if (diff.inDays < 7) return '${diff.inDays}h lalu';
  return idDateTime(dt);
}
