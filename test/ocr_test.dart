import 'package:flutter_test/flutter_test.dart';
import 'package:catatim/capture/ocr.dart';
import 'package:catatim/models.dart';

void main() {
  group('OcrService.parseReceiptText', () {
    test(
      'ekstraksi struk Indomaret standar (Total vs Tunai, Tanggal, & Kategori)',
      () {
        const sample = '''
PT INDOMARCO PRISMATAMA
INDOMARET RAYA 45
JL. SUDIRMAN NO. 12
TGL 25.10.26 14:30
ROTI TAWAR SARI       15.000
SUSU UHT COKLAT       12.500
AIR MINERAL 600ML      3.500
SUBTOTAL              31.000
TOTAL                 31.000
TUNAI                 50.000
KEMBALI               19.000
TERIMA KASIH
''';
        final data = OcrService.parseReceiptText(sample);
        expect(
          data.merchant,
          anyOf(contains('INDOMARCO'), contains('INDOMARET')),
        );
        // Nominal total 31.000, bukan uang tunai 50.000 atau kembalian 19.000
        expect(data.amount, 31000);
        expect(data.direction, Direction.outgoing);
        expect(data.occurredAt, DateTime(2026, 10, 25, 14, 30));
        expect(data.suggestedCategory, 'Belanja');
        expect(
          data.candidateAmounts,
          containsAll([31000, 15000, 12500, 3500, 50000, 19000]),
        );
      },
    );

    test('ekstraksi struk kafe format multi-line total & tebakan QRIS', () {
      const sample = '''
KOPI KENANGAN - GANDARIA
RECEIPT #12893
2 Kopi Kenangan Mantan   36.000
1 Toast Coklat           18.000
TOTAL AKHIR
Rp 54.000
QRIS BCA
LUNAS
''';
      final data = OcrService.parseReceiptText(sample);
      expect(data.merchant, 'KOPI KENANGAN - GANDARIA');
      expect(data.amount, 54000);
      expect(data.direction, Direction.outgoing);
      expect(data.suggestedCategory, 'Makanan');
      expect(data.suggestedPaymentMethod, anyOf('QRIS', 'blu by BCA'));
    });

    test(
      'ekstraksi struk SPBU Pertamina (Kategori Transportasi & Tanggal)',
      () {
        const sample = '''
SPBU PERTAMINA 34-12345
JL. GATOT SUBROTO
TANGGAL: 01/11/2026 08:15
PERTAMAX 92
TOTAL BAYAR: Rp 150.000
LUNAS
''';
        final data = OcrService.parseReceiptText(sample);
        expect(data.merchant, contains('PERTAMINA'));
        expect(data.amount, 150000);
        expect(data.suggestedCategory, 'Transportasi');
        expect(data.occurredAt, DateTime(2026, 11, 1, 8, 15));
      },
    );

    test('ekstraksi struk Apotek K-24 (Kategori Kesehatan)', () {
      const sample = '''
APOTEK K-24 SUDIRMAN
NOTA PENJUALAN
TGL 10-10-2026
PARACETAMOL 500MG     12.000
VITAMIN C             25.000
TOTAL                 37.000
''';
      final data = OcrService.parseReceiptText(sample);
      expect(data.merchant, contains('APOTEK'));
      expect(data.amount, 37000);
      expect(data.suggestedCategory, 'Kesehatan');
      expect(data.occurredAt, DateTime(2026, 10, 10));
    });

    test('ekstraksi bukti transfer masuk', () {
      const sample = '''
BUKTI TRANSAKSI
TRANSFER MASUK BERHASIL
PENGIRIM: AHMAD FAUZI
PENERIMA: SAYA
NOMINAL: Rp 250.000
REFF: 89347293847293
''';
      final data = OcrService.parseReceiptText(sample);
      expect(data.amount, 250000);
      expect(data.direction, Direction.incoming);
    });
  });
}
