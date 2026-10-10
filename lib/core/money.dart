/// Utilitas angka rupiah.
///
/// Rupiah disimpan sebagai `int` satuan penuh (tanpa sen).
class Money {
  Money._();

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

  /// Format `1234567` → `"Rp1.234.567"`, `-5000` → `"-Rp5.000"`.
  static String format(int amount) {
    final digits = amount.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buf.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) buf.write('.');
    }
    final sign = amount < 0 ? '-' : '';
    return '$sign Rp$buf'.replaceFirst(' ', '');
  }
}
