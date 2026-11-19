import '../models.dart';

/// Satu baris transaksi untuk ekspor — sudah di-join nama akun/kategori,
/// bebas dari drift supaya builder CSV murni dan mudah dites.
typedef ExportRow = ({
  DateTime occurredAt,
  Direction direction,
  TxKind kind,
  int amount,
  String? account,
  String? category,
  String? counterparty,
});

const String _csvBom = '\uFEFF';

const String _csvHeader = 'Tanggal;Arah;Jenis;Nominal;Akun;Kategori;Lawan';

/// Bangun isi file CSV dari seluruh transaksi.
///
/// Delimiter `;` dan BOM UTF-8: Excel locale Indonesia memakai `;`
/// sebagai pemisah daftar dan butuh BOM agar file UTF-8 tidak jadi
/// kacau saat dibuka langsung. Nominal ditulis sebagai bilangan polos
/// (tanpa pemisah ribuan) agar kolomnya tetap numerik di spreadsheet.
String buildTransactionCsv(List<ExportRow> rows) {
  final buffer = StringBuffer(_csvBom)..writeln(_csvHeader);
  for (final r in rows) {
    buffer.writeln(
      [
        _cell(_formatTanggal(r.occurredAt)),
        _cell(r.direction.label),
        _cell(r.kind.label),
        _cell('${r.amount}'),
        _cell(r.account),
        _cell(r.category),
        _cell(r.counterparty),
      ].join(';'),
    );
  }
  return buffer.toString();
}

/// dd/MM/yyyy HH:mm waktu lokal — konsisten dengan tampilan app.
String _formatTanggal(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year} '
      '${two(l.hour)}:${two(l.minute)}';
}

/// Escape sel CSV: bungkus kutip bila memuat delimiter, kutip, atau
/// baris baru; kutip di dalam sel digandakan (aturan RFC 4180).
/// Null (kolom kosong) menjadi string kosong — jangan dibiarkan jadi
/// teks "null" oleh join.
String _cell(String? value) {
  if (value == null || value.isEmpty) return '';
  final needsQuote =
      value.contains(';') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r');
  if (!needsQuote) return value;
  return '"${value.replaceAll('"', '""')}"';
}
