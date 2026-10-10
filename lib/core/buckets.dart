import '../models.dart';
import 'dates_id.dart';

/// Satu titik nominal untuk agregasi chart (tanpa dependensi drift).
typedef AmountPoint = ({DateTime at, Direction direction, int amount});

/// Satu batang chart.
typedef TrendBucket = ({String label, int incoming, int outgoing});

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

int _sum(Iterable<AmountPoint> rows, bool Function(AmountPoint) test) =>
    rows.where(test).fold(0, (total, r) => total + r.amount);

String _monthLabel(DateTime m) =>
    '${idMonthsShort[m.month - 1]}${m.month == 1 ? " '${m.year % 100}" : ''}';

/// Bucket bulanan untuk tiap bulan yang bersinggungan [start, end]
/// (inklusif). Dibatasi 24 bulan.
List<TrendBucket> rangedMonthlyBuckets(
    List<AmountPoint> rows, DateTime start, DateTime end) {
  final months = <DateTime>[];
  var m = DateTime(start.year, start.month);
  final last = DateTime(end.year, end.month);
  var guard = 0;
  while (!m.isAfter(last) && guard++ < 24) {
    months.add(m);
    m = DateTime(m.year, m.month + 1);
  }
  bool inMonth(AmountPoint r, DateTime month) =>
      r.at.year == month.year && r.at.month == month.month;
  return [
    for (final month in months)
      (
        label: _monthLabel(month),
        incoming: _sum(
            rows,
            (r) =>
                r.direction == Direction.incoming && inMonth(r, month)),
        outgoing: _sum(
            rows,
            (r) =>
                r.direction == Direction.outgoing && inMonth(r, month)),
      ),
  ];
}

/// Bucket 7-harian mundur dari [end] hingga menutup [start].
List<TrendBucket> rangedWeeklyBuckets(
    List<AmountPoint> rows, DateTime start, DateTime end) {
  final e = _day(end);
  final s = _day(start);
  final span = e.difference(s).inDays;
  final count = (span / 7).ceil().clamp(1, 53);
  final out = <TrendBucket>[];
  for (var i = count - 1; i >= 0; i--) {
    final wEnd = e.subtract(Duration(days: i * 7));
    final wStart = wEnd.subtract(const Duration(days: 6));
    bool inWindow(AmountPoint r) {
      final d = _day(r.at);
      return !d.isBefore(wStart) && !d.isAfter(wEnd);
    }

    out.add((
      label: idDayMonth(wStart),
      incoming: _sum(
          rows, (r) => r.direction == Direction.incoming && inWindow(r)),
      outgoing: _sum(
          rows, (r) => r.direction == Direction.outgoing && inWindow(r)),
    ));
  }
  return out;
}

/// Pilih granularitas otomatis: rentang > 62 hari → bulanan, sisanya
/// mingguan. [start]/[end] inklusif.
List<TrendBucket> trendBuckets(
    List<AmountPoint> rows, DateTime start, DateTime end) {
  final span = _day(end).difference(_day(start)).inDays;
  if (span > 62) return rangedMonthlyBuckets(rows, start, end);
  return rangedWeeklyBuckets(rows, start, end);
}

/// 6 bucket bulanan berakhir di bulan [now].
List<TrendBucket> monthlyBuckets(List<AmountPoint> rows, DateTime now) =>
    rangedMonthlyBuckets(
      rows,
      DateTime(now.year, now.month - 5),
      DateTime(now.year, now.month + 1, 0),
    );

/// 4 bucket mingguan (masing-masing 7 hari) berakhir hari ini.
List<TrendBucket> weeklyBuckets(List<AmountPoint> rows, DateTime now) {
  final today = _day(now);
  return rangedWeeklyBuckets(
    rows,
    today.subtract(const Duration(days: 27)),
    today,
  );
}
