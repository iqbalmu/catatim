import 'dart:async';

import '../models.dart';
import '../rules/engine.dart';
import '../storage/repository.dart';
import 'pipeline.dart';

/// Definisi skenario uji coba notifikasi.
class CaptureScenario {
  const CaptureScenario({
    required this.id,
    required this.group,
    required this.name,
    required this.packageName,
    required this.title,
    required this.body,
    this.expectedParsed = true,
    this.expectedKind,
    this.expectedDirection,
    this.expectedAmount,
    this.expectedCounterparty,
    this.isNegative = false,
  });

  final String id;
  final String group;
  final String name;
  final String packageName;
  final String title;
  final String body;
  final bool expectedParsed;
  final TxKind? expectedKind;
  final Direction? expectedDirection;
  final int? expectedAmount;
  final String? expectedCounterparty;
  final bool isNegative;
}

/// Hasil evaluasi simulasi notifikasi (Dry-Run atau Batch).
class SimulationEvaluation {
  const SimulationEvaluation({
    this.scenario,
    required this.packageName,
    required this.title,
    required this.body,
    required this.parsed,
    this.bankId,
    this.bankName,
    this.templateName,
    this.amount,
    this.direction,
    this.kind,
    this.counterparty,
    this.isFallbackGuess = false,
    required this.passedExpectation,
    required this.message,
  });

  final CaptureScenario? scenario;
  final String packageName;
  final String title;
  final String body;
  final bool parsed;
  final String? bankId;
  final String? bankName;
  final String? templateName;
  final int? amount;
  final Direction? direction;
  final TxKind? kind;
  final String? counterparty;
  final bool isFallbackGuess;
  final bool passedExpectation;
  final String message;
}

/// Laporan eksekusi batch seluruh preset notifikasi.
class BatchSimulationReport {
  const BatchSimulationReport({
    required this.total,
    required this.passed,
    required this.failed,
    required this.evaluations,
  });

  final int total;
  final int passed;
  final int failed;
  final List<SimulationEvaluation> evaluations;

  bool get isAllPassed => failed == 0 && total > 0;
  double get passRate => total == 0 ? 0 : (passed / total) * 100;
}

