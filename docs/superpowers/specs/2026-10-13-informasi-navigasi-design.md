# Desain Informasi & Navigasi Bukuduit

Tanggal: 2026-10-13. Status: **DRAF — belum disetujui, belum boleh bangun kode produk.**
Hasil brainstorming 3 layar mockup (audit → navbar → peta navigasi) + dinding alur A–K.
Builder: baca utuh sebelum menyusun plan. Yang eksplisit "diserahkan ke builder" (§8) boleh diputuskan sendiri.

## 1. Maksud & latar

Pemilik memakai Bukuduit harian untuk diri sendiri, dalam dua momen berbeda:

- ⚡ **Lirik 10 detik sebelum bayar** — "hari/minggu/bulan ini masih aman nggak?"
- 🪑 **Duduk tenang** (akhir minggu/bulan) — "duitku ke mana, berapa, dibanding bulan lalu gimana?"

Tujuh kebutuhan yang harus terjawab: ① sisa harian, ② sisa mingguan, ③ sisa
bulanan, ④ habis ke mana, ⑤ pengeluaran sudah berapa, ⑥ pemasukan berapa,
⑦ lainnya — ⑦ diisi: kalender nominal per tanggal, delta vs bulan lalu, total
per hari, **pos tabungan berprogres** (pemilik menabung berpos — terkonfirmasi).

Kondisi sekarang (M1 selesai 2026-10-11): 4 tab (Beranda·Riwayat·Laporan·Bon),
FAB di tengah navbar, Anggaran sembunyi di menu ⋯, Beranda 1 angka sisa aman
(prioritas harian→mingguan→bulanan), Jejak Duit 30 titik tanpa nominal.
Masalah yang diperbaiki desain ini: ①②③ tidak terlihat sekaligus; analisis
terserak di Beranda; Target tak ada wadah; navigasi dalam tak eksplisit.

## 2. Tujuan, non-tujuan, anti-tujuan

**Tujuan:** tiap kebutuhan ①–⑦ + 🎯 tercapai dalam ≤2 ketuk; navbar 4 item;
tidak ada angka buntu (semua bisa di-tap ke sumbernya); Beranda murni momen ⚡.

**Non-tujuan** (warisan ROADMAP, tetap berlaku): iOS/Web/Desktop; cloud/sinkron/
akun; update rules via server; multi-buku. **Jadwal & pengingat jatuh tempo
diparkir** — butuh scheduler notifikasi lokal yang belum diputuskan; dilarang
merancang layarnya sekarang (janji palsu).

**Anti-tujuan** (gagal meski jalan): Beranda penuh sampai momen ⚡ mati;
navbar >4 item; badge murah di mana-mana; FAB tetap di navbar; **setoran
Target tercatat sebagai pengeluaran** (menabung ≠ belanja, dilarang
mengotori statistik ⑤).

## 3. Batasan

Offline-first Android; drift + SQLCipher (migrasi skema bila perlu, pola
ikuti migrasi v1–v6 + self-heal); copy Indonesia; nominal selalu
`Money.format` (int rupiah); `lib/core/` bebas drift/Flutter (ADR-003); gaya
hanya via kit `lib/ui/quest.dart` + `context.q` (ADR-008) — kartu putih tanpa
border, bayangan halo; tanpa dependensi pubspec baru; logika baru wajib test
engine dulu (TDD), tanpa widget test UI (keputusan ROADMAP).

## 4. Struktur: 4 tab + FAB melayang + chrome global

Navbar (urut frekuensi kiri→kanan, label ≤8 huruf): 🏠 **Beranda** · 📒 **Rekap**
· 🎯 **Rencana** · 🤝 **Bon**. Pola 4 + aksi tengah yang sekarang dipertahankan
bentuknya, tapi **FAB keluar dari navbar** → melayang kanan-bawah
(`QuestBottomNav.centerAction` dihapus).

Chrome global: lonceng 🔔 (Capture log + badge saat listener mati) dan ⋯
(Kelola Akun · Aturan capture · Backup) ada di **semua** tab.

| Tab | Isi | Segmen (default tebal) | Menjawab |
|---|---|---|---|
| Beranda ⚡ | Hero sisa aman + Duit + streak; LIMIT H/M/B sekaligus; mini keluar/masuk bln; baris SALDO; strip alert | — | ①②③⑤⑥ (1 ketuk) |
| Rekap 🪑 | Satu data empat lensa | **Transaksi** · Donat · Kalender · Tren | ⑤⑥ lookup (1), ④ (2) |
| Rencana 🪑 | Aturan ke depan | **Batas** · Target | ①②③ detail (1–2), 🎯 (2) |
| Bon 🪑 | Seperti sekarang + badge | — | utang-piutang (1) |

**Sumber kebenaran batas** (dari kode sekarang): sisa H/M/B Beranda + pace =
limit global (`app_settings`); baris Jenis = alokasi bulanan per kategori
(tabel `budgets`, opsional scope akun) yang mengisi garis snapshot/alert
sebagai garis terpisah. Alur A mengubah global; alur K menambah/mengubah
baris Jenis.

**Kontrak filter Rekap** (keputusan saya): satu state bersama {periode, akun?,
cari?, kategori?, tanggal?}; deep-link Donat → set {kategori + periode bulan
berjalan}; Kalender → set {tanggal} + lompat Transaksi; pindah segmen manual
mempertahankan periode/akun/cari, menghapus kategori/tanggal; chip ✕
membersihkan. Filter Riwayat sekarang (search/akun/periode) dilebur ke state ini.

