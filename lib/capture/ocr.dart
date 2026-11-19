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
    this.occurredAt,
    this.candidateAmounts = const [],
    this.suggestedCategory,
    this.suggestedPaymentMethod,
  });

  final String rawText;
  final String merchant;
  final int? amount;
  final Direction direction;
  final DateTime? occurredAt;
  final List<int> candidateAmounts;
  final String? suggestedCategory;
  final String? suggestedPaymentMethod;
}

/// Service OCR on-device (tanpa internet) untuk mengenali teks dari struk/bukti transaksi.
class OcrService {
  const OcrService();

  // Pola dikompilasi sekali — dulu ±150–200 kompilasi RegExp per nota
  // di main isolate.
  static final _datePrefix = RegExp(r'^\d{1,2}[./\-]\d{1,2}[./\-]\d{2,4}');
  static final _timePrefix = RegExp(r'^\d{2}:\d{2}');
  static final _digitsOnly = RegExp(r'^\d+$');
  static final _rpAmount = RegExp(r'[Rr][Pp]\.?\s*([\d][\d.,]*)');
  static final _groupedAmount = RegExp(
    r'\b(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?)\b',
  );
  static final _fullDate = RegExp(
    r'\b(\d{1,2})[./\-](\d{1,2})[./\-](\d{2,4})\b',
  );
  static final _fullTime = RegExp(r'\b(\d{1,2}):(\d{2})(?::(\d{2}))?\b');

  /// Jalankan OCR pada file gambar di [imagePath].
  Future<OcrReceiptData?> processImage(
    String imagePath, {
    RuleEngine? engine,
  }) async {
    final file = File(imagePath);
    if (!file.existsSync()) return null;

    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer();

    try {
      final recognized = await textRecognizer.processImage(inputImage);
      final rawText = recognized.text.trim();
      if (rawText.isEmpty) return null;

      return parseReceiptText(rawText, engine: engine);
    } catch (e, st) {
      debugPrint('OCR error: $e\n$st');
      rethrow;
    } finally {
      await textRecognizer.close();
    }
  }

  /// Ekstraksi cerdas data struk: nama toko/merchant, nominal total, tanggal, arah, dan kategori.
  static OcrReceiptData parseReceiptText(String rawText, {RuleEngine? engine}) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final merchant = _extractMerchant(lines);
    final (amount, candidates) = _extractAmountsAndCandidates(
      lines,
      rawText,
      engine,
    );
    final direction = _extractDirection(rawText);
    final occurredAt = _extractDate(lines, rawText);
    final suggestedCategory = _suggestCategory(merchant, rawText);
    final suggestedPaymentMethod = _suggestPaymentMethod(rawText);

    return OcrReceiptData(
      rawText: rawText,
      merchant: merchant,
      amount: amount,
      direction: direction,
      occurredAt: occurredAt,
      candidateAmounts: candidates,
      suggestedCategory: suggestedCategory,
      suggestedPaymentMethod: suggestedPaymentMethod,
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
      'pos',
      'order',
    ];