/// Kumpulan skenario notifikasi bawaan Bukuduit.
const List<CaptureScenario> kSimulatorPresets = [
  // --- blu by BCA ---
  CaptureScenario(
    id: 'blu_topup_saving',
    group: 'blu by BCA',
    name: 'Tambah Dana blusaving',
    packageName: 'com.bcadigital.blu',
    title: 'blu by BCA',
    body: 'Penambahan dana blusaving sebesar Rp 150.000 berhasil',
    expectedParsed: true,
    expectedKind: TxKind.topup,
    expectedDirection: Direction.incoming,
    expectedAmount: 150000,
  ),
  CaptureScenario(
    id: 'blu_transfer_in',
    group: 'blu by BCA',
    name: 'Transfer Masuk',
    packageName: 'com.bcadigital.blu',
    title: 'blu',
    body: 'Transfer masuk dari BUDI SANTOSO sebesar Rp 250.000 berhasil.',
    expectedParsed: true,
    expectedKind: TxKind.transfer,
    expectedDirection: Direction.incoming,
    expectedAmount: 250000,
    expectedCounterparty: 'BUDI SANTOSO',
  ),
  CaptureScenario(
    id: 'blu_menerima_uang',
    group: 'blu by BCA',
    name: 'Menerima Uang',
    packageName: 'com.bcadigital.blu',
    title: 'blu by BCA',
    body: 'Kamu menerima uang dari SITI NURHALIZA sebesar Rp 50.000.',
    expectedParsed: true,
    expectedKind: TxKind.transfer,
    expectedDirection: Direction.incoming,
    expectedAmount: 50000,
    expectedCounterparty: 'SITI NURHALIZA',
  ),
  CaptureScenario(
    id: 'blu_transfer_out',
    group: 'blu by BCA',
    name: 'Transfer Keluar',
    packageName: 'com.bcadigital.blu',
    title: 'blu by BCA',
    body: 'Transfer ke ANDI WIJAYA sebesar Rp 75.000 berhasil.',
    expectedParsed: true,
    expectedKind: TxKind.transfer,
    expectedDirection: Direction.outgoing,
    expectedAmount: 75000,
    expectedCounterparty: 'ANDI WIJAYA',
  ),
  CaptureScenario(
    id: 'blu_payment_qr',
    group: 'blu by BCA',
    name: 'Pembayaran QRIS',
    packageName: 'com.bcadigital.blu',
    title: 'blu',
    body: 'Pembayaran QR di KOPI KENANGAN sebesar Rp 38.000 berhasil',
    expectedParsed: true,
    expectedKind: TxKind.payment,
    expectedDirection: Direction.outgoing,
    expectedAmount: 38000,
  ),
  CaptureScenario(
    id: 'blu_topup_wallet',
    group: 'blu by BCA',
    name: 'Top Up E-Wallet',
    packageName: 'com.bcadigital.blu',
    title: 'blu by BCA',
    body: 'Top up GoPay sebesar Rp 100.000 berhasil.',
    expectedParsed: true,
    expectedKind: TxKind.topup,
    expectedDirection: Direction.outgoing,
    expectedAmount: 100000,
  ),

  // --- Bank Nagari / Ollin ---
  CaptureScenario(
    id: 'nagari_kredit_masuk',
    group: 'Bank Nagari / Ollin',
    name: 'Kredit Masuk (Payroll/Transfer)',
    packageName: 'id.co.banknagari.ollin',
    title: 'Ollin Bank Nagari',
    body: 'Kredit masuk sebesar Rp 3.500.000 dari PT MAKMUR JAYA.',
    expectedParsed: true,
    expectedKind: TxKind.transfer,
    expectedDirection: Direction.incoming,
    expectedAmount: 3500000,
    expectedCounterparty: 'PT MAKMUR JAYA',
  ),
  CaptureScenario(
    id: 'nagari_debit_keluar',
    group: 'Bank Nagari / Ollin',
    name: 'Debit Keluar (Transfer)',
    packageName: 'id.co.banknagari.ollin',
    title: 'Ollin Bank Nagari',
    body: 'Debit sebesar Rp 120.000 a.n. RAHMAD HIDAYAT berhasil diproses.',
    expectedParsed: true,
    expectedKind: TxKind.transfer,
    expectedDirection: Direction.outgoing,
    expectedAmount: 120000,
    expectedCounterparty: 'RAHMAD HIDAYAT',
  ),
  CaptureScenario(
    id: 'nagari_qris',
    group: 'Bank Nagari / Ollin',
    name: 'Pembayaran QRIS Merchant',
    packageName: 'id.co.banknagari.ollin',
    title: 'Ollin Bank Nagari',
    body: 'Pembayaran QRIS sebesar Rp 45.000 di RM PADANG SEDERHANA berhasil.',
    expectedParsed: true,
    expectedKind: TxKind.payment,
    expectedDirection: Direction.outgoing,
    expectedAmount: 45000,
  ),
  CaptureScenario(
    id: 'nagari_topup',
    group: 'Bank Nagari / Ollin',
    name: 'Top Up Saldo E-Wallet',
    packageName: 'id.co.banknagari.ollin',
    title: 'Ollin Bank Nagari',
    body: 'Top up ShopeePay sebesar Rp 200.000 sukses.',
    expectedParsed: true,
    expectedKind: TxKind.topup,
    expectedDirection: Direction.outgoing,
    expectedAmount: 200000,
  ),

  // --- Format & Variasi Nominal (Edge Cases) ---
  CaptureScenario(
    id: 'format_decimal_comma',
    group: 'Variasi Format & Nominal',
    name: 'Nominal Desimal Koma (,00)',
    packageName: 'com.bcadigital.blu',
    title: 'blu by BCA',
    body: 'Pembayaran tagihan sebesar Rp 125.500,00 berhasil',
    expectedParsed: true,
    expectedKind: TxKind.payment,
    expectedDirection: Direction.outgoing,
    expectedAmount: 125500,
  ),
  CaptureScenario(
    id: 'format_idr',
    group: 'Variasi Format & Nominal',
    name: 'Simbol IDR',
    packageName: 'com.bcadigital.blu',
    title: 'blu',
    body: 'Transfer masuk dari HENDRA IDR 500.000 berhasil.',
    expectedParsed: true,
    expectedKind: TxKind.transfer,
    expectedDirection: Direction.incoming,
    expectedAmount: 500000,
    expectedCounterparty: 'HENDRA',
  ),
  CaptureScenario(
    id: 'format_no_space',
    group: 'Variasi Format & Nominal',
    name: 'Rp Tanpa Spasi (Rp85.000)',
    packageName: 'id.co.banknagari.ollin',
    title: 'Ollin Bank Nagari',
    body: 'Pembayaran QRIS Rp85.000 berhasil diproses.',
    expectedParsed: true,
    expectedKind: TxKind.payment,
    expectedDirection: Direction.outgoing,
    expectedAmount: 85000,
  ),

  // --- Guard Non-Finansial (Negatif) ---
  CaptureScenario(
    id: 'negative_otp',
    group: 'Guard Non-Finansial',
    name: 'Kode OTP Rahasia',
    packageName: 'com.bcadigital.blu',
    title: 'blu by BCA',
    body: 'JANGAN BERIKAN KODE OTP 948210 kepada siapa pun termasuk pihak bank.',
    expectedParsed: false,
    isNegative: true,
  ),
  CaptureScenario(
    id: 'negative_promo',
    group: 'Guard Non-Finansial',
    name: 'Iklan / Promo Cashback',
    packageName: 'com.bcadigital.blu',
    title: 'blu by BCA',
    body: 'Dapatkan cashback belanja hingga 50% untuk transaksi di merchant favoritmu!',
    expectedParsed: false,
    isNegative: true,
  ),
];

