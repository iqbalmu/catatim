# ADR-007: Gamifikasi = cermin kondisi nyata; XP/level dihapus

## Status

Diterima (2026-10-11). XP/level ditambah lalu dihapus di hari yang
sama; bar anggaran menggantikannya.

## Konteks

App butuh pemicu kebiasaan mencatat. Pendekatan umum: poin/XP/level.
Risikonya: reward terlepas dari realita keuangan — user "menang" padahal
anggarannya hancur.

## Keputusan

Semua umpan balik game adalah fungsi dari kondisi nyata:

- **Mood maskot** = fungsi murni `BudgetSnapshot` + perilaku mencatat:
  over → khawatir, warning → waspada, ok + catat hari ini → senang,
  tanpa data → idle, streak 0 belum catat → mengantuk, pulih dari over
  → celebrate.
- **Streak** dihitung ulang dari data transaksi asli setiap refresh —
  bukan counter tersimpan; tidak bisa drift, tidak bisa di-cheat.
  Milestone {3,7,14,21,30,60,100} dirayakan sekali.
- **Alert realtime**: garis batas naik level (ok→warning→over) memicu
  snack + haptic; kembali dalam batas memicu pesan pemulihan.
- **XP/level**: dihapus. Bar anggaran bulanan + chip tren menggantikan
  slotnya di hero card.

## Alternatif yang ditolak

XP per transaksi + level: mengoptimalkan engagement, bukan kesehatan
keuangan; menyamarkan realita saat realitanya buruk.

## Konsekuensi

- Tidak ada metrik game yang bisa "dipanen" tanpa data keuangan nyata.
- Mood buruk saat keuangan buruk — itu fitur, bukan bug.
- Kebiasaan yang dirayakan hanya satu: konsisten mencatat (streak);
  kualitas belanja dinilai oleh anggaran, bukan poin.
