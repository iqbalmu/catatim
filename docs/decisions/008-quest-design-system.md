# ADR-008: Design system Quest sendiri, tanpa state library

## Status

Diterima (2026-10-11).

## Konteks

Identitas visual board-game (maskot, streak, kartu tebal bergaya
papan permainan) tidak bisa dicapai dengan Material default tanpa
menimpa hampir semua komponennya. Sementara itu state app: daftar
transaksi reaktif + satu ringkasan kondisi.

## Keputusan

- `QuestSchemes.light()/dark()` + widget kit `lib/ui/quest.dart`
  (±845 baris: QuestCard, QuestButton, QuestBottomNav, sheet/dialog/
  snack, dst.) adalah **satu-satunya** tempat gaya didefinisikan.
  `MaterialApp` dipakai hanya sebagai host (locale, routing push).
- Tanpa Provider/Riverpod/BLoC: state = drift streams (per layar) +
  satu `ProgressService extends ChangeNotifier` (kondisi game),
  diteruskan lewat konstruktor dari `main.dart`.

## Alternatif yang ditolak

Material theming penuh: hasil setengah jalan, konflik dengan identitas.
State library: tidak ada masalah yang dia selesaikan pada skala satu
ChangeNotifier + streams.

## Konsekuensi

- Komponen visual baru wajib masuk `quest.dart`, bukan di-inline di
  layar — menjaga konsistensi dan tempat refactor tunggal.
- Menambah layar murah (push + stream); bila kompleksitas state tumbuh
  (mis. banyak service saling tergantung), keputusan ini ditinjau ulang
  — bukan sekarang.
