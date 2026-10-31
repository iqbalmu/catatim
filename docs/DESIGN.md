# Design System Bukuduit — "Slate-Indigo Clean" v3.0

Arah visual (diperbarui 2026-10-27, menggantikan "Mainan Hangat" burlap v2.1):
**bersih, tenang, dan berbobot finansial** — menggunakan palet ultra-clean Slate 50
dengan aksen fungsional Indigo, Emerald, Amber, dan Rose. Dokumen ini adalah sumber
kebenaran visual aplikasi; widget-kit terpusat di `lib/ui/quest.dart` + `lib/theme/`.

## Prinsip Desain

1. **Satu Hero per Layar.** Setiap tampilan memiliki satu jangkar visual dominan (misal: Total Saldo di Beranda, Status Batas Bulanan di Anggaran, Net Arus Kas di Laporan).
2. **Tiga Level Permukaan Kartu (`QuestCardVariant`):**
   - `hero`: Kartu jangkar utama (radius 24, padding lega, elevasi menonjol).
   - `card`: Kartu konten standar (radius 20, hairline border `#F1F5F9`, shadow halus).
   - `flat`: Strip ringkas atau sub-konten (latar `surface2`, hairline border, tanpa shadow).
3. **Anggaran Aksen Warna Terkendali:**
   - **Indigo (`#6366F1` / `#4F46E5`)**: Hanya untuk brand dan elemen interaktif / CTA primer.
   - **Emerald (`#10B981`)**: Khusus pemasukan dan status aman / aktif.
   - **Amber (`#F59E0B`)**: Khusus peringatan mendekati batas anggaran (75–99%) dan gamifikasi.
   - **Rose (`#EF4444`)**: Khusus pengeluaran dan status over-budget / aksi destruktif.
4. **Angka Adalah Raja:**
   - Semua nominal finansial memakai `FontFeature.tabularFigures()` dengan tipografi tebal (`qDisplay` 28–34 atau `qTitle`).
5. **Tanpa Dekorasi Berlebih:**
   - Menghapus tagline dekoratif, penomoran buatan (seperti `01–04`), dan nesting kartu di dalam kartu.

## Palet Token (`lib/theme/tokens.dart` & `quest.dart`)

| Token | Nilai Hex | Peran |
|---|---|---|
| `bg` | `#F8FAFC` | Latar aplikasi (Slate 50) |
| `surface` | `#FFFFFF` | Permukaan kartu murni |
| `surface2` | `#F1F5F9` | Tint latar sekunder / strip (Slate 100) |
| `line` / `border` | `#F1F5F9` | Garis pembatas hairline halus |
| `text` / `ink` | `#0F172A` | Teks judul utama (Slate 900) |
| `body` | `#334155` | Teks bacaan konten (Slate 700) |
| `muted` | `#64748B` | Teks sekunder / keterangan (Slate 500) |
| `primary` | `#6366F1` | Brand & tombol CTA utama (Indigo 500) |
| `primaryLight` | `#EEF2FF` | Latar tint CTA & banner draf (Indigo 50) |
| `good` / `incoming` | `#10B981` | Pemasukan & status aman (Emerald 500) |
| `incomingTint` | `#ECFDF5` | Latar chip pemasukan / surplus |
| `warn` | `#F59E0B` | Peringatan mendekati batas 75-99% (Amber 500) |
| `warnTint` | `#FEF3C7` | Latar chip peringatan / streak |
| `bad` / `outgoing` | `#EF4444` | Pengeluaran & over-budget (Rose 500) |
| `outgoingTint` | `#FEF2F2` | Latar chip pengeluaran / defisit |

## Tipografi — Nunito

| Peran | Ukuran / Bobot | Kegunaan |
|---|---|---|
| `qDisplay` | 28–34 / w900, `tabularFigures` | Hero saldo, nominal display utama |
| `qTitle` | 15–20 / w800 | Judul kartu, judul halaman |
| `qBody` | 13–14 / w500–w600 | Teks konten, keterangan input |
| `qSmall` | 11–12 / w500–w600 | Metadata baris, subjudul, status |
| `qEyebrow` | 10–11 / w800, uppercase | Label seksi, kategori pelacak |

## Bentuk & Elevasi

- **Radius (`AppRadius`)**:
  - `sheet`: **24px** (hero card, drawer sheet).
  - `card`: **20px** (kartu konten standar).
  - `nav`: **28px** (bottom navigation bar).
  - `frame`: **18px** (bingkai segmented).
  - `tile`: **14px** (tile item daftar, field input).
  - `cell`: **12px** (avatar ikon kecil, picker cell).
  - `pill`: **999px** (tombol, badge status, switch).
