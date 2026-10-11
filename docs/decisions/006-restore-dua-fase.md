# ADR-006: Restore dua-fase via staging + marker + restart

## Status

Diterima (2026-10-11, bersama layar Backup).

## Konteks

SQLCipher mengunci file database selama app berjalan; menimpanya saat
dibuka akan korup atau gagal. Restore harus terjadi sebelum database
dibuka — tetapi pemilih file hanya ada di dalam app yang sudah jalan.

## Keputusan

1. Restore menyalin file pilihan user ke `restore_staging.sqlite` +
   menulis marker `restore_pending` di `app_settings`.
2. App diminta keluar (`SystemNavigator.pop`).
3. Saat bootstrap berikutnya, `main.dart` cek marker →
   `applyPendingRestore` mengganti database sebelum dibuka.

## Alternatif yang ditolak

`ATTACH` + copy SQL saat app berjalan: bisa berhenti setengah jalan
saat crash, menyisakan DB campuran.

## Konsekuensi

- Restore selalu butuh satu restart — diterima, operasi langka.
- Staging diverifikasi utuh sebelum menggantikan DB lama; DB lama tidak
  disentuh sampai tahap akhir.
- Marker di settings membuat restore tahan terhadap app dimatikan paksa
  di tengah jalan.
