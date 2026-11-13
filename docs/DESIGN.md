# Design System CatatIn — "Petrol Teal CatatIn" v4.0

Arah visual (diperbarui 2026-11-13):
**hangat, ramah, dan berbobot finansial** — seluruh palet diturunkan dari logo
aplikasi CatatIn: latar teal petrol `#13454A` dengan aksen teal syal, orana syal,
emas koin "Rp", koral teks "In", hijau daun grafik, dan burlap karung.
Dokumen ini adalah sumber kebenaran visual aplikasi; widget-kit terpusat di `lib/ui/quest.dart` + `lib/theme/`.

## Prinsip Desain

1. **Satu Hero per Layar.** Setiap tampilan memiliki satu jangkar visual dominan (misal: Total Saldo / Pace Harian di Beranda, Status Batas Bulanan di Rencana, Net Arus Kas di Laporan).
2. **Tiga Level Permukaan Kartu (`QuestCardVariant`):**
   - `hero`: Kartu jangkar utama (radius 24, padding lega, elevasi menonjol).
   - `card`: Kartu konten standar (radius 20, hairline border, shadow halus).
   - `flat`: Strip ringkas atau sub-konten (latar `surface2`, hairline border, tanpa shadow).
3. **Anggaran Aksen Warna Terkendali:**
   - **Teal (`#1F5A53` / `#5FB8A9`)**: Hanya untuk brand dan elemen interaktif / CTA primer. Isi CTA memakai `primarySolid` (light teal deep / dark teal terang) dengan konten `onPrimary` (putih / tinta gelap) — pasangan lolos WCAG AA (audit 2026-11-13: putih di atas teal deep 7,9:1, tinta di atas teal terang 6,8:1).
   - **Hijau (`#266E48` / `#5FD3A0`)**: Khusus pemasukan dan status aman / aktif — turunan hijau daun grafik logo. Light varian gelap agar lolos AA di surface & tint.
   - **Emas (`#8A5F06` / `#E8C468`)**: Khusus peringatan mendekati batas anggaran (75–99%) dan gamifikasi streak — langsung dari koin "Rp" logo (dark) dan varian gelapnya untuk teks light.
   - **Koral (`#B93A31` / `#F0928A`)**: Khusus pengeluaran dan status over-budget / aksi destruktif — dari teks "In" logo; light digelapkan agar lolos AA (5,0:1 di tint).
4. **Angka Adalah Raja:**
   - Semua nominal finansial memakai `FontFeature.tabularFigures()` dengan tipografi tebal (`qDisplay` 28–40 atau `qTitle`).
5. **Tanpa Dekorasi Berlebih (Craft Floor):**
   - Menghapus tagline dekoratif, penomoran buatan (seperti `01–04`), nesting kartu di dalam kartu, dan kicker/eyebrow berlebihan.
   - Tanpa emoji pada salinan sistem (gunakan Material Symbols / Icons resmi).
  - Target sentuh interaktif minimum **48×48 dp** di seluruh komponen (ditegakkan di kit: tombol/ikon/switch/chip 48; segmented & chip pemilih dialog 40/38 — kontrol penuh 48 dengan bingkai/spacing; sel kalender & bulan 44 visual dalam hit QuestPress).
  - Dukungan aksesibilitas TalkBack: `Semantics` label/state di seluruh kontrol kustom, liveRegion pada nominal keypad; ikon status bar edge-to-edge mengikuti tema.

## Palet Token (`lib/theme/tokens.dart` & `quest.dart`)

### Light Mode (`SeedColors`)
| Token | Nilai Hex | Peran |
|---|---|---|
| `bg` | `#F3F8F7` | Latar aplikasi (off-white ber-tint teal) |
| `surface` | `#FFFFFF` | Permukaan kartu murni |
| `surface2` | `#E7F0EE` | Tint latar sekunder / strip |
| `line` / `border` | `#E3EDEB` | Garis pembatas hairline halus |
| `text` / `ink` | `#10393D` | Teks judul utama (petrol ink, teal tergelap logo) |
| `body` | `#2C4B4D` | Teks bacaan konten |
| `muted` | `#54716E` | Teks sekunder / keterangan — hanya di atas `surface`/`bg` (5,3:1) |
| `hint` | `#3E5D5A` | Teks di atas isian `surface2`: hint/label input, segmen tak aktif (6,2:1) |
| `primary` | `#2A6F66` | Brand — ikon/aksen non-teks & ripple (teal syal logo digelapkan; 5,9:1) |
| `primarySolid` | `#1F5A53` | Isi CTA/chip terpilih/switch — pasangan `onPrimary` putih 7,9:1 |
| `primaryText` | `#1F5A53` | Teks berwarna brand: link "Lihat Semua", label nav aktif (7,9:1) |
| `primaryGradientEnd` | `#164E48` | Ujung gradien CTA (putih 9,5:1) |
| `onPrimary` | `#FFFFFF` | Teks/ikon di atas `primarySolid`/gradien |
| `primaryLight` | `#DCEEEA` | Latar tint CTA & banner draf |
| `accent` | `#C75B1E` | Aksen kedua — orana strip syal logo (ikon, 4,3:1) |
| `good` / `incoming` | `#266E48` | Pemasukan & status aman (hijau daun logo; 6,2:1 di surface, 5,5:1 di tint) |
| `incomingTint` | `#E8F4EE` | Latar chip pemasukan / surplus |
| `warn` | `#8A5F06` | Peringatan mendekati batas 75-99% (emas koin digelapkan; 5,6:1 di tint) |
| `warnTint` | `#FCF1D8` | Latar chip peringatan / streak |
| `bad` / `outgoing` | `#B93A31` | Pengeluaran & over-budget (koral teks "In" logo; 5,7:1 di surface, 5,0:1 di tint) |
| `outgoingTint` | `#FDEEEC` | Latar chip pengeluaran / defisit |