/// Utilitas simulator untuk mengevaluasi dan menguji notifikasi.
class NotificationSimulator {
  static const _settingKeyDraftIds = 'simulated_draft_ids';

  /// Evaluasi satu notifikasi secara instan (Dry-Run) tanpa menyentuh DB.
  static SimulationEvaluation evaluate({
    required RuleEngine engine,
    required String packageName,
    required String title,
    required String body,
    CaptureScenario? scenario,
  }) {
    // 1. Coba parse lewat rule engine
    final draft = engine.parse(
      packageName: packageName,
      title: title,
      body: body,
    );

    if (draft != null) {
      final bank = engine.ruleSet.bank(draft.bankId);
      final bankName = bank?.displayName ?? draft.bankId;

      // Cek apakah ekspektasi skenario terpenuhi
      var passed = true;
      final failures = <String>[];

      if (scenario != null) {
        if (!scenario.expectedParsed) {
          passed = false;
          failures.add('Seharusnya diabaikan (bukan transaksi)');
        }
        if (scenario.expectedAmount != null &&
            draft.amount != scenario.expectedAmount) {
          passed = false;
          failures.add('Nominal beda: dapat ${draft.amount}, ingin ${scenario.expectedAmount}');
        }
        if (scenario.expectedDirection != null &&
            draft.direction != scenario.expectedDirection) {
          passed = false;
          failures.add('Arah beda: dapat ${draft.direction.name}, ingin ${scenario.expectedDirection!.name}');
        }
        if (scenario.expectedKind != null && draft.kind != scenario.expectedKind) {
          passed = false;
          failures.add('Jenis beda: dapat ${draft.kind.name}, ingin ${scenario.expectedKind!.name}');
        }
      }

      return SimulationEvaluation(
        scenario: scenario,
        packageName: packageName,
        title: title,
        body: body,
        parsed: true,
        bankId: draft.bankId,
        bankName: bankName,
        templateName: draft.ruleName,
        amount: draft.amount,
        direction: draft.direction,
        kind: draft.kind,
        counterparty: draft.counterparty,
        isFallbackGuess: false,
        passedExpectation: passed,
        message: passed
            ? 'Berhasil dikenali oleh rule "${draft.ruleName}" ($bankName)'
            : 'Mismatched: ${failures.join(", ")}',
      );
    }

    // 2. Jika tidak cocok rule, uji fallback guess
    final guess = engine.guess(title, body);
    final hasGuess = guess.amount != null && guess.amount! > 0;

    if (hasGuess) {
      final isNeg = scenario?.isNegative ?? false;
      final passed = !isNeg;
      return SimulationEvaluation(
        scenario: scenario,
        packageName: packageName,
        title: title,
        body: body,
        parsed: false,
        bankId: 'unknown',
        bankName: 'Mode Tebak (Fallback)',
        amount: guess.amount,
        direction: guess.direction,
        kind: TxKind.transfer,
        isFallbackGuess: true,
        passedExpectation: passed,
        message: passed
            ? 'Format belum ada di rule, tertangkap oleh tebakan cerdas (Rp ${guess.amount})'
            : 'Peringatan: Notifikasi non-finansial mendeteksi angka Rp ${guess.amount}',
      );
    }

    // 3. Tidak ada angka / format tidak dikenal
    final expectedUnparsed = scenario != null && !scenario.expectedParsed;
    return SimulationEvaluation(
      scenario: scenario,
      packageName: packageName,
      title: title,
      body: body,
      parsed: false,
      isFallbackGuess: false,
      passedExpectation: expectedUnparsed,
      message: expectedUnparsed
          ? 'Tepat diabaikan (bukan transaksi finansial)'
          : 'Gagal parse: pola kata kunci atau format nominal tidak dikenali',
    );
  }

