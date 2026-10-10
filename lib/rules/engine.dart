import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/money.dart';
import '../models.dart';
import 'rule_set.dart';

/// Aturan buatan pengguna yang sudah dipetakan (dari DB) — diprioritaskan
/// di atas seed rules.
class UserRuleDef {
  const UserRuleDef({
    required this.id,
    required this.name,
    this.packageName,
    this.matchText,
    this.amountPattern,
    required this.direction,
    required this.kind,
    this.accountId,
  });

  final int id;
  final String name;

  /// Null = cocok paket mana pun.
  final String? packageName;

  /// Null = bebas kata kunci; terisi = title+body harus mengandung ini
  /// (case-insensitive).
  final String? matchText;
  final String? amountPattern;
  final Direction direction;
  final TxKind kind;
  final int? accountId;

  bool matches(String rawPackageName, String lower) {
    final pkg = packageName;
    if (pkg != null && pkg != rawPackageName) {
      return false;
    }
    final text = matchText?.toLowerCase();
    if (text != null && text.isNotEmpty && !lower.contains(text)) {
      return false;
    }
    return true;
  }
}

/// Mesin pencocokan notifikasi → draf transaksi berbasis template JSON.
class RuleEngine {
  RuleEngine(this._ruleSet);

  final RuleSet _ruleSet;

  /// Aturan pengguna — selalu dicoba sebelum seed rules.
  List<UserRuleDef> _userRules = const [];

  void setUserRules(List<UserRuleDef> rules) {
    _userRules = List.unmodifiable(rules);
  }

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
  BankRules? get _generic => _ruleSet.bank('unknown');

  /// Mengembalikan null bila notifikasi bukan transaksi yang dikenali.
  ParsedDraft? parse({
    required String packageName,
    required String title,
    required String body,
  }) {
    final text = '$title $body';
    final lower = text.toLowerCase();

    // 1) Aturan pengguna — prioritas tertinggi.
    for (final rule in _userRules) {
      if (!rule.matches(packageName, lower)) continue;
      final amount = _extractAmount(rule.amountPattern, text);
      if (amount == null) continue;
      return ParsedDraft(
        bankId: 'user',
        bankName: rule.name,
        ruleName: rule.name,
        kind: rule.kind,
        direction: rule.direction,
        amount: amount,
        counterparty: null,
        accountId: rule.accountId,
      );
    }

    // 2) Seed rules.
    final bank = _detectBank(packageName, lower);
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

  BankRules? _detectBank(String packageName, String lower) {
    for (final b in _ruleSet.banks) {
      if (b.packageNames.contains(packageName)) return b;
    }
    for (final b in _ruleSet.banks) {
      if (b.keywords.any(lower.contains)) return b;
    }
    return null;
  }

  /// Benar bila notifikasi berasal dari app bank yang dikenal (packageName
  /// terdaftar) atau kontennya mengandung kata kunci bank — dipakai filter
  /// capture di luar mode pelajaran.
  bool isKnownSource(String packageName, String title, String body) {
    final lower = '$title $body'.toLowerCase();
    return _detectBank(packageName, lower) != null;
  }

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
