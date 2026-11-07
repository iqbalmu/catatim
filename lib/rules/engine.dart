import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/money.dart';
import '../models.dart';
import 'rule_set.dart';

/// Mesin pencocokan notifikasi → draf transaksi berbasis template JSON.
class RuleEngine {
  RuleEngine(this.ruleSet, {this.ignoredPatterns = const []});

  RuleSet ruleSet;
  List<IgnoredPattern> ignoredPatterns;

  /// Pola nominal default, dicoba berurutan:
  /// 1. "Rp" atau "Rp." diikuti angka bebas (paling spesifik).
  /// 2. Angka bergrup ribuan ("1.234.567" / "1,234,567").
  /// Pola `\d+` polos sengaja tidak dipakai default agar nomor telepon /
  /// nomor rekening tidak ter catastrophe sebagai nominal.
  static final List<String> _defaultAmountPatterns = [
    r'[Rr][Pp]\.?\s*([\d][\d.,]*)',
    r'(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?)',
  ];

  static const int _maxSaneAmount = 999999999999; // ≤ 1 triliun
  static const int _minSaneAmount = 1;

  /// Bank generik sebagai fallback bila bank tidak dikenali.
  BankRules? get _generic => ruleSet.bank('unknown');

  /// Deteksi apakah pesan adalah notifikasi non-transaksi (OTP, login alert, promo, info saldo).
  static bool isNonTransactionNotification(String text) {
    final lower = text.toLowerCase();

    // 1. OTP & Kode Otentikasi
    const otpKeywords = [
      'otp',
      'one time password',
      'kode verifikasi',
      'kode rahasia',
      'kode keamanan',
      'security code',
      'passcode',
      'jangan berikan kode',
      'jangan beritahu kode',
      'jangan bagikan kode',
      'jangan berikan ke siapa',
      'kode aktivasi',
      'm-token',
    ];
    if (otpKeywords.any(lower.contains)) return true;

    // 2. Akses Akun & Login
    const loginKeywords = [
      'login baru',
      'login berhasil',
      'berhasil login',
      'perangkat baru terdeteksi',
      'perangkat baru berhasil',
      'masuk ke perangkat baru',
      'ganti password',
      'ubah password',
      'ganti pin',
      'ubah pin',
      'sesi anda berakhir',
      'session expired',
      'aktivasi akun',
      'pemblokiran kartu',
    ];
    if (loginKeywords.any(lower.contains)) return true;

    // 3. Pemasaran, Promo & Penawaran (yang bukan mutasi riil)
    const promoKeywords = [
      'cashback hingga',
      'dapatkan cashback',
      'promo diskon',
      'nikmati promo',
      'penawaran spesial',
      'apply kartu kredit',
      'pengajuan pinjaman',
      'khusus untuk anda',
      'khusus untukmu',
      's&k berlaku',
      'syarat dan ketentuan berlaku',
    ];
    if (promoKeywords.any(lower.contains)) return true;

    // 4. Informasi Saldo Murni (tanpa kata mutasi riil)
    const balanceOnlyKeywords = [
      'sisa saldo anda',
      'sisa saldo rekening',
      'informasi saldo',
      'saldo rekening anda',
      'saldo anda saat ini',
    ];
    if (balanceOnlyKeywords.any(lower.contains) &&
        !lower.contains('berhasil') &&
        !lower.contains('transfer') &&
        !lower.contains('pembayaran') &&
        !lower.contains('debit') &&
        !lower.contains('kredit')) {
      return true;
    }

    // 5. Pemeliharaan Sistem
    const maintenanceKeywords = [
      'pemeliharaan sistem',
      'maintenance sistem',
      'gangguan sementara',
      'jadwal pemeliharaan',
    ];
    if (maintenanceKeywords.any(lower.contains)) return true;

    return false;
  }

  /// Cek apakah notifikasi diabaikan (karena non-transaksi atau pola yang dipelajari).
  bool isIgnored(String text, {String? bankId}) {
    if (isNonTransactionNotification(text)) return true;
    final lower = text.toLowerCase();
    for (final ip in ignoredPatterns) {
      if (ip.bankId != null && bankId != null && ip.bankId != bankId) continue;
      if (lower.contains(ip.pattern)) return true;
    }
    return false;
  }

