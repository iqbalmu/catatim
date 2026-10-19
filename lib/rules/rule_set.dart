import '../models.dart';

/// Seluruh set aturan parsing, dimuat dari JSON.
class RuleSet {
  RuleSet({required this.version, required this.banks});

  final int version;
  final List<BankRules> banks;

  late final Map<String, BankRules> _byId = {for (final b in banks) b.id: b};

  BankRules? bank(String id) => _byId[id];

  factory RuleSet.fromJson(Map<String, dynamic> json) => RuleSet(
    version: (json['version'] as num?)?.toInt() ?? 1,
    banks: [
      for (final b in json['banks'] as List<dynamic>? ?? const [])
        BankRules.fromJson(b as Map<String, dynamic>),
    ],
  );
}

/// Aturan milik satu bank/e-wallet.
class BankRules {
  const BankRules({
    required this.id,
    required this.displayName,
    required this.packageNames,
    required this.keywords,
    required this.templates,
  });

  final String id;
  final String displayName;

  /// Nama package aplikasi Android yang notifikasinya dicocokkan persis.
  final List<String> packageNames;

  /// Kata kunci konten (title+body, lowercase) untuk mendeteksi bank
  /// ketika packageName tidak dikenal.
  final List<String> keywords;
  final List<TemplateRule> templates;

  factory BankRules.fromJson(Map<String, dynamic> json) => BankRules(
    id: json['id'] as String,
    displayName: json['displayName'] as String? ?? json['id'] as String,
    packageNames: _strings(json['packageNames']),
    keywords: _strings(json['keywords']).map((e) => e.toLowerCase()).toList(),
    templates: [
      for (final t in json['templates'] as List<dynamic>? ?? const [])
        TemplateRule.fromJson(t as Map<String, dynamic>),
    ],
  );

  static List<String> _strings(Object? value) => [
    for (final v in value as List<dynamic>? ?? const []) v as String,
  ];
}

/// Jenis akun bank/e-wallet ini menurut kata kunci katalognya — dipakai
/// untuk ikon, pengelompokan, dan pembuatan akun saat terhubung.
extension BankRulesAccountKind on BankRules {
  AccountKind get accountKind => keywords.any(
        (k) =>
            k.contains('pay') ||
            k.contains('ovo') ||
            k.contains('dana') ||
            k.contains('gopay') ||
            k.contains('emoney') ||
            k.contains('e-money') ||
            k.contains('wallet') ||
            k.contains('dompet'),
      )
      ? AccountKind.ewallet
      : AccountKind.bank;
}

/// Satu template: kapan berlaku, arah/jenisnya, dan pola ekstraksi.
class TemplateRule {
  const TemplateRule({
    required this.name,
    required this.kind,
    required this.direction,
    this.matchAll = const [],
    this.matchAny = const [],
    this.notMatch = const [],
    this.amountPattern,
    this.counterpartyPattern,
    this.balancePattern,
  });

  final String name;
  final TxKind kind;
  final Direction direction;

  /// Semua substring ini harus ada (lowercase).
  final List<String> matchAll;

  /// Minimal satu substring ini harus ada; kosong = bebas.
  final List<String> matchAny;

  /// Tidak boleh ada satu pun substring ini.
  final List<String> notMatch;

  /// Regex custom nominal; null = pakai default engine.
  final String? amountPattern;
  final String? counterpartyPattern;
  final String? balancePattern;

  bool matches(String lowerText) {
    for (final m in matchAll) {
      if (!lowerText.contains(m)) return false;
    }
    if (matchAny.isNotEmpty && !matchAny.any(lowerText.contains)) {
      return false;
    }
    for (final n in notMatch) {
      if (lowerText.contains(n)) return false;
    }
    return true;
  }

  factory TemplateRule.fromJson(Map<String, dynamic> json) => TemplateRule(
    name: json['name'] as String,
    kind: txKindFromString(json['kind'] as String),
    direction: directionFromString(json['direction'] as String),
    matchAll: BankRules._strings(
      json['matchAll'],
    ).map((e) => e.toLowerCase()).toList(),
    matchAny: BankRules._strings(
      json['matchAny'],
    ).map((e) => e.toLowerCase()).toList(),
    notMatch: BankRules._strings(
      json['notMatch'],
    ).map((e) => e.toLowerCase()).toList(),
    amountPattern: json['amount'] as String?,
    counterpartyPattern: json['counterparty'] as String?,
    balancePattern: json['balance'] as String?,
  );
}

Direction directionFromString(String value) => switch (value) {
  'in' => Direction.incoming,
  'out' => Direction.outgoing,
  _ => throw ArgumentError('direction tidak dikenal: $value'),
};

TxKind txKindFromString(String value) => switch (value) {
  'transfer' => TxKind.transfer,
  'payment' => TxKind.payment,
  'topup' => TxKind.topup,
  'withdrawal' => TxKind.withdrawal,
  'other' => TxKind.other,
  _ => throw ArgumentError('kind tidak dikenal: $value'),
};
