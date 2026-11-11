# Design System Bukuduit — "Slate-Indigo Clean" v3.0

Arah visual (diperbarui 2026-11-11):
**bersih, tenang, dan berbobot finansial** — menggunakan palet ultra-clean Slate 50
(Slate 900 pada Dark Mode) dengan aksen fungsional Indigo, Emerald, Amber, dan Rose.
Dokumen ini adalah sumber kebenaran visual aplikasi; widget-kit terpusat di `lib/ui/quest.dart` + `lib/theme/`.

## Prinsip Desain

1. **Satu Hero per Layar.** Setiap tampilan memiliki satu jangkar visual dominan (misal: Total Saldo / Pace Harian di Beranda, Status Batas Bulanan di Rencana, Net Arus Kas di Laporan).
2. **Tiga Level Permukaan Kartu (`QuestCardVariant`):**
   - `hero`: Kartu jangkar utama (radius 24, padding lega, elevasi menonjol).
   - `card`: Kartu konten standar (radius 20, hairline border, shadow halus).
   - `flat`: Strip ringkas atau sub-konten (latar `surface2`, hairline border, tanpa shadow).
3. **Anggaran Aksen Warna Terkendali:**
   - **Indigo (`#4F46E5` / `#818CF8`)**: Hanya untuk brand dan elemen interaktif / CTA primer. Isi CTA memakai `primarySolid` (light Indigo 600 / dark Indigo 400) dengan konten `onPrimary` (putih / tinta gelap) — pasangan lolos WCAG AA (audit 2026-11-11: putih di atas Indigo 400 hanya 2,98:1).
   - **Emerald (`#047857` / `#34D399`)**: Khusus pemasukan dan status aman / aktif. Light memakai varian 700 agar lolos AA sebagai teks nominal (Emerald 500 hanya 2,54:1 di putih).
   - **Amber (`#B45309` / `#FBBF24`)**: Khusus peringatan mendekati batas anggaran (75–99%) dan gamifikasi streak. Light varian 700 (Amber 500 di `warnTint` hanya 1,93:1).
   - **Rose (`#B91C1C` / `#F87171`)**: Khusus pengeluaran dan status over-budget / aksi destruktif. Light varian 700 (Rose 500 3,76:1, Rose 600 masih 4,41:1 di tint).
4. **Angka Adalah Raja:**
   - Semua nominal finansial memakai `FontFeature.tabularFigures()` dengan tipografi tebal (`qDisplay` 28–40 atau `qTitle`).
5. **Tanpa Dekorasi Berlebih (Craft Floor):**
   - Menghapus tagline dekoratif, penomoran buatan (seperti `01–04`), nesting kartu di dalam kartu, dan kicker/eyebrow berlebihan.
   - Tanpa emoji pada salinan sistem (gunakan Material Symbols / Icons resmi).
  - Target sentuh interaktif minimum **48×48 dp** di seluruh komponen (ditegakkan di kit: tombol/ikon/switch/segmented/chip 48; sel kalender & bulan 44 visual dalam hit QuestPress).
  - Dukungan aksesibilitas TalkBack: `Semantics` label/state di seluruh kontrol kustom, liveRegion pada nominal keypad; ikon status bar edge-to-edge mengikuti tema.

## Palet Token (`lib/theme/tokens.dart` & `quest.dart`)