**Operasi halaman:** Riwayat+Laporan+Kalender(baru) → Rekap; Anggaran+Target
(baru) → Rencana; Beranda dimurnikan (TrendTile/KategoriCard/KewajibanStrip/
JejakStrip hapus = pindah); JejakStrip dilebur ke Kalender; Bon tetap.

**Halaman/segmen baru:** 📅 Kalender (nominal **keluar** per tanggal saja —
stream tersedia; pemasukan tidak tampil per tanggal — keputusan saya; +
rincian hari terpilih); 🎯 Target (pos: nama, nominal target, terkumpul,
tenggat opsional; aksi Sisihkan via sheet + FAB); baris SALDO di Beranda
(rumah Kelola Akun).

## 5. Sistem navigasi

Akar tab: tanpa back (back non-Beranda → Beranda; back Beranda → keluar),
ketuk tab aktif → ke atas, state dipertahankan (IndexedStack seperti sekarang).

Alur (detail visual: `.superpowers/brainstorm/40940-1791900219/content/alur-lengkap.html`):
- **A** Beranda → tap limit → Rencana·Batas (deep-link segmen) → ✏️ → dialog ubah.
- **B** Rekap·Donat → tap kategori → Transaksi terfilter otomatis → tap baris → sheet edit.
- **C** Rencana·Target → FAB Sisihkan → sheet (pos, nominal, akun sumber).
- **D** Bon → FAB/＋Bon → sheet; tap Lunas → pindah LUNAS + posisi bersih segar.
- **E** FAB Catat → sheet (nominal, arah, kategori, akun, tanggal, pihak) → pace & alert segar.
- **F** Rekap·Kalender → tap tanggal → rincian hari (+ lompat ke Transaksi).
- **G** Baris SALDO / ⋯ → Kelola Akun → dialog tambah/ubah/hapus (hapus → transaksi tanpa akun).
- **H** 🔔 → Capture log (kesehatan, mode pelajaran, baterai) → tap baris → teks mentah + parse ulang; pertama kali = dialog disclosure → pengaturan Android.
- **I** ⋯ → Aturan → editor sheet + kartu Uji; simpan → parse ulang antrean gagal.
- **J** ⋯ → Backup (CSV, backup terenkripsi + passphrase terpisah, restore + dialog konfirmasi timpa).
- **K** Dialog ＋Jenis (nama, limit, scope akun) dan ＋Target (nama, nominal, tenggat).

FAB kontekstual: Beranda/Rekap = Catat transaksi · Rencana·Target = Sisihkan ·
Rencana·Batas = ＋Jenis · Bon = Catat bon. Badge: Bon + lonceng saja.

## 6. Yang dicoret (jangan diusulkan lagi)

6 tab; Target jadi tab sendiri; Bon → ⋯; Riwayat ⊂ Tinjau (lookup ★★★★ butuh
1 ketuk); Target full di Beranda; Anggaran tetap di ⋯; nama lama
Riwayat/Laporan/Anggaran untuk tab gabungan (dipilih: Rekap, Rencana).

## 7. Keputusan saya (boleh digugat saat membaca)

Nama "Rekap"/"Rencana"; default segmen Transaksi & Batas; Beranda tanpa Target
(murni ⚡); Kalender sebagai segmen bukan tab; sel kalender = keluar saja;
kontrak filter Rekap; Jejak dilebur; FAB melayang (mudah dijangkau jempol)
bukan di header; back non-Beranda → Beranda; Sisihkan mengurangi
saldo-spendable + pace H/M/B, bukan keluar/masuk (jawaban pemilik 2026-10-13);
badge Bon = ada belum-lunas berumur > 30 hari, tanpa kolom skema baru
(keputusan saya — pemilik konfirmasi tanpa janji-tanggal).

## 8. Diserahkan ke builder

- **Model setoran Target**: syarat anti-tujuan — sisihkan bukan keluar. Opsi:
  (a) tabel target + setoran terpisah dari transaksi; (b) pos sebagai akun
  virtual + Sisihkan sebagai transfer. Pilih salah satu, buktikan dengan uji;
  migrasi v7.
- Formula pace Target ("−RpX/bln s/d tenggat", tanpa tenggat = % saja).
- Ambang heat Kalender (relatif ke limit harian bila ada, else kuantil).
- Copy final Indonesia, empty/error states tiap segmen, pull-to-refresh tidak
  perlu (stream), performa grid kalender + watch-stream gabungan di Rekap.
- Teks disclosure tetap (syarat Play, jangan diubah maknanya).

## 9. Acuan visual (tidak dikomit, di `.superpowers/brainstorm/40940-1791900219/content/`)

`audit-dan-calon.html` · `navbar-4item.html` · `navbar-4item-v2.html` ·
`nav-system.html` · `alur-lengkap.html` (+ `usulan-6-halaman.html`,
`hifi-5-halaman.html`, `kini-beranda.html` = riwayat proses, kedaluwarsa).

## 10. Terjawab (2026-10-13)

- **T1.** Ya: sisihan mengurangi sisa H/M/B + saldo-spendable; statistik
  keluar/masuk tidak ikut.
- **T2.** Tanpa janji-tanggal: badge dari umur bon (> 30 hari); tanpa kolom
  skema baru.
