/// Utilitas angka rupiah.
///
/// Rupiah disimpan sebagai `int` satuan penuh (tanpa sen).
library;

/// Arah tampilan nominal — menentukan tanda arah yang digambar di depan
/// angka (`+` untuk pemasukan, `−` untuk pengeluaran).
///
/// [MoneyTone] dipakai bersama oleh formatter data ([Money.format]) dan
/// widget display ([QuestMoney]) supaya satu nominal tidak pernah memakai
/// dua bentuk tanda berbeda.
enum MoneyTone { neutral, incoming, outgoing }

class Money {
  Money._();

  /// Tanda minus tipografis U+2212 — lebarnya sepadan dengan digit dan
  /// duduk di sumbu matematika, berbeda dengan hyphen ASCII yang pendek
  /// dan menggantung di atas huruf. Nunito menyediakan glyph ini.
  static const String minusGlyph = '−';

  /// Tanda plus.
  static const String plusGlyph = '+';

  /// Mengubah grup digit hasil regex (mis. `"1.234.567"`, `"50000"`,
  /// `"50.000,50"`) menjadi int rupiah.
  static int parseGroup(String group) {
    var s = group.trim().replaceAll(RegExp(r'[^0-9.,]'), '');
    if (s.isEmpty) throw const FormatException('amount kosong');
    // Koma diikuti 1-2 digit di akhir = desimal; rupiah dibulatkan ke bawah.
    final commaDecimal = RegExp(r',\d{1,2}$').firstMatch(s);
    if (commaDecimal != null) s = s.substring(0, commaDecimal.start);
    s = s.replaceAll(RegExp(r'[.,]'), '');
    return int.parse(s);
  }

  static int? tryParseGroup(String? group) {
    if (group == null) return null;
    try {
      return parseGroup(group);
    } on FormatException {
      return null;
    }
  }

  /// Digit absolut dengan pemisah ribuan: `1234567` → `"1.234.567"`.
  static String groupDigits(int value) {
    final digits = value.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buf.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) buf.write('.');
    }
    return buf.toString();
  }

  /// Nominal tanpa tanda arah: `840000` → `"Rp840.000"`.
  ///
  /// Dipakai widget display yang menggambar tanda sendiri sebagai marker
  /// subordinat (lihat `QuestMoney`).
  static String formatAbs(int amount) => 'Rp${groupDigits(amount)}';

  /// Format nominal lengkap. `1234567` → `"Rp1.234.567"`,
  /// `-5000` → `"−Rp5.000"` (tanda U+2212).
  static String format(int amount) =>
      amount < 0 ? '$minusGlyph${formatAbs(amount)}' : formatAbs(amount);

  /// Tanda arah untuk [amount] sesuai [tone].
  ///
  /// - [MoneyTone.incoming] → `+`
  /// - [MoneyTone.outgoing] → `−`
  /// - [MoneyTone.neutral] atau `null` → `−` bila [amount] negatif,
  ///   selain itu tanpa tanda.
  static String? signOf(int amount, MoneyTone? tone) {
    switch (tone) {
      case MoneyTone.incoming:
        return plusGlyph;
      case MoneyTone.outgoing:
        return minusGlyph;
      case MoneyTone.neutral:
      case null:
        return amount < 0 ? minusGlyph : null;
    }
  }
}