    for (final line in lines.take(6)) {
      final lower = line.toLowerCase();
      // Lewati baris berisi tanggal/waktu saja atau kata umum nota
      if (_datePrefix.hasMatch(line)) {
        continue;
      }
      if (_timePrefix.hasMatch(line)) {
        continue;
      }
      if (ignoreWords.any((w) => lower == w || lower.startsWith('$w '))) {
        continue;
      }
      // Ambil baris pertama yang bermakna sebagai nama toko
      if (line.length >= 3 && !_digitsOnly.hasMatch(line)) {
        return line;
      }
    }
    return lines.isNotEmpty ? lines.first : 'Struk / Nota';
  }

  static (int?, List<int>) _extractAmountsAndCandidates(
    List<String> lines,
    String fullText,
    RuleEngine? engine,
  ) {
    final candidates = <int>{};

    // Kumpulkan semua angka rupiah yang valid dari seluruh baris
    for (final line in lines) {
      final amounts = _findAllAmountsInLine(line);
      for (final a in amounts) {
        if (a >= 100 && a <= 1000000000) {
          candidates.add(a);
        }
      }
    }

    // Kata kunci total — urut = prioritas. Baris dipilih berdasarkan kata
    // kunci BERPRIORITAS TERTINGGI yang muncul di struk, bukan baris
    // teratas: struk umumnya menulis SUBTOTAL (sebelum diskon) lebih dulu,
    // dan 'subtotal' mengandung substring 'total', sehingga kecocokan
    // substring polos baris-per-baris selalu memilih subtotal.
    const totalKeywords = [
      'grand total',
      'total akhir',
      'total tagihan',
      'total bayar',
      'total belanja',
      'total',
      'subtotal',
      'jumlah bayar',
      'jumlah akhir',
      'jumlah',
      'netto',
    ];

    // Kata kunci non-total (pembayaran tunai & kembalian)
    const excludeKeywords = [
      'kembali',
      'kembalian',
      'change',
      'tunai',
      'cash',
      'bayar tunai',
      'uang muka',
      'dp',
      'diskon',
      'potongan',
      'ppn',
      'pajak',
    ];

    int? totalAmount;

    // 1. Baris total terbaik: peringkat kata kuncinya tertinggi (paling
    //    kecil indeksnya) di antara semua baris yang tidak terexclude.
    int bestLine = -1;
    int? bestRank;
    for (var i = 0; i < lines.length; i++) {
      final lineLower = lines[i].toLowerCase();

      final isExcluded = excludeKeywords.any((kw) {
        // Pengecualian khusus: 'total bayar tunai' tetap dihitung jika tidak ada kata 'kembali'
        if (kw == 'tunai' || kw == 'cash') {
          return lineLower.contains('kembali') || lineLower.contains('change');
        }
        return lineLower.contains(kw);
      });
      if (isExcluded) continue;

      final rank = _totalKeywordRank(lineLower, totalKeywords);
      if (rank == null) continue;
      if (bestRank == null || rank < bestRank) {
        bestRank = rank;
        bestLine = i;
        if (rank == 0) break; // 'grand total' tak terkalahkan
      }
    }

    if (bestLine >= 0) {
      // Ambil nominal di baris yang sama
      final parsed = _findAmountInLine(lines[bestLine]);
      if (parsed != null && parsed > 0) {
        totalAmount = parsed;
      } else if (bestLine + 1 < lines.length) {
        // Atau di baris tepat setelahnya
        final nextParsed = _findAmountInLine(lines[bestLine + 1]);
        if (nextParsed != null && nextParsed > 0) {
          totalAmount = nextParsed;
        }
      }
    }

    // 2. Fallback: engine.guess jika belum ketemu
    if (totalAmount == null && engine != null) {
      final guess = engine.guess('Struk', fullText);
      if (guess.amount != null && guess.amount! > 0) {
        totalAmount = guess.amount;
      }
    }

    // 3. Fallback: cari nominal terbesar di baris yang BUKAN tunai/kembali
    if (totalAmount == null) {
      int? maxSafeAmount;
      for (final line in lines) {
        final lower = line.toLowerCase();
        if (excludeKeywords.any(lower.contains)) continue;
        final amt = _findAmountInLine(line);
        if (amt != null && amt >= 100 && amt <= 1000000000) {
          if (maxSafeAmount == null || amt > maxSafeAmount) {
            maxSafeAmount = amt;
          }
        }
      }
      totalAmount = maxSafeAmount;
    }

    // Urutkan kandidat angka (nominal total diletakkan di depan)
    final candidateList = candidates.toList();
    if (totalAmount != null && candidateList.contains(totalAmount)) {
      candidateList.remove(totalAmount);
      candidateList.insert(0, totalAmount);
    }

    return (totalAmount, candidateList);
  }

  /// Peringkat kata kunci total terbaik pada satu baris; null = bukan
  /// baris total. 'total' sengaja tidak menangkap baris yang memuat
  /// 'subtotal' — baris itu berperingkat lebih rendah dan harus kalah
  /// dari TOTAL sungguhan di bawahnya.
  static int? _totalKeywordRank(String lowerLine, List<String> totalKeywords) {
    for (var i = 0; i < totalKeywords.length; i++) {
      final kw = totalKeywords[i];
      if (kw == 'total' && lowerLine.contains('subtotal')) continue;
      if (lowerLine.contains(kw)) return i;
    }
    return null;
  }

  static List<int> _findAllAmountsInLine(String line) {
    final result = <int>[];
    final rpMatches = _rpAmount.allMatches(line);
    for (final m in rpMatches) {
      final g = m.group(1);
      final val = Money.tryParseGroup(g);
      if (val != null && val > 0) result.add(val);
    }

    final numMatches = _groupedAmount.allMatches(line);
    for (final m in numMatches) {
      final g = m.group(1);
      final val = Money.tryParseGroup(g);
      if (val != null && val > 0) result.add(val);
    }
    return result;
  }

  static int? _findAmountInLine(String line) {
    final list = _findAllAmountsInLine(line);
    return list.isNotEmpty ? list.last : null;
  }

  static Direction _extractDirection(String text) {
    final lower = text.toLowerCase();
    const inWords = [
      'transfer masuk',
      'dana masuk',
      'uang masuk',
      'penerima:',
      'kamu menerima',
      'berhasil diterima',
      'setoran',
      'kredit',
    ];
    // 'kredit' saja ambigu: bukti pembayaran KARTU KREDIT juga memuatnya.
    // Masuk hanya bila ada sinyal masuk DAN tidak ada sinyal keluar —
    // guard yang sama dengan RuleEngine.guess.
    const outWords = [
      'pembayaran',
      'membayar',
      'bayar',
      'tagihan',
      'debit',
      'transfer ke',
      'qris',
      'belanja',
      'tarik tunai',
    ];
    final isIn = inWords.any(lower.contains);
    final isOut = outWords.any(lower.contains);
    return isIn && !isOut ? Direction.incoming : Direction.outgoing;
  }

  static DateTime? _extractDate(List<String> lines, String fullText) {
    // 1. Format tanggal standar: DD/MM/YYYY, DD.MM.YYYY, DD-MM-YYYY, DD/MM/YY
    final dateReg = _fullDate;
    final timeReg = _fullTime;

    DateTime? parsedDate;
    int hour = 0;
    int minute = 0;

    for (final line in lines) {
      if (parsedDate == null) {
        final dMatch = dateReg.firstMatch(line);
        if (dMatch != null) {
          final day = int.tryParse(dMatch.group(1) ?? '') ?? 1;
          final month = int.tryParse(dMatch.group(2) ?? '') ?? 1;
          var year = int.tryParse(dMatch.group(3) ?? '') ?? 2026;
          if (year < 100) year += 2000;

          if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            parsedDate = DateTime(year, month, day);
          }
        }
      }

      final tMatch = timeReg.firstMatch(line);
      if (tMatch != null) {
        hour = int.tryParse(tMatch.group(1) ?? '') ?? 0;
        minute = int.tryParse(tMatch.group(2) ?? '') ?? 0;
      }

      if (parsedDate != null && tMatch != null) break;
    }

    if (parsedDate != null) {
      return DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
        hour.clamp(0, 23),
        minute.clamp(0, 59),
      );
    }
    return null;
  }

  static String? _suggestCategory(String merchant, String fullText) {
    // 1. Prioritas: Cocokkan dari nama merchant/toko
    final mCat = _matchCategory(merchant.toLowerCase());
    if (mCat != null) return mCat;

    // 2. Fallback: Cocokkan dari seluruh teks struk
    return _matchCategory(fullText.toLowerCase());
  }

  static String? _matchCategory(String text) {
    // Belanja / Minimarket
    if (const [
      'indomaret',
      'indomar',
      'alfamart',
      'alfamidi',
      'supermarket',
      'hypermart',
      'transmart',
      'yogya',
      'minimarket',
      'swalayan',
      'mart',
      'toko',
      'grocery',
      'pasar',
    ].any(text.contains)) {
      return 'Belanja';
    }

    // Makanan & Minuman
    if (const [
      'kopi',
      'coffee',
      'cafe',
      'kafe',
      'resto',
      'restaurant',
      'bakso',
      'mie',
      'geprek',
      'warung',
      'mcd',
      'kfc',
      'burger',
      'rotio',
      'roti',
      'jco',
      'dapur',
      'kitchen',
      'food',
      'makan',
      'bento',
      'sushi',
      'pizza',
      'es teh',
      'haus',
      'janji jiwa',
      'kenangan',
    ].any(text.contains)) {
      return 'Makanan';
    }

    // Transportasi & Bensin
    if (const [
      'spbu',
      'pertamina',
      'shell',
      'bp ',
      'bensin',
      'solar',
      'parkir',
      'parking',
      'grab',
      'gojek',
      'toll',
      'tol',
      'tiket',
      'kereta',
      'kai',
      'flight',
    ].any(text.contains)) {
      return 'Transportasi';
    }

    // Kesehatan & Obat
    if (const [
      'apotek',
      'pharmacy',
      'kimia farma',
      'k-24',
      'klinik',
      'clinic',
      'rs',
      'rumah sakit',
      'guardian',
      'watsons',
      'obat',
      'dokter',
      'optik',
    ].any(text.contains)) {
      return 'Kesehatan';
    }

    // Tagihan & Utilitas
    if (const [
      'pln',
      'pdam',
      'telkom',
      'indihome',
      'wifi',
      'pulsa',
      'bpjs',
      'listrik',
      'air',
    ].any(text.contains)) {
      return 'Tagihan';
    }

    // Hiburan
    if (const [
      'bioskop',
      'cinema',
      'xxi',
      'cgv',
      'cinepolis',
      'timezone',
      'game',
      'karaoke',
    ].any(text.contains)) {
      return 'Hiburan';
    }

    return null;
  }

  static String? _suggestPaymentMethod(String fullText) {
    final lower = fullText.toLowerCase();
    if (lower.contains('qris')) return 'QRIS';
    if (lower.contains('blu') || lower.contains('bca')) return 'blu by BCA';
    if (lower.contains('nagari') || lower.contains('ollin')) {
      return 'Bank Nagari';
    }
    if (lower.contains('tunai') || lower.contains('cash')) return 'Tunai';
    return null;
  }
}
