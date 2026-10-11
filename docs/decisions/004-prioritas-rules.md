# ADR-004: Prioritas rules — user di atas seed

## Status

Diterima (2026-10-11, bersama layar Aturan).

## Konteks

Seed rules (`assets/rules/seed_rules.json`) adalah titik awal yang
belum tentu cocok dengan teks notifikasi asli tiap user. User butuh
kemampuan menimpa rules bawaan tanpa mengubah asset.

## Keputusan

Urutan evaluasi `RuleEngine`:

1. **User rules** (tabel `user_rules`, layar Aturan) — pattern custom
   user bersifat eksklusif: bila tidak match, evaluasi berhenti
   (gugur), tidak jatuh ke seed.
2. **Seed rules** — dimaterialisasi ke `user_rules` sekali saat
   bootstrap (`seedUserRulesFromBanks`) agar user bisa menonaktifkan/
   mengubahnya seperti miliknya sendiri.
3. **Template generik** (`unknown`) — pola in/out umum untuk app tak
   dikenal.

## Alternatif yang ditolak

Merge semua rules dengan bobot sama: keputusan user bisa dikalahkan
seed, membingungkan saat debugging parse.

## Konsekuensi

- Aturan "apakah transaksi ini ter-parse X?" selalu bisa dijawab dengan
  membaca satu daftar rules berurutan.
- Update seed di rilis berikutnya tidak pernah menimpa/menambah apa
  pun begitu `user_rules` berisi — seeding skip seluruhnya bila tabel
  sudah ada baris (`seedUserRulesFromBanks`, guard `existing
  .isNotEmpty`). Seed baru dari update app hanya berlaku untuk
  instalasi baru; user lama mengadopsi manual via layar Aturan.
