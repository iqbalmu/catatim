import 'package:bukuduit/core/rekap_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final monthStart = DateTime(2026, 10, 1);
  final monthEnd = DateTime(2026, 10, 31, 23, 59, 59, 999);

  test('default kosong', () {
    const f = RekapFilter();
    expect(f.month, isNull);
    expect(f.rangeStart, isNull);
    expect(f.rangeEnd, isNull);
    expect(f.accountId, isNull);
    expect(f.query, isNull);
    expect(f.categoryId, isNull);
    expect(f.day, isNull);
  });

  test('applyDonatTap set kategori + bulan, hapus tanggal', () {
    const f = RekapFilter(day: null);
    final g = f.applyDonatTap(
      categoryId: 7,
      monthStart: monthStart,
      monthEnd: monthEnd,
    );
    expect(g.categoryId, 7);
    expect(g.month, monthStart);
    expect(g.rangeStart, monthStart);
    expect(g.rangeEnd, monthEnd);
    expect(g.day, isNull);
  });

  test('applyKalenderTap set tanggal, pertahankan kategori/akun/cari', () {
    final f = const RekapFilter(accountId: 3, query: 'kopi').applyDonatTap(
      categoryId: 7,
      monthStart: monthStart,
      monthEnd: monthEnd,
    );
    final g = f.applyKalenderTap(DateTime(2026, 10, 13));
    expect(g.day, DateTime(2026, 10, 13));
    expect(g.categoryId, 7);
    expect(g.accountId, 3);
    expect(g.query, 'kopi');
  });

  test('onSegmentSwitch hapus kategori/tanggal, simpan periode/akun/cari', () {
    final f = const RekapFilter(accountId: 3, query: 'kopi').applyDonatTap(
      categoryId: 7,
      monthStart: monthStart,
      monthEnd: monthEnd,
    ).applyKalenderTap(DateTime(2026, 10, 13));
    final g = f.onSegmentSwitch();
    expect(g.categoryId, isNull);
    expect(g.day, isNull);
    expect(g.month, monthStart);
    expect(g.rangeStart, monthStart);
    expect(g.rangeEnd, monthEnd);
    expect(g.accountId, 3);
    expect(g.query, 'kopi');
  });

  test('clearChip hapus kategori/tanggal saja, simpan sisanya', () {
    final f = const RekapFilter(accountId: 3, query: 'kopi').applyDonatTap(
      categoryId: 7,
      monthStart: monthStart,
      monthEnd: monthEnd,
    ).applyKalenderTap(DateTime(2026, 10, 13));
    final g = f.clearChip();
    expect(g.categoryId, isNull);
    expect(g.day, isNull);
    expect(g.month, monthStart);
    expect(g.rangeStart, monthStart);
    expect(g.rangeEnd, monthEnd);
    expect(g.accountId, 3);
    expect(g.query, 'kopi');
  });
}
