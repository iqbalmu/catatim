import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../core/money.dart';
import '../models.dart';
import '../rules/engine.dart';

/// Hasil ekstraksi OCR dari struk/nota/bukti transaksi.
class OcrReceiptData {
  const OcrReceiptData({
    required this.rawText,
    required this.merchant,
    required this.amount,
    required this.direction,
  });

  final String rawText;
  final String merchant;
  final int? amount;
  final Direction direction;
}

/// Service OCR on-device (tanpa internet) untuk mengenali teks dari struk/bukti transaksi.
class OcrService {
  const OcrService();

  /// Jalankan OCR pada file gambar di [imagePath].
  Future<OcrReceiptData?> processImage(
    String imagePath, {
    RuleEngine? engine,
  }) async {
    final file = File(imagePath);
    if (!file.existsSync()) return null;

    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognized = await textRecognizer.processImage(inputImage);
      final rawText = recognized.text.trim();
      if (rawText.isEmpty) return null;

      return parseReceiptText(rawText, engine: engine);
    } catch (e) {
      debugPrint('OCR error: $e');
      return null;
    } finally {
      await textRecognizer.close();
    }
  }

  /// Ekstraksi cerdas data struk: nama toko/merchant, nominal total, arah transaksi.
  static OcrReceiptData parseReceiptText(String rawText, {RuleEngine? engine}) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final merchant = _extractMerchant(lines);
    final amount = _extractTotalAmount(lines, rawText, engine);
    final direction = _extractDirection(rawText);

    return OcrReceiptData(
      rawText: rawText,
      merchant: merchant,
      amount: amount,
      direction: direction,
    );
  }

  static String _extractMerchant(List<String> lines) {
    const ignoreWords = [
      'struk',
      'nota',
      'receipt',
      'invoice',
      'bukti',
      'transaksi',
      'pembayaran',
      'selamat',
      'terima kasih',
      'welcome',
      'merchant',
      'salinan',
      'customer',
      'pelanggan',
      'bill',
    ];

    for (final line in lines.take(5)) {
      final lower = line.toLowerCase();
      // Lewati baris berisi tanggal/waktu saja atau kata umum nota
      if (RegExp(r'^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}').hasMatch(line)) {
        continue;
      }
      if (RegExp(r'^\d{2}:\d{2}').hasMatch(line)) {
        continue;
      }
      if (ignoreWords.any((w) => lower == w || lower.startsWith('$w '))) {
        continue;
      }
      // Ambil baris pertama yang bermakna sebagai nama toko
      if (line.length >= 3) {
        return line;
      }
    }
    return lines.isNotEmpty ? lines.first : 'Struk / Nota';
  }

  static int? _extractTotalAmount(
    List<String> lines,
    String fullText,
    RuleEngine? engine,
  ) {
    // 1. Prioritas: baris yang memuat kata kunci total/jumlah
    const totalKeywords = [
      'grand total',
      'total akhir',
      'total bayar',
      'total belanja',
      'total tagihan',
      'total',
      'jumlah',
      'netto',
      'subtotal',
    ];

    for (var i = 0; i < lines.length; i++) {
      final lineLower = lines[i].toLowerCase();
      for (final kw in totalKeywords) {
        if (lineLower.contains(kw)) {
          // Cek nominal di baris yang sama
          final parsed = _findAmountInLine(lines[i]);
          if (parsed != null && parsed > 0) return parsed;

          // Atau di baris tepat setelahnya (sering format "TOTAL \n Rp 50.000")
          if (i + 1 < lines.length) {
            final nextParsed = _findAmountInLine(lines[i + 1]);
            if (nextParsed != null && nextParsed > 0) return nextParsed;
          }
        }
      }
    }

    // 2. Fallback: coba engine.guess
    if (engine != null) {
      final guess = engine.guess('Struk', fullText);
      if (guess.amount != null && guess.amount! > 0) return guess.amount;
    }

    // 3. Fallback: ambil angka nominal rupiah terbesar yang masuk akal
    int? maxAmount;
    for (final line in lines) {
      final amt = _findAmountInLine(line);
      if (amt != null && amt >= 100 && amt <= 1000000000) {
        if (maxAmount == null || amt > maxAmount) {
          maxAmount = amt;
        }
      }
    }
    return maxAmount;
  }

  static int? _findAmountInLine(String line) {
    // Cari pola "Rp 50.000", "50.000", "50000"
    final rpMatch = RegExp(r'[Rr][Pp]\.?\s*([\d][\d.,]*)').firstMatch(line);
    if (rpMatch != null) {
      final g = rpMatch.group(1);
      final val = Money.tryParseGroup(g);
      if (val != null && val > 0) return val;
    }

    final numMatch = RegExp(
      r'\b(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?)\b',
    ).firstMatch(line);
    if (numMatch != null) {
      final g = numMatch.group(1);
      final val = Money.tryParseGroup(g);
      if (val != null && val > 0) return val;
    }
    return null;
  }

  static Direction _extractDirection(String text) {
    final lower = text.toLowerCase();
    // Bukti transfer masuk / penerimaan
    const inWords = [
      'transfer masuk',
      'dana masuk',
      'uang masuk',
      'penerima:',
      'kamu menerima',
      'berhasil diterima',
      'kredit',
    ];
    if (inWords.any(lower.contains)) {
      return Direction.incoming;
    }
    // Struk belanja / pembayaran selalu pengeluaran
    return Direction.outgoing;
  }
}
