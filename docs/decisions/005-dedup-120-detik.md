# ADR-005: Dedup push ganda ±120 detik

## Status

Diterima (2026-10-10, sejak repository pertama).

## Konteks

Bank/e-wallet sering mengirim notifikasi ganda untuk satu transaksi:
push + SMS, atau resend. Tanpa dedup, satu pembelian bisa tercatat dua
kali dan meracuni semua agregat.

## Keputusan

`addDraftFromCapture` menolak membuat draf baru bila sudah ada draf /
transaksi dengan bank + nominal + arah sama dalam jendela ±120 detik.
Arah berbeda dengan nominal sama **tidak** didedup (transfer ke diri
sendiri menghasilkan dua transaksi sah). Cek-then-insert berjalan dalam
transaksi DB dan pipeline memproses notifikasi bergiliran — dua notifikasi
yang tiba nyaris bersamaan tidak bisa lolos dua-duanya.

## Alternatif yang ditolak

Dedup by ID notifikasi: tidak reliabel — format ID berbeda antar bank
dan antar jalur (push vs SMS).

## Konsekuensi

- Diterima: dua transaksi sah beruntun, nominal sama, arah sama, dalam
  <2 menit bisa tenggelam satu — tetapi **tidak lagi senyap**: yang
  digugurkan tercatat di `capture_logs` (`ignored_dup`) dan tampil di
  Diagnostik untuk dicatat manual bila memang transaksi berbeda.
- Jendela dan kunci dedup hidup di repository (bukan engine) karena
  butuh query histori.
