import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:catatim/models.dart';
import 'package:catatim/rules/engine.dart';
import 'package:catatim/rules/rule_set.dart';

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
    test('terdeteksi lewat nama paket resmi Ollin (id.co.banknagari.ollin)', () {
      final draft = engine.parse(
        packageName: 'id.co.banknagari.ollin',
        title: 'Ollin by Bank Nagari',
        body:
            'Transaksi Debit Rekening 1234567890 Sebesar Rp 150.000 Berhasil.',
      );
      expect(draft, isNotNull);
      expect(draft!.bankId, 'nagari');
      expect(draft.direction, Direction.outgoing);
      expect(draft.amount, 150000);
    });

    test('pembayaran QRIS Ollin', () {
      final draft = engine.parse(
        packageName: 'id.co.banknagari.ollin',
        title: 'Ollin by Bank Nagari',
        body: 'Pembayaran QRIS Sebesar Rp 45.000 Berhasil.',
      );
      expect(draft, isNotNull);
      expect(draft!.bankId, 'nagari');
      expect(draft.direction, Direction.outgoing);
      expect(draft.kind, TxKind.payment);
      expect(draft.amount, 45000);
    });

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
        body:
            'BANKNAGARI: Kredit Rp750.000 dari SITI AMINAH. Saldo Rp3.250.000',
      );
      expect(draft, isNotNull);
      expect(draft!.bankId, 'nagari');
      expect(draft.direction, Direction.incoming);
      expect(draft.amount, 750000);
      expect(draft.counterparty, 'SITI AMINAH');
    });
  });

  group('CustomTemplate & Dynamic Merging', () {
    test('template kustom diprioritaskan di atas template bawaan', () {
      final baseRuleSet = _loadSeed();
      final custom = CustomTemplate(
        id: 'cust_1',
        bankId: 'nagari',
        template: const TemplateRule(
          name: 'Custom Spesial Nagari',
          kind: TxKind.payment,
          direction: Direction.outgoing,
          matchAll: ['spesial', 'diskon'],
        ),
      );

      final merged = baseRuleSet.withCustomTemplates([custom]);
      final customEngine = RuleEngine(merged);

      final draft = customEngine.parse(
        packageName: 'id.co.banknagari.ollin',
        title: 'Ollin',
        body: 'Transaksi Spesial Diskon Sebesar Rp 20.000 Berhasil',
      );

      expect(draft, isNotNull);
      expect(draft!.ruleName, 'Custom Spesial Nagari');
      expect(draft.amount, 20000);
      expect(draft.kind, TxKind.payment);
    });

    test(
      'template kustom untuk paket baru (app:<paket>) didaftarkan dinamis',
      () {
        final baseRuleSet = _loadSeed();
        final custom = CustomTemplate(
          id: 'cust_2',
          bankId: 'app:com.custom.fintech',
          template: const TemplateRule(
            name: 'Fintech Keluar',
            kind: TxKind.payment,
            direction: Direction.outgoing,
            matchAll: ['bayar'],
          ),
        );

        final merged = baseRuleSet.withCustomTemplates([custom]);
        final customEngine = RuleEngine(merged);

        final draft = customEngine.parse(
          packageName: 'com.custom.fintech',
          title: 'Fintech App',
          body: 'Kamu bayar tagihan Rp 99.000 sukses',
        );

        expect(draft, isNotNull);
        expect(draft!.bankId, 'app:com.custom.fintech');
        expect(draft.amount, 99000);
      },
    );
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

  group('Katalog Bank & E-Wallet Baru', () {
    test('BCA: transfer keluar & QRIS', () {
      final tf = engine.parse(
        packageName: 'com.bca',
        title: 'm-BCA',
        body: 'm-Transfer berhasil ke rek 1234567890 a.n. BUDI sebesar Rp 1.500.000',
      );
      expect(tf, isNotNull);
      expect(tf!.bankId, 'bca');
      expect(tf.kind, TxKind.transfer);
      expect(tf.direction, Direction.outgoing);
      expect(tf.amount, 1500000);

      final qris = engine.parse(
        packageName: 'com.bca.mybca',
        title: 'myBCA',
        body: 'Pembayaran QRIS sebesar Rp 75.000 di KOPI KENANGAN Berhasil',
      );
      expect(qris, isNotNull);
      expect(qris!.bankId, 'bca');
      expect(qris.kind, TxKind.payment);
      expect(qris.direction, Direction.outgoing);
      expect(qris.amount, 75000);
      expect(qris.counterparty, 'KOPI KENANGAN');
    });

    test('Livin by Mandiri: transfer masuk & keluar', () {
      final tfMasuk = engine.parse(
        packageName: 'id.bmri.livin',
        title: 'Livin by Mandiri',
        body: 'Kamu menerima transfer masuk sebesar Rp 500.000 dari SITI AMINAH',
      );
      expect(tfMasuk, isNotNull);
      expect(tfMasuk!.bankId, 'mandiri');
      expect(tfMasuk.kind, TxKind.transfer);
      expect(tfMasuk.direction, Direction.incoming);
      expect(tfMasuk.amount, 500000);
      expect(tfMasuk.counterparty, 'SITI AMINAH');

      final tfKeluar = engine.parse(
        packageName: 'id.bmri.livin',
        title: 'Livin by Mandiri',
        body: 'Transfer berhasil ke REK 987654321 sebesar Rp 250.000',
      );
      expect(tfKeluar, isNotNull);
      expect(tfKeluar!.bankId, 'mandiri');
      expect(tfKeluar.kind, TxKind.transfer);
      expect(tfKeluar.direction, Direction.outgoing);
      expect(tfKeluar.amount, 250000);
    });

    test('BRImo: transaksi kredit & qris belanja', () {
      final kredit = engine.parse(
        packageName: 'id.co.bri.brimo',
        title: 'BRImo',
        body: 'Transaksi Kredit Rp 1.000.000 dari PT ABC SUKSES',
      );
      expect(kredit, isNotNull);
      expect(kredit!.bankId, 'bri');
      expect(kredit.kind, TxKind.transfer);
      expect(kredit.direction, Direction.incoming);
      expect(kredit.amount, 1000000);

      final qris = engine.parse(
        packageName: 'id.co.bri.brimo',
        title: 'BRImo',
        body: 'Transaksi QRIS Sebesar Rp 35.000 di TOKO BERKAH Berhasil',
      );
      expect(qris, isNotNull);
      expect(qris!.bankId, 'bri');
      expect(qris.kind, TxKind.payment);
      expect(qris.direction, Direction.outgoing);
      expect(qris.amount, 35000);
      expect(qris.counterparty, 'TOKO BERKAH');
    });

    test('wondr by BNI: transfer & qris', () {
      final qris = engine.parse(
        packageName: 'id.bni.wondr',
        title: 'wondr by BNI',
        body: 'Pembayaran QRIS Rp 50.000 di SUPERINDO Berhasil',
      );
      expect(qris, isNotNull);
      expect(qris!.bankId, 'bni');
      expect(qris.kind, TxKind.payment);
      expect(qris.direction, Direction.outgoing);
      expect(qris.amount, 50000);
      expect(qris.counterparty, 'SUPERINDO');
    });

    test('GoPay: top up & bayar qris', () {
      final topup = engine.parse(
        packageName: 'com.gojek.app',
        title: 'GoPay',
        body: 'Top up berhasil! Saldo masuk Rp 100.000 dari BCA',
      );
      expect(topup, isNotNull);
      expect(topup!.bankId, 'gopay');
      expect(topup.kind, TxKind.topup);
      expect(topup.direction, Direction.incoming);
      expect(topup.amount, 100000);
      expect(topup.counterparty, 'BCA');

      final bayar = engine.parse(
        packageName: 'id.co.gopay',
        title: 'GoPay',
        body: 'Kamu telah membayar Rp 42.000 di INDOMARET',
      );
      expect(bayar, isNotNull);
      expect(bayar!.bankId, 'gopay');
      expect(bayar.kind, TxKind.payment);
      expect(bayar.direction, Direction.outgoing);
      expect(bayar.amount, 42000);
      expect(bayar.counterparty, 'INDOMARET');
    });

    test('OVO: top up & pembayaran', () {
      final topup = engine.parse(
        packageName: 'ovo.id',
        title: 'OVO',
        body: 'Top up berhasil sebesar Rp 200.000',
      );
      expect(topup, isNotNull);
      expect(topup!.bankId, 'ovo');
      expect(topup.kind, TxKind.topup);
      expect(topup.direction, Direction.incoming);
      expect(topup.amount, 200000);

      final bayar = engine.parse(
        packageName: 'ovo.id',
        title: 'OVO',
        body: 'Pembayaran berhasil Rp 15.000 di KANTIN KITA',
      );
      expect(bayar, isNotNull);
      expect(bayar!.bankId, 'ovo');
      expect(bayar.kind, TxKind.payment);
      expect(bayar.direction, Direction.outgoing);
      expect(bayar.amount, 15000);
      expect(bayar.counterparty, 'KANTIN KITA');
    });

    test('DANA: kirim uang & bayar qris', () {
      final kirim = engine.parse(
        packageName: 'id.dana',
        title: 'DANA',
        body: 'Kirim uang berhasil Rp 120.000 ke AHMAD',
      );
      expect(kirim, isNotNull);
      expect(kirim!.bankId, 'dana');
      expect(kirim.kind, TxKind.transfer);
      expect(kirim.direction, Direction.outgoing);
      expect(kirim.amount, 120000);
      expect(kirim.counterparty, 'AHMAD');

      final bayar = engine.parse(
        packageName: 'id.dana',
        title: 'DANA',
        body: 'Pembayaran berhasil Rp 18.000 di MINIMARKET',
      );
      expect(bayar, isNotNull);
      expect(bayar!.bankId, 'dana');
      expect(bayar.kind, TxKind.payment);
      expect(bayar.direction, Direction.outgoing);
      expect(bayar.amount, 18000);
      expect(bayar.counterparty, 'MINIMARKET');
    });

    test('ShopeePay: pembayaran & transfer keluar', () {
      final bayar = engine.parse(
        packageName: 'com.shopee.id',
        title: 'ShopeePay',
        body: 'Pembayaran berhasil sebesar Rp 85.000 di SELLER SHOP',
      );
      expect(bayar, isNotNull);
      expect(bayar!.bankId, 'shopeepay');
      expect(bayar.kind, TxKind.payment);
      expect(bayar.direction, Direction.outgoing);
      expect(bayar.amount, 85000);
      expect(bayar.counterparty, 'SELLER SHOP');
    });
  });

  test('bankFor: paket blu dikenal, chat tidak', () {
    expect(
      engine.bankFor(packageName: 'com.bcadigital.blu', lowerText: 'apa saja'),
      isNotNull,
    );
    expect(
      engine.bankFor(
        packageName: 'com.whatsapp',
        lowerText: 'pesan masuk halo bro',
      ),
      isNull,
    );
    // kata kunci konten tetap dikenali meski paket tidak terdaftar
    expect(
      engine
          .bankFor(
            packageName: 'com.vendor.smsrelay',
            lowerText: 'banknagari: kredit rp750.000',
          )
          ?.id,
      'nagari',
    );
    // filter koneksi membatasi hasil
    expect(
      engine.bankFor(
        packageName: 'com.bcadigital.blu',
        lowerText: 'apa saja',
        onlyIds: {'nagari'},
      ),
      isNull,
    );
  });

  test('seed rules memuat 3 bank', () {
    final set = _loadSeed();
    expect(
      set.banks.map((b) => b.id),
      containsAll(['blu', 'nagari', 'unknown']),
    );
  });

  group('Deteksi Notifikasi Non-Transaksi & Pola Abaikan', () {
    test('deteksi OTP dan kode keamanan', () {
      expect(
        RuleEngine.isNonTransactionNotification('Kode OTP Anda adalah 123456. Jangan berikan ke siapa pun.'),
        isTrue,
      );
      expect(
        RuleEngine.isNonTransactionNotification('BCA: Kode verifikasi m-Token Anda 849201 untuk login.'),
        isTrue,
      );
    });

    test('deteksi login baru dan alert keamanan akun', () {
      expect(
        RuleEngine.isNonTransactionNotification('Login baru berhasil dari Chrome Windows pada 12:30 WIB.'),
        isTrue,
      );
      expect(
        RuleEngine.isNonTransactionNotification('Perangkat baru terdeteksi masuk ke akun blu Anda.'),
        isTrue,
      );
    });

    test('deteksi promo dan penawaran pemasaran', () {
      expect(
        RuleEngine.isNonTransactionNotification('Dapatkan cashback hingga Rp 50.000 dengan bayar QRIS. S&K berlaku.'),
        isTrue,
      );
    });

    test('deteksi sisa saldo murni tanpa mutasi transaksi', () {
      expect(
        RuleEngine.isNonTransactionNotification('Sisa saldo rekening Anda saat ini adalah Rp 1.500.000.'),
        isTrue,
      );
    });

    test('transaksi riil tidak dianggap non-transaksi', () {
      expect(
        RuleEngine.isNonTransactionNotification('Transfer masuk sebesar Rp 500.000 dari BUDI'),
        isFalse,
      );
      expect(
        RuleEngine.isNonTransactionNotification('Pembayaran QRIS Rp 25.000 di Kopi Kenangan berhasil'),
        isFalse,
      );
    });

    test('isIgnored mencocokkan pola yang dipelajari', () {
      final customEngine = RuleEngine(
        _loadSeed(),
        ignoredPatterns: [
          IgnoredPattern(
            id: 'p1',
            pattern: 'survey kepuasan',
            label: 'Survey',
            createdAt: DateTime.now(),
          ),
          IgnoredPattern(
            id: 'p2',
            pattern: 'tagihan kartu kredit',
            label: 'BCA Billing',
            bankId: 'bca',
            createdAt: DateTime.now(),
          ),
        ],
      );

      // Cocok dengan pola global
      expect(customEngine.isIgnored('Mohon isi survey kepuasan pelanggan blu'), isTrue);

      // Cocok dengan pola spesifik bank
      expect(customEngine.isIgnored('Tagihan kartu kredit Anda jatuh tempo', bankId: 'bca'), isTrue);
      // Tidak cocok jika bank berbeda
      expect(customEngine.isIgnored('Tagihan kartu kredit Anda jatuh tempo', bankId: 'mandiri'), isFalse);
    });
  });
}
