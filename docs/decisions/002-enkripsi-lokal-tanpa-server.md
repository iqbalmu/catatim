# ADR-002: Enkripsi lokal tanpa server

## Status

Diterima (2026-10-10, sejak commit awal).

## Konteks

Klaim produk: data keuangan tidak pernah meninggalkan perangkat. Klaim
itu hanya benar bila file database benar-benar terenkripsi dan tidak
ada jalur jaringan untuk data.

## Keputusan

- SQLCipher dibundel lewat hook native assets (`hooks.user_defines.
  sqlite3.source: sqlcipher` di pubspec.yaml; mekanisme `sqlite3` ≥3.x —
  `sqlcipher_flutter_libs` lama sudah no-op/EOL).
- Passphrase acak disimpan di `flutter_secure_storage`, database dibuka
  via `openAppDatabase` dengan `PRAGMA key`.
- Tanpa server, tanpa akun, tanpa analytics. Pindah device hanya via
  backup file terenkripsi yang dibuat user sendiri.
- Verifikasi cepat di device: `SELECT count(*) FROM
  pragma_cipher_version` ≥ 1.

## Alternatif yang ditolak

SQLite polos + enkripsi aplikasi parsial: klaim privasi jadi janji
kosong. Cloud sync: bertentangan dengan prinsip dan menambah permukaan
serangan.

## Konsekuensi

- File `.sqlite` yang bocor tetap terbaca; ancaman nyata tinggal di
  device yang sudah di-root.
- Passphrase hilang = backup tak tertolong; layar Backup mengingatkan
  menyimpan passphrase terpisah.
- Restore tidak bisa menimpa DB yang sedang terbuka → mekanisme
  dua-fase ([ADR-006](006-restore-dua-fase.md)).
