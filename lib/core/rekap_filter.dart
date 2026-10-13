/// Filter bersama untuk layar Rekap (ADR-003: core murni, hanya DateTime).
class RekapFilter {
  final DateTime? month;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final int? accountId;
  final String? query;
  final int? categoryId;
  final DateTime? day;

  const RekapFilter({
    this.month,
    this.rangeStart,
    this.rangeEnd,
    this.accountId,
    this.query,
    this.categoryId,
    this.day,
  });

  /// Tap slice donat: filter kategori dalam rentang bulan; tanggal hari dilepas.
  RekapFilter applyDonatTap({
    required int categoryId,
    required DateTime monthStart,
    required DateTime monthEnd,
  }) {
    return RekapFilter(
      month: monthStart,
      rangeStart: monthStart,
      rangeEnd: monthEnd,
      accountId: accountId,
      query: query,
      categoryId: categoryId,
    );
  }

  /// Tap kalender: filter satu tanggal; field lain dipertahankan.
  RekapFilter applyKalenderTap(DateTime day) {
    return RekapFilter(
      month: month,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      accountId: accountId,
      query: query,
      categoryId: categoryId,
      day: day,
    );
  }

  /// Pindah segmen (manual): periode/akun/cari dipertahankan,
  /// kategori/tanggal dihapus.
  RekapFilter onSegmentSwitch() {
    return RekapFilter(
      month: month,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      accountId: accountId,
      query: query,
    );
  }

  /// Hapus chip: kategori/tanggal saja; sisanya dipertahankan.
  RekapFilter clearChip() {
    return RekapFilter(
      month: month,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      accountId: accountId,
      query: query,
    );
  }
}