  /// Jalankan seluruh skenario preset sekaligus dan laporkan ringkasannya.
  static BatchSimulationReport runBatch({
    required RuleEngine engine,
    List<CaptureScenario> scenarios = kSimulatorPresets,
  }) {
    final evaluations = <SimulationEvaluation>[];
    var passed = 0;
    var failed = 0;

    for (final s in scenarios) {
      final eval = evaluate(
        engine: engine,
        packageName: s.packageName,
        title: s.title,
        body: s.body,
        scenario: s,
      );
      evaluations.add(eval);
      if (eval.passedExpectation) {
        passed++;
      } else {
        failed++;
      }
    }

    return BatchSimulationReport(
      total: scenarios.length,
      passed: passed,
      failed: failed,
      evaluations: evaluations,
    );
  }

  /// Dorong satu notifikasi ke pipeline nyata (End-to-End).
  ///
  /// Mengembalikan ID draf yang baru dibuat jika berhasil.
  static Future<int?> injectEndToEnd({
    required CapturePipeline pipeline,
    required LedgerRepository repository,
    required String packageName,
    required String title,
    required String body,
    DateTime? postedAt,
  }) async {
    final now = postedAt ?? DateTime.now();
    final raw = RawCapture(
      packageName: packageName,
      title: title,
      body: body,
      postedAt: now,
    );

    // Ambil daftar draf sebelum injeksi untuk melacak id yang baru dibuat
    final initialDrafts = await repository.watchDrafts().first;
    final initialIds = {for (final d in initialDrafts) d.id};

    pipeline.submit(raw);
    await pipeline.flush();

    final afterDrafts = await repository.watchDrafts().first;
    int? createdDraftId;
    for (final d in afterDrafts) {
      if (!initialIds.contains(d.id)) {
        createdDraftId = d.id;
        break;
      }
    }

    if (createdDraftId != null) {
      await _trackSimulatedDraftId(repository, createdDraftId);
    }

    return createdDraftId;
  }

  static Future<void> _trackSimulatedDraftId(
    LedgerRepository repository,
    int id,
  ) async {
    final raw = await repository.getSetting(_settingKeyDraftIds);
    final set = (raw ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    set.add(id.toString());
    await repository.setSetting(_settingKeyDraftIds, set.join(','));
  }

  /// Ambil jumlah draf simulasi yang saat ini tersimpan di antrean.
  static Future<int> countTrackedDrafts(LedgerRepository repository) async {
    final raw = await repository.getSetting(_settingKeyDraftIds);
    if (raw == null || raw.trim().isEmpty) return 0;
    final ids = raw
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toSet();
    if (ids.isEmpty) return 0;
    final current = await repository.watchDrafts().first;
    return current.where((d) => ids.contains(d.id)).length;
  }

  /// Bersihkan seluruh draf dan data uji coba hasil simulasi.
  static Future<int> cleanupSimulatedData(LedgerRepository repository) async {
    final raw = await repository.getSetting(_settingKeyDraftIds);
    if (raw == null || raw.trim().isEmpty) return 0;

    final ids = raw
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
    if (ids.isEmpty) return 0;

    final deleted = await repository.discardDrafts(ids);
    await repository.setSetting(_settingKeyDraftIds, '');
    return deleted;
  }
}