### Dark Mode (`DarkColors`)
Graphite netral (2026-11-14): latar tidak lagi teal, teal hanya aksen brand.
Tangga `bg → surface → surface2` dan `line` sengaja dilebarkan agar batas
kartu terbaca (line 1,87:1 di surface; sebelumnya 1,42:1).

| Token | Nilai Hex | Peran |
|---|---|---|
| `bg` | `#0C1112` | Latar aplikasi (graphite hampir hitam, semburat sejuk) |
| `surface` | `#191F21` | Permukaan kartu — satu langkah di atas bg |
| `surface2` | `#262F31` | Tint latar sekunder / strip / isian input |
| `line` / `border` | `#3F4C4E` | Garis pembatas hairline (1,87:1 di surface) |
| `text` / `ink` | `#EFF4F3` | Teks judul utama (putih netral) |
| `body` | `#CFD8D7` | Teks bacaan konten |
| `muted` | `#93A2A1` | Teks sekunder / keterangan (6,3:1 di surface, 5,2:1 di surface2) |
| `hint` | `#A9B9B7` | Teks di atas isian `surface2`: hint/label input, segmen tak aktif (6,7:1) |
| `primary` | `#5FB8A9` | Brand & ikon aksen (teal syal diterangkan; 5,8:1 di surface2) |
| `primarySolid` | `#4FAA9B` | Isi CTA — konten `onPrimary` tinta gelap 6,8:1 |
| `primaryText` | `#7FD1C2` | Teks berwarna brand (9,4:1 di surface) |
| `primaryGradientEnd` | `#77C9BA` | Ujung gradien CTA |
| `onPrimary` | `#0C1112` | Teks/ikon di atas `primarySolid`/gradien |
| `primaryLight` | `#17302D` | Latar tint CTA & badge |
| `accent` | `#E58A5C` | Aksen kedua — orana syal logo diterangkan |
| `good` / `incoming` | `#5FD3A0` | Pemasukan & status aman (9,0:1 di surface) |
| `incomingTint` | `#13322A` | Latar chip pemasukan / surplus |
| `warn` | `#E8C468` | Peringatan mendekati batas (10,0:1 di surface) |
| `warnTint` | `#3A2E12` | Latar chip peringatan / streak |
| `bad` / `outgoing` | `#F0928A` | Pengeluaran & over-budget (7,3:1 di surface) |
| `outgoingTint` | `#3A1B1C` | Latar chip pengeluaran / defisit |

## Tipografi — Nunito

| Peran | Ukuran / Bobot | Kegunaan |
|---|---|---|
| `qDisplay` | 28–40 / w900, `tabularFigures` | Hero saldo, nominal display utama |
| `qTitle` | 14–20 / w800 | Judul kartu, judul halaman |
| `qBody` | 13–14 / w500–w600 | Teks konten, keterangan input |
| `qSmall` | 11–12.5 / w500–w700 | Metadata baris, subjudul, status badge |

### Tanda arah nominal (+/−) — "minimalis"

Tanda arah **bukan** elemen seberat angka; ia marker subordinat di samping
angka ("Angka adalah Raja"). Semua nominal bertanda memakai `QuestMoney`
(`lib/theme/quest.dart`) dengan parameter `QuestSignStyle`:

| Aspek | Nilai | Catatan |
|---|---|---|
| Glyph | `−` U+2212 & `+` | Bukan hyphen ASCII (pendek & menggantung); Nunito menyediakan keduanya |
| Ukuran | 62% ukuran angka (80% bila angka < 16px) | Konstan: `QuestSignStyle.sizeRatio` / `smallRatio` |
| Bobot | 1 tingkat lebih ringan di tangga bundel w400→w600→w700→w800 | ExtraBold terdaftar sebagai w800 |
| Opasitas | 55% warna angka (65% untuk nominal kecil) | Warna arah tetap terbaca, angka tetap dominan |
| Posisi | dinaikkan 0.18 em dari baseline | Center digit `0` = +0.3525 em, center `−` = +0.2870 em → tanpa kompensasi tanda duduk di bawah tengah digit |
| Jarak | 0.05 em | Optik, bukan spasi |

