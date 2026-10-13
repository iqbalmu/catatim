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

  /// Jendela [start, end) dari periode filter: rentang (akhir +1 hari,
  /// eksklusif) bila ada, else bulan. Null bila keduanya kosong.
  ({DateTime start, DateTime end})? get window {
    final s = rangeStart;
    final e = rangeEnd;
    if (s != null && e != null) {
      return (
        start: DateTime(s.year, s.month, s.day),
        end: DateTime(e.year, e.month, e.day + 1),
      );
    }
    final m = month;
    if (m != null) {
      return (
        start: DateTime(m.year, m.month),
        end: DateTime(m.year, m.month + 1),
      );
    }
    return null;
  }

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