  /// Mengembalikan null bila notifikasi bukan transaksi yang dikenali.
  ParsedDraft? parse({
    required String packageName,
    required String title,
    required String body,
  }) {
    final text = '$title $body';
    final lower = text.toLowerCase();

    // Bank terdeteksi
    final bank = _detectBank(packageName, lower);

    if (isIgnored(text, bankId: bank?.id)) return null;

    // Seed rules — katalog bank murni (model hubungkan bank).
    final candidates = <BankRules>[
      ?bank,
      if (_generic != null && bank?.id != 'unknown') _generic!,
    ];

    for (final candidate in candidates) {
      for (final template in candidate.templates) {
        if (!template.matches(lower)) continue;
        final amount = _extractAmount(template.amountPattern, text);
        if (amount == null) continue;
        // Bank terdeteksi tetap dipertahankan walaupun template yang cocok
        // berasal dari rules generik (fallback).
        final reported = bank ?? candidate;
        return ParsedDraft(
          bankId: reported.id,
          bankName: reported.displayName,
          ruleName: template.name,
          kind: template.kind,
          direction: template.direction,
          amount: amount,
          counterparty: _extractGroup(template.counterpartyPattern, text),
        );
      }
    }
    return null;
  }

  BankRules? _detectBank(String packageName, String lower) =>
      bankFor(packageName: packageName, lowerText: lower);

  /// Bank katalog yang cocok dengan paket/teks ini, dibatasi ke [onlyIds]
  /// bila diberikan — dipakai pipeline model hubungkan bank.
  BankRules? bankFor({
    required String packageName,
    required String lowerText,
    Set<String>? onlyIds,
  }) {
    for (final b in ruleSet.banks) {
      if (onlyIds != null && !onlyIds.contains(b.id)) continue;
      if (b.packageNames.contains(packageName)) return b;
    }
    for (final b in ruleSet.banks) {
      if (onlyIds != null && !onlyIds.contains(b.id)) continue;
      if (b.keywords.any(lowerText.contains)) return b;
    }
    return null;
  }

  /// Package names katalog milik bank-bank ini — dipakai pipeline untuk
  /// menyusun allowlist antrean native. Tidak termasuk paket belajaran.
  Set<String> packageNamesFor(Set<String> bankIds) => {
    for (final b in ruleSet.banks)
      if (bankIds.contains(b.id)) ...b.packageNames,
  };

  int? _extractAmount(String? customPattern, String text) {
    // Pola custom dari aturan pengguna bersifat eksklusif: bila gagal
    // mencocokkan, JANGAN jatuh ke pola default — salah-potong lebih
    // berbahaya daripada tidak tercatat.
    final patterns = [
      ?customPattern,
      if (customPattern == null) ..._defaultAmountPatterns,
    ];
    for (final pattern in patterns) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(text);
      if (match == null) continue;
      final group = match.group(match.groupCount >= 1 ? 1 : 0);
      final value = Money.tryParseGroup(group);
      if (value == null) continue;
      if (value < _minSaneAmount || value > _maxSaneAmount) continue;
      return value;
    }
    return null;
  }

  /// Tebakan untuk notifikasi berformat tak dikenal (mode belajar):
  /// nominal dari pola umum + arah dari kata umum. Boleh salah —
  /// nominal/arah/kategori final tetap keputusan user saat konfirmasi.
  ({int? amount, Direction direction}) guess(String title, String body) {
    final text = '$title $body';
    final amount = _extractAmount(null, text);
    final lower = text.toLowerCase();
    const inWords = [
      'dana masuk',
      'uang masuk',
      'transfer masuk',
      'setoran masuk',
      'setoran',
      'kredit',
      'menerima transfer',
      'menerima dana',
      'diterima dari',
      'berhasil ditambahkan',
      'top up berhasil',
      'isi saldo berhasil',
    ];
    const outWords = [
      'dana keluar',
      'uang keluar',
      'transfer keluar',
      'transfer ke',
      'debit',
      'pembayaran',
      'membayar',
      'belanja',
      'tarik tunai',
      'tarik',
      'qris',
    ];
    final isIn = inWords.any(lower.contains);
    final isOut = outWords.any(lower.contains);
    return (
      amount: amount,
      direction: isIn && !isOut ? Direction.incoming : Direction.outgoing,
    );
  }

  String? _extractGroup(String? pattern, String text) {
    if (pattern == null) return null;
    final match = RegExp(pattern, caseSensitive: false).firstMatch(text);
    if (match == null || match.groupCount < 1) return null;
    final value = match.group(1)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }
}

/// Memuat seed rules dari asset bundle.
Future<RuleSet> loadSeedRuleSet() async {
  final raw = await rootBundle.loadString('assets/rules/seed_rules.json');
  return RuleSet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