- **Elevasi (`AppShadows`)**:
  - `card`: `Offset(0, 4), blurRadius: 16, color: Color(0x080F172A)`
  - `raised`: `Offset(0, 6), blurRadius: 18, color: Color(0x0C0F172A)`
  - `elevated`: `Offset(0, 8), blurRadius: 24, color: Color(0x0D0F172A)`

## Komponen

- **Kartu**: `surface`, radius 22, cushion shadow, padding 14–16.
- **Panggung atas**: ruang hangat `honey50` yang memudar ke bawah, radius
  24, tanpa kartu dan tanpa bayangan — karakter berdiri di dalamnya.
  Satu per layar.
- **Tombol utama**: gradien emas, teks `#6B4A1E` 800, radius pill,
  spring press. Sekunder: `surface2` teks ink. Teks tombol = aksi nyata
  ("Simpan", bukan "OK").
- **Chip/pill**: `surface2` radius 999; status memakai tint
  (`goodTint`/`badTint`/`accentTint`) + teks `good`/`bad`/`accentInk`.
- **Segmented**: sel aktif **mint** `#7FBDB1` teks putih — aksen
  netral-aktif; emas tidak dipakai untuk state, hanya CTA.
- **Tile transaksi**: dot kategori lingkaran penuh, nama 700, meta
  kecil muted, nominal tabular berwarna arah.
- **Nav melayang**: `surface` radius 22–24, cushion shadow, FAB
  gradien emas menonjol ke atas; item aktif `goldInk`.
- **Maskot Duit**: karakter kunci aplikasi. Ukuran: **64** (Beranda
  pilot v3, kartu penutup Bon), **76** (meter batas di Rencana), **172**
  (`MascotStage`, kini hanya di Rencana). Ekspresi = fungsi kondisi
  nyata. Tidak menempel di setiap kartu.
- **Panggung maskot** (`MascotStage`): glow radial lembut + bayangan
  tanah, karakter berdiri di atasnya. Meter Rencana memakai glow
  `honey50` di atas kartu putih. (`DuitStage` 172 di Beranda dihentikan
  oleh pilot v3 — file dihapus.)
