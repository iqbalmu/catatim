import 'package:flutter_test/flutter_test.dart';
import 'package:bukuduit/core/money.dart';

void main() {
  group('Money.parseGroup', () {
    test('ribuan bertitik', () {
      expect(Money.parseGroup('1.234.567'), 1234567);
      expect(Money.parseGroup('150.000'), 150000);
    });

    test('polos', () {
      expect(Money.parseGroup('50000'), 50000);
    });

    test('koma ribuan gaya EN', () {
      expect(Money.parseGroup('1,234,567'), 1234567);
    });

    test('desimal koma dipotong ke rupiah penuh', () {
      expect(Money.parseGroup('50.000,50'), 50000);
    });

    test('ada sisa teks non-digit', () {
      expect(Money.parseGroup('Rp 25.000,-'), 25000);
    });

    test('kosong melempar FormatException', () {
      expect(() => Money.parseGroup('..,'), throwsFormatException);
    });
  });

  group('Money.format', () {
    test('positif', () {
      expect(Money.format(1234567), 'Rp1.234.567');
      expect(Money.format(50000), 'Rp50.000');
      expect(Money.format(500), 'Rp500');
    });

    test('negatif memakai minus tipografis U+2212', () {
      expect(Money.format(-5000), '−Rp5.000');
    });

    test('nol', () {
      expect(Money.format(0), 'Rp0');
    });
  });

  group('Money.formatAbs', () {
    test('tanpa tanda arah', () {
      expect(Money.formatAbs(840000), 'Rp840.000');
      expect(Money.formatAbs(-840000), 'Rp840.000');
      expect(Money.formatAbs(0), 'Rp0');
    });
  });

  group('Money.signOf', () {
    test('tone menentukan arah', () {
      expect(Money.signOf(840000, MoneyTone.incoming), '+');
      expect(Money.signOf(840000, MoneyTone.outgoing), '−');
    });

    test('tanpa tone mengikuti tanda nilai', () {
      expect(Money.signOf(-840000, null), '−');
      expect(Money.signOf(840000, null), isNull);
      expect(Money.signOf(-840000, MoneyTone.neutral), '−');
      expect(Money.signOf(840000, MoneyTone.neutral), isNull);
    });
  });
}
