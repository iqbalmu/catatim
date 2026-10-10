import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bukuduit/models.dart';
import 'package:bukuduit/rules/engine.dart';
import 'package:bukuduit/rules/rule_set.dart';

RuleSet _loadSeed() {
  final raw = File('assets/rules/seed_rules.json').readAsStringSync();
  return RuleSet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  late RuleEngine engine;

  setUp(() {
    engine = RuleEngine(_loadSeed());
  });

  group('blu by BCA', () {
    test('format asli: penambahan dana blusaving', () {
      final draft = engine.parse(
        packageName: 'com.bcadigital.blu',
        title: 'Kamu Berhasil Menambahkan Dana',
        body: 'Penambahan dana ke bluSaving sisa Rp 2.000 berhasil',
      );
      expect(draft, isNotNull);
      expect(draft!.bankId, 'blu');
      expect(draft.kind, TxKind.topup);
      expect(draft.direction, Direction.incoming);
      expect(draft.amount, 2000);
    });

    test('transfer masuk dengan pihak', () {
      final draft = engine.parse(
        packageName: 'id.bm.blu',
        title: 'blu by BCA',
        body:
            'Kamu menerima transfer masuk sebesar Rp2.000.000 dari BUDI SANTOSO',
        );
      expect(draft, isNotNull);
      expect(draft!.bankId, 'blu');
      expect(draft.direction, Direction.incoming);
      expect(draft.amount, 2000000);
      expect(draft.counterparty, 'BUDI SANTOSO');
    });

    test('debit pembayaran → jatuh ke template generik, bank tetap blu', () {
      final draft = engine.parse(
        packageName: 'id.bm.blu',
        title: 'blu',
        body:
            'Transaksi debit Rp150.000 ke KOPI KENANGAN berhasil. Saldo Rp1.234.500',
      );
      expect(draft, isNotNull);
      expect(draft!.bankId, 'blu');
      expect(draft.direction, Direction.outgoing);
      expect(draft.amount, 150000);
    });

    test('promo dengan nominal tapi bukan transaksi → null', () {
      final draft = engine.parse(
        packageName: 'id.bm.blu',
        title: 'blu',
        body: 'Promo! Cashback hingga Rp50.000 tiap Jumat minggu ini',
      );
      expect(draft, isNull);
    });
  });

  group('Bank Nagari', () {
    test('terdeteksi lewat kata kunci meski packageName tidak dikenal', () {
      final draft = engine.parse(
        packageName: 'com.vendor.smsrelay',
        title: '',
        body:
            'BANK NAGARI: Transfer ke 1234567890 a.n. ANDI PRATAMA Rp 500.000 Berhasil. Saldo Rp2.500.000',
      );
      expect(draft, isNotNull);
      expect(draft!.bankId, 'nagari');
      expect(draft.direction, Direction.outgoing);
      expect(draft.amount, 500000);
    });

    test('kredit masuk', () {
      final draft = engine.parse(
        packageName: '',
        title: '',
        body: 'BANKNAGARI: Kredit Rp750.000 dari SITI AMINAH. Saldo Rp3.250.000',
      );
      expect(draft, isNotNull);
      expect(draft!.bankId, 'nagari');
      expect(draft.direction, Direction.incoming);
      expect(draft.amount, 750000);
      expect(draft.counterparty, 'SITI AMINAH');
    });
  });

  group('fallback generik', () {
    test('app tidak dikenal dengan pola umum', () {
      final draft = engine.parse(
        packageName: 'com.random.app',
        title: 'Notifikasi',
        body: 'Pembayaran QRIS Rp25.000 ke INDOMARET berhasil',
      );
      expect(draft, isNotNull);
      expect(draft!.bankId, 'unknown');
      expect(draft.direction, Direction.outgoing);
      expect(draft.amount, 25000);
    });

    test('notifikasi tanpa nominal → null', () {
      final draft = engine.parse(
        packageName: 'id.bm.blu',
        title: 'blu',
        body: 'Login baru dari perangkat Android',
      );
      expect(draft, isNull);
    });

    test('nomor rekening panjang tanpa prefix Rp tidak jadi nominal', () {
      final draft = engine.parse(
        packageName: 'com.otherbank.app',
        title: '',
        body: 'Transfer ke 1234567890 a.n. BUDI telah diproses',
      );
      // "transfer ke " cocok template nagari? tidak — bank tak terdeteksi;
      // generik 'keluar umum' tidak memuat 'transfer ke'. Tanpa nominal
      // valid → null.
      expect(draft, isNull);
    });
  });

  test('seed rules memuat 3 bank', () {
    final set = _loadSeed();
    expect(set.banks.map((b) => b.id), containsAll(['blu', 'nagari', 'unknown']));
  });
}
