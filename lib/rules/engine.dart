import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/money.dart';
import '../models.dart';
import 'rule_set.dart';

/// Mesin pencocokan notifikasi → draf transaksi berbasis template JSON.
class RuleEngine {
  RuleEngine(this._ruleSet);

  final RuleSet _ruleSet;

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
    final patterns = [
      ?customPattern,
      ..._defaultAmountPatterns,
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
