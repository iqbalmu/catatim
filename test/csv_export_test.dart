import 'package:flutter_test/flutter_test.dart';
import 'package:catatim/core/csv_export.dart';
import 'package:catatim/models.dart';

ExportRow row({
  DateTime? at,
  Direction direction = Direction.outgoing,
  TxKind kind = TxKind.payment,
  int amount = 15000,
  String? account = 'Tunai',
  String? category = 'Makanan',
  String? counterparty = 'Warung Bu Sari',
}) => (
  occurredAt: at ?? DateTime(2026, 11, 15, 8, 30),
  direction: direction,
  kind: kind,
  amount: amount,
  account: account,
  category: category,
  counterparty: counterparty,
);

void main() {
  test('header + baris utuh tanpa karakter khusus', () {
    final csv = buildTransactionCsv([row()]);
    expect(csv.startsWith('\uFEFF'), isTrue, reason: 'BOM UTF-8 untuk Excel');
    final lines = csv.split('\n');
    expect(
      lines.first.trim(),
      'Tanggal;Arah;Jenis;Nominal;Akun;Kategori;Lawan',
    );
    expect(
      lines[1],
      '15/11/2026 08:30;Keluar;Pembayaran;15000;Tunai;Makanan;Warung Bu Sari',
    );
  });

  test('sel dengan delimiter dan kutip dibungkus dan digandakan', () {
    final csv = buildTransactionCsv([
      row(counterparty: 'Toko A;B & C "Premium"'),
    ]);
    expect(csv, contains('"Toko A;B & C ""Premium"""'));
  });

  test('sel null menjadi kolom kosong', () {
    final csv = buildTransactionCsv([
      row(account: null, category: null, counterparty: null),
    ]);
    expect(csv, contains('15/11/2026 08:30;Keluar;Pembayaran;15000;;;'));
  });

  test('beberapa baris urut sesuai input pemanggil', () {
    final csv = buildTransactionCsv([
      row(at: DateTime(2026, 11, 1, 9)),
      row(at: DateTime(2026, 11, 2, 10), direction: Direction.incoming),
    ]);
    final dataLines = csv
        .split('\n')
        .skip(1)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    expect(dataLines, hasLength(2));
    expect(dataLines[0], startsWith('01/11/2026'));
    expect(dataLines[1], startsWith('02/11/2026'));
    expect(dataLines[1], contains(';Masuk;'));
  });

  test('baris baru di dalam sel tetap satu baris CSV terkutip', () {
    final csv = buildTransactionCsv([row(counterparty: 'Warung\nBu Sari')]);
    // Newline di dalam kutip valid (RFC 4180) — sel utuh terkutip.
    expect(csv, contains('"Warung\nBu Sari"'));
    // Baris data tetap persis satu: satu baris diawali tanggal.
    final dataLines = csv
        .split('\n')
        .where((l) => l.startsWith('15/11/2026'))
        .toList();
    expect(dataLines, hasLength(1));
    expect(dataLines.single, startsWith('15/11/2026 08:30;Keluar'));
  });
}