### Light Mode (`SeedColors`)
| Token | Nilai Hex | Peran |
|---|---|---|
| `bg` | `#F8FAFC` | Latar aplikasi (Slate 50) |
| `surface` | `#FFFFFF` | Permukaan kartu murni |
| `surface2` | `#F1F5F9` | Tint latar sekunder / strip (Slate 100) |
| `line` / `border` | `#F1F5F9` | Garis pembatas hairline halus |
| `text` / `ink` | `#0F172A` | Teks judul utama (Slate 900) |
| `body` | `#334155` | Teks bacaan konten (Slate 700) |
| `muted` | `#64748B` | Teks sekunder / keterangan (Slate 500) — hanya di atas `surface`/`bg` |
| `hint` | `#475569` | Teks di atas isian `surface2`: hint/label input, segmen tak aktif (Slate 600, 6,9:1) |
| `primary` | `#6366F1` | Brand — ikon/aksen non-teks & ripple (Indigo 500; 3,99:1 sebagai teks kecil) |
| `primarySolid` | `#4F46E5` | Isi CTA/chip terpilih/switch — pasangan `onPrimary` putih 6,29:1 (Indigo 600) |
| `primaryText` | `#4F46E5` | Teks berwarna brand: link "Lihat Semua", label nav aktif (Indigo 600, 6,29:1) |
| `primaryGradientEnd` | `#4338CA` | Ujung gradien CTA (Indigo 700, putih 7,9:1) |
| `onPrimary` | `#FFFFFF` | Teks/ikon di atas `primarySolid`/gradien |
| `primaryLight` | `#EEF2FF` | Latar tint CTA & banner draf (Indigo 50) |
| `good` / `incoming` | `#047857` | Pemasukan & status aman (Emerald 700; 5,0–5,5:1 di semua permukaan) |
| `incomingTint` | `#ECFDF5` | Latar chip pemasukan / surplus |
| `warn` | `#B45309` | Peringatan mendekati batas 75-99% (Amber 700; 4,5–5,0:1) |
| `warnTint` | `#FEF3C7` | Latar chip peringatan / streak |
| `bad` / `outgoing` | `#B91C1C` | Pengeluaran & over-budget (Rose 700; 5,9–6,5:1) |
| `outgoingTint` | `#FEF2F2` | Latar chip pengeluaran / defisit |

### Dark Mode (`DarkColors`)
| Token | Nilai Hex | Peran |
|---|---|---|
| `bg` | `#0F172A` | Latar aplikasi (Slate 900) |
| `surface` | `#1E293B` | Permukaan kartu (Slate 800) |
| `surface2` | `#334155` | Tint latar sekunder / strip (Slate 700) |
| `line` / `border` | `#334155` | Garis pembatas hairline halus |
| `text` / `ink` | `#F8FAFC` | Teks judul utama (Slate 50) |
| `body` | `#E2E8F0` | Teks bacaan konten (Slate 200) |
| `muted` | `#94A3B8` | Teks sekunder / keterangan (Slate 400) — hanya di atas `surface`/`bg` |
| `hint` | `#CBD5E1` | Teks di atas isian `surface2`: hint/label input, segmen tak aktif (Slate 300, 7,0:1) |
| `primary` | `#818CF8` | Brand & ikon aksen (Indigo 400) |
| `primarySolid` | `#818CF8` | Isi CTA — konten `onPrimary` tinta gelap 5,98:1 (Indigo 400) |
| `primaryText` | `#A5B4FC` | Teks berwarna brand (Indigo 300; 5,7–9:1 di permukaan dark) |
| `primaryGradientEnd` | `#A5B4FC` | Ujung gradien CTA (Indigo 300, tinta 8,96:1) |
| `onPrimary` | `#0F172A` | Teks/ikon di atas `primarySolid`/gradien |
| `primaryLight` | `#312E81` | Latar tint CTA & badge (Indigo 900) |
| `good` / `incoming` | `#34D399` | Pemasukan & status aman (Emerald 400) |
| `incomingTint` | `#064E3B` | Latar chip pemasukan / surplus |
| `warn` | `#FBBF24` | Peringatan mendekati batas (Amber 400) |
| `warnTint` | `#451A03` | Latar chip peringatan / streak |
| `bad` / `outgoing` | `#F87171` | Pengeluaran & over-budget (Rose 400) |
| `outgoingTint` | `#450A0A` | Latar chip pengeluaran / defisit |

## Tipografi — Nunito

| Peran | Ukuran / Bobot | Kegunaan |
|---|---|---|
| `qDisplay` | 28–40 / w900, `tabularFigures` | Hero saldo, nominal display utama |
| `qTitle` | 14–20 / w800 | Judul kartu, judul halaman |
| `qBody` | 13–14 / w500–w600 | Teks konten, keterangan input |
| `qSmall` | 11–12.5 / w500–w700 | Metadata baris, subjudul, status badge |

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
- **Chip/pill**: `surface2` radius 999; status memakai tint (`incomingTint`/`outgoingTint`/`warnTint`).
- **Segmented**: frame `surface2`; sel aktif `surface` dengan shadow halus, teks/ikon `text`/`primaryText`; tak aktif memakai `hint` (muted gagal 4,5:1 di `surface2`).
- **Tile transaksi**: ikon kategori 40px lingkaran tint 12%, nama w800, meta muted, nominal tabular berwarna arah.
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
