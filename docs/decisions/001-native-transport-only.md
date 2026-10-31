# ADR-001: Native hanya transport, logika di Dart

## Status

Diterima (2026-10-10, sejak commit awal). Amandemen 2026-10-31:
allowlist paket (lihat "Amandemen").

## Konteks

Capture otomatis butuh `NotificationListenerService` — harus Kotlin.
Logika parse bisa jalan di Kotlin (akses langsung API Android) atau di
Dart (lewat channel).

## Keputusan

Kotlin (`NotificationCatcher`) hanya: baca notifikasi → JSON mentah →
tulis antrian file (`capture_queue.jsonl`) → kirim via EventChannel.
Seluruh logika — filter, parse, dedup, simpan — di Dart
(`CapturePipeline` + `RuleEngine`).

## Amandemen (2026-10-31): allowlist paket antrean

Hasil audit keamanan (A-02): menulis SEMUA notifikasi ke
`capture_queue.jsonl` plaintext berarti OTP/chat ikut tertinggal di
disk tanpa batas waktu. Kini Dart mendorong daftar paket bank
terhubung (`CapturePipeline.syncAllowedPackages`); native hanya
menulis paket dalam daftar itu ke antrean.

Batasan amandemen — native tetap tidak MEMUTUSKAN apa pun:

- Daftar datang dari Dart; native hanya menyimpan & mencocokkan string
  (metadata paket, bukan isi notifikasi).
- Sink live (EventChannel) tetap menerima semua notifikasi agar Dart
  bisa mencocokkan keyword; ketika bank terhubung cocok lewat keyword
  tapi paketnya asing, Dart mengirim `learnBankPackage` dan native
  mencatat paket itu (bertahan di SharedPreferences) untuk antrean
  berikutnya.
- Allowlist kosong = tidak ada yang ditulis ke disk (default aman).
- Risiko: app jahat bisa memalsukan teks ber-keyword bank agar paketnya
  dipelajari — dibatasi kap antrean 1 MB/1000 baris; dampaknya junk
  di antrean, bukan kebocoran data.

## Alternatif yang ditolak

Parse di Kotlin: logika terbelah dua bahasa dan tidak bisa di-unit-test
tanpa device/emulator.

## Konsekuensi

- Rule engine, dedup, dan pipeline teruji penuh di `flutter test`
  (74 test tanpa device).
- Tuning rules cukup hot restart; entri lama bisa di-parse ulang dari
  Capture Log.
- Antrian file membuat notifikasi tetap tertangkap saat app mati dan
  di-drain saat app hidup lagi.
- Payload mentah melewati channel — sedikit lebih boros, tidak relevan
  untuk volume notifikasi personal.
