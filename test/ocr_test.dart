import 'package:flutter_test/flutter_test.dart';
import 'package:bukuduit/capture/ocr.dart';
import 'package:bukuduit/models.dart';

void main() {
  group('OcrService.parseReceiptText', () {
    test('ekstraksi struk Indomaret standar', () {
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
      expect(data.amount, 31000);
      expect(data.direction, Direction.outgoing);
    });

    test('ekstraksi struk kafe format multi-line total', () {
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
