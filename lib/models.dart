import 'dart:convert';
import 'dart:math';

/// Arah pergerakan uang.
enum Direction { incoming, outgoing }

/// Sumber pencatatan transaksi.
/// notification = draf notifikasi yang dikonfirmasi user; auto = dicatat
/// otomatis tanpa konfirmasi. Disimpan sebagai teks (nama), tanpa migrasi.
enum TxSource { notification, manual, import, auto }

/// Jenis transaksi.
/// transfer = kirim ke pihak lain (dihitung pengeluaran/pemasukan).
/// internal = pindah dana antar akun sendiri. topup dan withdrawal juga
/// perpindahan dana milik sendiri. Ketiganya tidak masuk arus kas.
enum TxKind { transfer, payment, topup, withdrawal, other, internal }

/// Jenis akun/dompet.
enum AccountKind { bank, ewallet, cash }

/// Arah bon: dipinjamkan (piutang) atau dipinjam (utang).
enum BonDirection { lent, borrowed }

extension TxKindLabel on TxKind {
  String get label => switch (this) {
    TxKind.transfer => 'Transfer',
    TxKind.payment => 'Pembayaran',
    TxKind.topup => 'Top up',
    TxKind.withdrawal => 'Tarik tunai',
    TxKind.other => 'Lainnya',
    TxKind.internal => 'Antar akun',
  };

  /// Perpindahan dana milik sendiri: dikecualikan dari arus kas dan belanja.
  bool get isInternalMove =>
      this == TxKind.internal ||
      this == TxKind.topup ||
      this == TxKind.withdrawal;
}

extension DirectionLabel on Direction {
  String get label => switch (this) {
    Direction.incoming => 'Masuk',
    Direction.outgoing => 'Keluar',
  };
}

extension TxSourceLabel on TxSource {
  String get label => switch (this) {
    TxSource.notification => 'Dikonfirmasi',
    TxSource.auto => 'Otomatis',
    TxSource.manual => 'Manual',
    TxSource.import => 'Impor',
  };
}

extension AccountKindLabel on AccountKind {
  String get label => switch (this) {
    AccountKind.bank => 'Bank',
    AccountKind.ewallet => 'E-wallet',
    AccountKind.cash => 'Tunai',
  };
}

extension BonDirectionLabel on BonDirection {
  String get label => switch (this) {
    BonDirection.lent => 'Dipinjamkan',
    BonDirection.borrowed => 'Dipinjam',
  };
}

/// Hasil parsing notifikasi menjadi draf transaksi (belum tersimpan).
class ParsedDraft {
  const ParsedDraft({
    required this.bankId,
    required this.bankName,
    required this.ruleName,
    required this.kind,
    required this.direction,
    required this.amount,
    this.counterparty,
  });

  final String bankId;
  final String bankName;
  final String ruleName;
  final TxKind kind;
  final Direction direction;
  final int amount;
  final String? counterparty;
}

/// Pola pesan notifikasi yang diabaikan permanen oleh pengguna.
class IgnoredPattern {
  const IgnoredPattern({
    required this.id,
    required this.pattern,
    required this.label,
    this.bankId,
    required this.createdAt,
  });

  final String id;
  final String pattern;
  final String label;
  final String? bankId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'pattern': pattern,
    'label': label,
    if (bankId != null) 'bankId': bankId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory IgnoredPattern.fromJson(Map<String, dynamic> json) => IgnoredPattern(
    id: json['id'] as String,
    pattern: (json['pattern'] as String).toLowerCase(),
    label: json['label'] as String? ?? json['pattern'] as String,
    bankId: json['bankId'] as String?,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Notifikasi mentah yang ditangkap dari lapisan native.
class RawCapture {
  const RawCapture({
    required this.packageName,
    required this.title,
    required this.body,
    required this.postedAt,
  });

  final String packageName;
  final String title;
  final String body;
  final DateTime postedAt;

  factory RawCapture.fromLine(String line) {
    final json = jsonDecode(line) as Map<String, dynamic>;
    final postedMs = (json['postedAt'] as num?)?.toInt();
    return RawCapture(
      packageName: json['packageName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      postedAt: postedMs == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(postedMs),
    );
  }
}

/// UUID v4 sederhana untuk identitas baris transaksi.
String newUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