- **Kalimat Duit**: satu kalimat pendek ("Duit khawatir — Harian
  terlampaui (120%)") — di Beranda pilot v5 tampil di dalam dunia,
  tepat di bawah nama Pochy. Semua mood tampil sebagai render 3D
  (raster WebP); mood tanpa aset spesifik memakai raster terdekat —
  vektor hanya fallback bila aset gagal dimuat. Warna
  burlap/tali/syal/koin dari palet ADR-010.
- **Dunia Pochy** (`UangCard`, Beranda): full-bleed scene — langit
  `honey50` → rumput `mint` (horizon 42%), `MascotStage` 172 di tengah,
  wordmark di langit, nama "Pochy" + kalimat Duit, koin emas
  dekoratif. Info streak hidup di strip MINGGU INI.
- **Spending card** (`SpendingCard`, Beranda — langsung di bawah
  dunia): label "PENGELUARAN HARI INI 💰"; angka besar terpakai harian
  "/ limit harian" (tanpa batas → angka saja); dua stats bar ala Koby —
  **Minggu ini** (bar `honeyDeep`) dan **Bulan ini** (bar `mintDeep`),
  isi bar = terpakai/limit, over `outgoing`, nilai "x /limit" tabular.
  Tap kartu → Rencana.
- **Strip streak** (`StreakStrip`): record mingguan ala "This Week" —
  header "MINGGU INI" + counter "🔥 n hari" di kanan atas, lalu 7 sel
  Sen–Min: hari disiplin = lingkaran `honey50` + api `honeyDeep`; hari
  lewat batas = angka tanggal merah; hari belum terjadi = angka redup;
  label hari ini disorot `honeyInk`. Sumber: `disciplineMonth` (hitung
  ulang transaksi).
- **Seksi transaksi terbaru** (`TransaksiTerbaruCard`): 3 baris chip
  ikon kategori 40px (tint warna kategori 14% + ikon dari colorIndex),
  judul + meta, nominal berwarna arah; "Lihat semua" → Rekap.

## Motion

- Press scale 0,96 dengan curve **spring** (`Cubic(0.34,1.56,0.64,1)`,
  bounce ~6%), durasi 150–200ms.
- Transisi halaman: slide penuh dari kanan (`Offset(1, 0)` → nol) di
  semua platform via `QuestPageTransitionsBuilder`; saat back meluncur
  kembali ke kanan.
- Pindah tab navbar: berganti di tempat via `IndexedStack` tanpa efek
  slide dari samping; setiap tab memiliki `QuestStage` mandiri sehingga
  hanya tab tujuan yang memutar animasi masuk tanpa me-reset state tab lain.
- Nilai yang berubah karena aksi user (bulan/periode, jumlah draf,
  inspector grafik): ganti tipis via `QuestSwap` — fade + geser 18% tinggi,
  220ms easeOut; bagian yang tumbuh/runtuh memakai `AnimatedSize` 220ms.
- Show/hide saldo (`TotalBalanceCard` & chip akun): transisi privasi kaca
  buram (*frosted blur* `ImageFiltered` + pegas skala + sapuan kilau pada
  titik privasi, serta riak bertahap antar chip akun); saat dibuka kembali,
  nominal menghitung naik dari 0 ke saldo aktual.
- Isi TAB menetas satu-per-satu via `QuestTabEnter` (jeda 65ms per `index`,
  320ms easeOut), dipicu `QuestStage` dengan `AnimationController` tanpa
  menghancurkan `State` atau `StreamBuilder` anak.
- Isi halaman yang di-push / sheet menetas bertahap satu-per-satu via
  `QuestEnter` (jeda 65ms per `index`, fade + geser 6% tinggi).
- Nominal, persentase, dan bar/chart menampilkan prosesnya dari 0 ke nilai
  akhir: `QuestMoney` / `QuestCountUp` menghitung naik dari 0 dengan lebar
  tabular stabil, selaras dengan `QuestProgressBar` / `QuestBar` (620ms
  `easeOutCubic`), grafik batang tren (bergelombang kiri-ke-kanan), dan bar
  komposisi kategori melalui `QuestEnterScope`.
- Bob maskot: sine 2400ms amplitudo 2% (aset raster: translate murni).
- Milestone/berubah level: perayaan singkat (stempel/konfeti) + haptic.
- Hormati `MediaQuery.disableAnimations` (reduced motion).

## Bahasa tulis

Kalimat aktif, sebut aksi nyata, kosakata konsisten antar layar
(tombol "Simpan" → snack "Tersimpan"). Error menjelaskan apa + cara
benar; empty state mengundang aksi ("Belum ada catatan — catat
transaksi pertamamu").

## Alur halaman (disepakati 2026-10-20, mockup 4 halaman)

- **Beranda (pilot v5.2)**: dunia Pochy full-bleed (langit → rumput,
  maskot 172 di tengah, kalimat + streak) →
  **spending card** "Pengeluaran hari ini" (angka besar / limit harian,
  ⊕, stats bar Minggu & Bulan) → strip streak harian → duo kartu
  **arus** (Keluar | Masuk berikon) → **transaksi terbaru** (chip ikon
  kategori) → **insight 7 hari** (7 batang + kategori). Jarak antar
  kartu 16dp di atas krem `bg`.
- **Rekap**: segmen **Donat default**; toggle Keluar/Masuk di dalam
  kartu donat; delta vs bulan lalu; kartu "keluar terbesar" per
  merchant. Segmen lain: Transaksi, Tren, Kalender.
- **Rencana**: segmen Harian/Mingguan/Bulanan; kartu batas + maskot
  mini sebagai meter; alokasi per jenis = daftar progres (lewat batas
  merah otomatis, belum diatur diberi label jujur); chip progres
  mingguan. Tanpa FAB (Rencana bukan tempat mencatat).
- **Bon**: ringkasan dua kolom piutang/utang; "Tandai lunas" per baris
  (satu tap); item lunas terarsip redup + tercoret; kartu penutup
  celebrate.

## Checklist migrasi (Playful Rapi → Mainan Hangat v2.1)

1. `tokens.dart`: `SeedColors` — nilai palet baru (bg, surface,
   surface2, line, ink, muted, emas 3 stop, mint 3 stop, good, bad);
   kelas `Palette` baru membungkus token peran.
2. `theme/quest.dart`: `QuestPalette` satu konstanta (hapus `.dark`),
   `QuestSchemes.dark()` dihapus; cushion shadow; segmented mint;
   spring press.
3. `app.dart`: hapus `darkTheme`/`themeMode`.
4. Layar per tab: Beranda dulu (pilot) → Rekap → Rencana → Bon →
   sekunder (Menu, Akun, Backup). Golden test minimal di widget kit.
5. Dark mode TIDAK diadaptasi di langkah mana pun (tidak ada).