Aturan: **tanda hanya lewat `MoneyTone`**, tidak boleh digambar manual per
call site. `Money.format` (string data) memakai glyph U+2212 yang sama
supaya satu nominal tidak pernah punya dua bentuk tanda.

## Bentuk & Elevasi

- **Radius (`AppRadius`)**:
  - `sheet`: **24px** (hero card, drawer sheet).
  - `card`: **20px** (kartu konten standar).
  - `nav`: **28px** (bottom navigation bar).
  - `frame`: **18px** (bingkai segmented).
  - `tile`: **14px** (tile item daftar, field input).
  - `cell`: **12px** (avatar ikon kecil, picker cell).
  - `pill`: **999px** (tombol, badge status, switch).
- **Elevasi (`QuestPalette.cardShadow` / `elevatedShadow` — dark-aware, audit T-01)**:
  - `card`: `Offset(0, 4), blurRadius: 16` — warna `shadow` per tema: light `Color(0x080F172A)` (3% slate), dark `Color(0x30000000)` (48% hitam).
  - `elevated`: `Offset(0, 8), blurRadius: 24` — warna `shadow` per tema.
  - Kartu flat & tile daftar: tanpa shadow (hairline border saja).

## Komponen

- **Kartu**: `surface`, radius 20–24, hairline border, padding 14–16.
- **Tombol utama**: gradien `primarySolid → primaryGradientEnd`, teks `onPrimary`, radius pill. Sekunder: `surface2` teks ink. Danger: isi `bad`, teks `onPrimary`.
- **Input teks**: satu gaya kanonik dari `inputDecorationTheme` — fill `surface2`, radius `tile`, border `line` → fokus `primary` 1.5px, label/hint `hint`. Situs lain dilarang menimpa border/fill/isDense; cukup `InputDecoration(labelText, hintText, prefixIcon, …)` (atribut konten saja). Referensi: drawer tambah akun.
- **Chip/pill**: `surface2` radius 999; status memakai tint (`incomingTint`/`outgoingTint`/`warnTint`).
- **Segmented**: frame `surface2`; sel aktif `surface` dengan shadow halus, teks/ikon `text`/`primaryText`; tak aktif memakai `hint` (muted gagal 4,5:1 di `surface2`).
- **Tile transaksi**: ikon kategori 40px lingkaran tint 12%, nama w800, meta muted, nominal tabular berwarna arah. Tanda `+`/`−` memakai `QuestMoney` + `MoneyTone` (lihat Tipografi) — bukan prefiks manual.
- **Nominal (`QuestMoney`)**: satu-satunya cara menampilkan nominal bertanda; angka tabular + `FontFeature.tabularFigures()`, tanda arah digambar terpisah sebagai marker subordinat.
- **Nav bawah**: `surface` radius 28, `elevatedShadow`, state aktif pada warna teks dan ikon (`primaryText`), tanpa background pill, tombol tengah aksi utama (gradien `primarySolid → primaryGradientEnd`, ikon `onPrimary`).
- **Keypad**: tombol 50dp (save 48dp), haptic feedback, pintasan nominal (000, Backspace, Clear).

## Motion

- Press scale 0.96 dengan spring curve (`QuestMotion.spring`), responsif tanpa memblokir scroll gestur.
- Transisi halaman: slide penuh dari kanan di semua platform via `QuestPageTransitionsBuilder`.
- Pindah tab navbar: pergantian di tempat via `IndexedStack` tanpa efek slide samping; tiap tab memiliki `QuestStage` mandiri.
- Nilai dinamis: ganti halus via `QuestSwap`; bar / grafik beranimasi progresif dari 0 ke nilai akhir saat tab dibuka.
- Hormati `MediaQuery.disableAnimations` (reduced motion) — termasuk potong instan pada transisi halaman (audit M-01).

## Alur Halaman

- **Beranda**: Header salam & lonceng draf → Stacked Hero Cards (`DailyPaceHeroCard` & `TotalBalanceCard`) → Banner Notifikasi Bank Aktif → Transaksi Terbaru (5 baris + "Lihat semua").
- **Transaksi**: Tab filter, ringkasan arus kas (Pemasukan, Pengeluaran, Selisih), daftar transaksi dikelompokkan per hari.
- **Bon**: Ringkasan Piutang dan Utang; daftar bon aktif dengan aksi 1-tap "Lunasi" atau "Hitung & Lunasi".
- **Laporan**: Ringkasan eksekutif arus kas, komposisi kategori pengeluaran, tren mingguan/bulanan.
