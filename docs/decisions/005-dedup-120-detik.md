# ADR-005: Dedup push ganda ±120 detik

## Status

Diterima (2026-10-10, sejak repository pertama).

## Konteks

Bank/e-wallet sering mengirim notifikasi ganda untuk satu transaksi:
push + SMS, atau resend. Tanpa dedup, satu pembelian bisa tercatat dua
kali dan meracuni semua agregat.

## Keputusan

`recordFromCapture` menolak transaksi baru bila sudah ada transaksi
dengan bank + nominal + arah sama dalam jendela ±120 detik. Arah
berbeda dengan nominal sama **tidak** didedup (transfer ke diri sendiri
menghasilkan dua transaksi sah).

## Alternatif yang ditolak

Dedup by ID notifikasi: tidak reliabel — format ID berbeda antar bank
dan antar jalur (push vs SMS).

## Konsekuensi

- Diterima: dua transaksi sah beruntun, nominal sama, arah sama, dalam
  <2 menit bisa tenggelam satu. Kasusnya jarang; risiko duplikat lebih
  buruk daripada risiko hilang satu.
- Jendela dan kunci dedup hidup di repository (bukan engine) karena
  butuh query histori.
