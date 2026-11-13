# Roadmap CatatIM

Status: v1.0.0+1, belum dirilis. Diperbarui 2026-10-16.

**Arah yang disepakati**: kedalaman produk dulu, rilis menyusul. User
primer = pemilik proyek (pemakaian harian sendiri); publik menjadi
target setelah produk terasa lengkap dan capture terbukti di lapangan.

## Non-goals (terkunci)

| Non-goal | Alasan |
|---|---|
| iOS / Web / Desktop | Capture notifikasi = mekanisme Android-spesifik (`NotificationListenerService`); porting berarti produk berbeda. |
| Cloud / sinkron / akun | Melanggar prinsip tanpa-server; backup terenkripsi manual sudah mencakup pindah device. |
| Update rules via server | Membuka jalur jaringan; tuning via capture log lokal sudah cukup. |
| Multi-buku / profil | Kompleksitas UI tanpa bukti kebutuhan; satu buku per perangkat cukup untuk kasus personal. |

## Milestone

### M1 — Beranda baru (selesai 2026-10-11)

Beranda berubah dari catatan pasif menjadi panggung keputusan. Di atas
hero card maskot (tetap), ditambahkan:

1. **Pace harian (kartu utama)** — "sisa aman hari ini" + posisi
   tanggal-vs-pemakaian bulan berjalan, dari `BudgetSnapshot` yang sudah
   ada.
2. **Saldo gabungan + status per akun** — total saldo, mini-status alokasi
   per akun, tap → Kelola Akun.
3. **Insight mini** — sparkline keluar 7/30 hari + 3 kategori teratas,
   jembatan ke tab Laporan.

**Selesai bila**: beranda menjawab "boleh habis berapa hari ini?" dan
"uangku di mana?" tanpa buka layar lain; perhitungan pace punya unit
test.

**Hasil**: terverifikasi di emulator (Android 14) — pace Rp10.000
dari batas harian Rp50.000 − keluar hari ini Rp40.000, fallback
"tanpa batas" sebelum anggaran diatur, saldo per akun + dot alokasi,
sparkline 7/30, navigasi ke Laporan dan Kelola Akun. Ditemukan & diperbaiki
saat smoke: pace tidak segar setelah edit anggaran (refresh saat kembali
dari layar Anggaran).

> **Arsitektur info v2** (2026-10-14, post-M1): navigasi ditata ulang
> menjadi shell 4 tab — **Beranda · Rekap · Rencana · Bon** — dengan FAB
> kontekstual per tab. Tab Riwayat/Laporan digantikan **Rekap** (4 segmen:
> Transaksi, Donat, Tren, Kalender) dan tab Anggaran digantikan **Rencana**
> (segmen Batas; ~~+ Target/Sisihkan~~ — dipensiunkan, ADR-009);
> statistik memakai keluar murni (transfer dikecualikan). Layar lama
> (Riwayat/Laporan/Anggaran) dipensiunkan.
> Status M1–M5 mengikuti revisi terbaru (lihat catatan 2026-10-16).
>
> **Perubahan rencana** (2026-10-16): M2 (misi harian) dibatalkan —
> kebiasaan mencatat sudah dirayakan oleh streak + mood (ADR-007),
> misi terpisah berarti reward ganda untuk perilaku yang sama.
> Pengingat jatuh tempo bon diputuskan **tidak dibangun** — bon cukup
> daftar + status lunas, tanpa scheduler notifikasi. Target/Sisihkan
> dipensiunkan (ADR-009): Rencana kini murni Batas.

### M2 — Misi harian (dibatalkan 2026-10-16)

Dibatalkan: kebiasaan mencatat sudah dirayakan oleh streak disiplin +
mood maskot (ADR-007). Menambah quest engine terpisah memberi dua
reward untuk satu perilaku dan menambah permukaan yang harus
dipelihara. Bila motivasi mencatat terbukti kurang di pemakaian
harian, pertimbangkan ulang dari data — bukan dari asumsi.

### M3 — Validasi capture lapangan

Syarat sebelum rilis: parser terbukti dengan notifikasi asli.

- Semua template blu tervalidasi minimal satu capture asli per template.
- `packageNames` Bank Nagari terisi dari capture log (saat ini kosong).
- Target: pemakaian normal beberapa hari dengan **nol** entri gagal
  parse; entri lama sukses di-parse ulang.

### M4 — Kepatuhan rilis

- Privacy policy URL (satu-satunya checklist Play yang belum beres
  selain di bawah).
- Form Data safety: klaim "tidak dikumpulkan/dibagikan" valid karena
  semua lokal.
- Build release signed + closed testing (12 tester, 14 hari).

### M5 — Production

Rollout bertahap setelah closed testing lulus tanpa blocker.

## Keputusan terbuka

- Widget test UI: tetap 0 sampai ada bug UI nyata yang membuktikan
  kebutuhannya.

## Risiko

| Risiko | Mitigasi |
|---|---|
| Parser salah → semua laporan/anggaran/mood ikut salah | M3 wajib sebelum M4; reparse capture log memperbaiki data lama tanpa transaksi ulang. |
| Passphrase backup hilang | Data tak tertolong — passphrase wajib disimpan terpisah dari file backup (diingatkan di layar Backup). |
| Vendor agresif mematikan listener (vivo/Funtouch) | Panduan baterai/autostart + indikator kesehatan capture di layar Capture Log. |
| Fitur terus bertambah tanpa validasi | M3 diposisikan sebagai gerbang sebelum jalur rilis; keputusan baru dicek terhadap non-goals. |
