# ADR-001: Native hanya transport, logika di Dart

## Status

Diterima (2026-10-10, sejak commit awal).

## Konteks

Capture otomatis butuh `NotificationListenerService` — harus Kotlin.
Logika parse bisa jalan di Kotlin (akses langsung API Android) atau di
Dart (lewat channel).

## Keputusan

Kotlin (`NotificationCatcher`) hanya: baca notifikasi → JSON mentah →
tulis antrian file (`capture_queue.jsonl`) → kirim via EventChannel.
Seluruh logika — filter, parse, dedup, simpan — di Dart
(`CapturePipeline` + `RuleEngine`).

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
