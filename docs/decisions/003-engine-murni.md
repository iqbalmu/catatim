# ADR-003: Engine murni tanpa dependensi drift/Flutter

## Status

Diterima (2026-10-11, sejak mesin anggaran dibangun).

## Konteks

Logika keuangan (format uang, bucket tren, penilaian batas anggaran)
dan logika parse paling sering berubah dan paling sering salah.
Menaruhnya di widget atau repository membuat test butuh device dan
membuat refactor UI berisiko menyentuh logika uang.

## Keputusan

`lib/core/` (money, buckets, budget, dates_id) dan `lib/rules/` adalah
Dart murni — tanpa import drift/Flutter. Storage dan UI memakainya;
keduanya tidak boleh berisi logika keuangan.

## Alternatif yang ditolak

Logika di repository/widget: cepat ditulis, mahal diuji, mahal
direfactor.

## Konsekuensi

- Mayoritas dari 74 test jalan dalam hitungan detik tanpa emulator.
- Aturan perilaku terdokumentasi sebagai test (warning 75%, over 100%,
  tren ±5% datar, streak mundur dari kemarin, dst.).
- Konversi tipe di batas lapisan (int rupiah ↔ tampilan) menjadi
  tanggung jawab UI — sudah diseragamkan lewat `Money`.
