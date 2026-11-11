# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Pengguna Indonesia dengan rekening aktif di beberapa bank/e-wallet.
Tahap saat ini: dogfooding — dibangun dan dipakai sendiri dulu.
Publikasi ke publik (Play Store) direncanakan setelah stabil; waktu dan
cakupan beta belum ditentukan (open).

## Product Purpose

Pencatat keuangan pribadi yang merekam transaksi otomatis dari notifikasi
bank (NotificationListenerService) dan struk/bukti (OCR on-device), lalu
mengelola budget bulanan, bon (piutang/utang), dan laporan arus kas.

Sukses didefinisikan berlapis:

- **Mekanisme**: semua transaksi tercatat lewat capture — tanpa input
  manual sama sekali.
- **Tolok ukur**: saldo di app cocok dengan saldo bank nyata di akhir
  bulan.
- **Hasil akhir**: pengguna selalu paham ke mana uangnya pergi tiap
  bulan.

## Positioning

Input utama lewat capture notifikasi bank dan struk — bukan entri manual
seperti pencatat keuangan umumnya — dengan 100% offline, database
terenkripsi SQLCipher, tanpa akun, tanpa iklan.

## Operating Context

- Bahasa Indonesia penuh; format Rupiah; locale `id`.
- Pengguna memberi izin Notification Listener untuk bank/e-wallet;
  capture juga lewat share-intent teks/gambar dari app lain.
- Tema terang/gelap mengikuti sistem; preferensi dipersist di DB.
- Backup/restore manual via file; pindah perangkat memicu layar
  pemulihan (kunci DB terikat perangkat), bukan crash atau kehilangan
  data.

## Capabilities and Constraints

- Capture notifikasi bank + share-intent teks/gambar; OCR ML Kit
  on-device.
- Pipeline: draf → aturan (seed rules per bank) → transaksi final;
  kotak masuk draf untuk kurasi manual.
- Budget bulanan per kategori dengan status aman/waspada/lewat.
- Bon piutang/utang dengan aksi 1-tap "Lunasi".
- Laporan: ringkasan eksekutif, komposisi kategori, tren
  mingguan/bulanan.
- Gamifikasi (maskot Pochy, streak, lencana) menopang kebiasaan.
- Multi-akun bank/e-wallet.
- Constraint permanen: 100% offline (tanpa server/cloud/akun), DB
  terenkripsi SQLCipher (non-negotiable), gratis & tanpa iklan
  selamanya, bahasa Indonesia sebagai bahasa utama.

## Brand Commitments

- Nama "bukuduit"; maskot Pochy (ADR-010).
- Font Nunito; ikon Material.
- Identitas visual "Slate-Indigo Clean" (docs/DESIGN.md) adalah sumber
  kebenaran visual.

## Evidence on Hand

- Aset nyata: `assets/mascot/`, `assets/rules/seed_rules.json`,
  `docs/DESIGN.md` v3.0.
- Test suite aktif (termasuk tema, navigasi, dan transisi).
- Belum ada: screenshot pengguna nyata, testimoni, data pasar — tidak
  boleh direkayasa di permukaan mana pun.

## Product Principles

1. Capture dulu, kurasi kemudian — tidak pernah auto-post transaksi.
2. Angka adalah raja — nominal selalu tabular, tebal, jelas arahnya.
3. Privasi adalah default — offline, terenkripsi, tanpa telemetri.
4. Indonesia dulu — bahasa, format uang, konteks bank lokal.
5. Gamifikasi melayani kebiasaan, bukan distraksi.

## Accessibility & Inclusion

Standar internal: TalkBack, target sentuh 48dp, reduced-motion
(diklaim DESIGN.md; audit internal 2026-11-11 menemukan gap P1 pada
kontras token dan semantik). Wajib diselesaikan sebelum rilis publik.
