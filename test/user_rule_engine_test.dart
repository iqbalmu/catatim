import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bukuduit/models.dart';
import 'package:bukuduit/rules/engine.dart';
import 'package:bukuduit/rules/rule_set.dart';

RuleEngine _engine({List<UserRuleDef> userRules = const []}) {
  final seed = '''
{
  "version": 1,
  "banks": [
    {
      "id": "blu",
      "displayName": "blu by BCA",
      "packageNames": ["com.bcadigital.blu"],
      "keywords": ["blu by bca"],
      "templates": [
        {
          "name": "transfer masuk",
          "kind": "transfer",
          "direction": "in",
          "matchAll": ["transfer masuk"]
        }
      ]
    },
    {
      "id": "unknown",
      "displayName": "Tidak dikenal",
      "packageNames": [],
      "keywords": [],
      "templates": [
        {
          "name": "keluar umum",
          "kind": "payment",
          "direction": "out",
          "matchAny": ["pembayaran", "debit"]
        }
      ]
    }
  ]
}
''';
  final set = RuleSet.fromJson(
    (const JsonDecoder().convert(seed)) as Map<String, dynamic>,
  );
  final engine = RuleEngine(set);
  engine.setUserRules(userRules);
  return engine;
}

void main() {
  test('tanpa aturan user: seed rules yang dipakai', () {
    final engine = _engine();
    final draft = engine.parse(
      packageName: 'com.bcadigital.blu',
      title: 'blu',
      body: 'Kamu menerima transfer masuk Rp100.000 dari BUDI',
    );
    expect(draft, isNotNull);
    expect(draft!.direction, Direction.incoming);
    expect(draft.amount, 100000);
  });

  test('aturan user dengan package match menimpa seed rules', () {
    final engine = _engine(
      userRules: [
        UserRuleDef(
          id: 1,
          name: 'Tarik tunai blu',
          packageName: 'com.bcadigital.blu',
          matchText: 'tarik tunai',
          direction: Direction.outgoing,
          kind: TxKind.withdrawal,
        ),
      ],
    );
    final draft = engine.parse(
      packageName: 'com.bcadigital.blu',
      title: '',
      body: 'Tarik tunai Rp500.000 berhasil',
    );
    expect(draft, isNotNull);
    expect(draft!.ruleName, 'Tarik tunai blu');
    expect(draft.direction, Direction.outgoing);
    expect(draft.kind, TxKind.withdrawal);
    expect(draft.amount, 500000);
  });

  test('aturan user dengan package berbeda tidak ikut mencocokkan', () {
    final engine = _engine(
      userRules: [
        UserRuleDef(
          id: 1,
          name: 'Hanya gopay',
          packageName: 'id.gopay.consumer',
          matchText: 'topup',
          direction: Direction.incoming,
          kind: TxKind.topup,
        ),
      ],
    );
    final draft = engine.parse(
      packageName: 'com.bcadigital.blu',
      title: '',
      body: 'Topup berhasil Rp50.000',
    );
    // Aturan user tidak cocok (beda paket) → seed rules: tidak ada match.
    expect(draft, isNull);
  });

  test('aturan user dengan pola custom eksklusif: tidak match → gugur', () {
    final engine = _engine(
      userRules: [
        UserRuleDef(
          id: 1,
          name: 'Nominal aneh',
          packageName: 'com.bcadigital.blu',
          matchText: 'transfer masuk',
          amountPattern: r'@([\d]+)', // tidak ada di teks → gagal → fallback
          direction: Direction.incoming,
          kind: TxKind.transfer,
        ),
      ],
    );
    final draft = engine.parse(
      packageName: 'com.bcadigital.blu',
      title: '',
      body: 'Kamu menerima transfer masuk Rp100.000 dari BUDI',
    );
    // Pola custom gagal → rule gugur → jatuh ke seed rule "transfer masuk".
    expect(draft, isNotNull);
    expect(draft!.ruleName, 'transfer masuk');
    expect(draft.amount, 100000);
  });
}
