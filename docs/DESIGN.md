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
   - **Indigo (`#6366F1` / `#818CF8`)**: Hanya untuk brand dan elemen interaktif / CTA primer.
   - **Emerald (`#10B981` / `#34D399`)**: Khusus pemasukan dan status aman / aktif.
   - **Amber (`#F59E0B` / `#FBBF24`)**: Khusus peringatan mendekati batas anggaran (75–99%) dan gamifikasi streak.
   - **Rose (`#EF4444` / `#F87171`)**: Khusus pengeluaran dan status over-budget / aksi destruktif.
4. **Angka Adalah Raja:**
   - Semua nominal finansial memakai `FontFeature.tabularFigures()` dengan tipografi tebal (`qDisplay` 28–34 atau `qTitle`).
5. **Tanpa Dekorasi Berlebih (Craft Floor):**
   - Menghapus tagline dekoratif, penomoran buatan (seperti `01–04`), nesting kartu di dalam kartu, dan kicker/eyebrow berlebihan.
   - Tanpa emoji pada salinan sistem (gunakan Material Symbols / Icons resmi).
   - Target sentuh interaktif minimum **48×48 dp** di seluruh komponen.
   - Dukungan aksesibilitas TalkBack dengan `Semantics` pada seluruh kontrol kustom.

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
| `muted` | `#64748B` | Teks sekunder / keterangan (Slate 500) |
| `primary` | `#6366F1` | Brand & tombol CTA utama (Indigo 500) |
| `primaryLight` | `#EEF2FF` | Latar tint CTA & banner draf (Indigo 50) |
| `good` / `incoming` | `#10B981` | Pemasukan & status aman (Emerald 500) |
| `incomingTint` | `#ECFDF5` | Latar chip pemasukan / surplus |
| `warn` | `#F59E0B` | Peringatan mendekati batas 75-99% (Amber 500) |
| `warnTint` | `#FEF3C7` | Latar chip peringatan / streak |
| `bad` / `outgoing` | `#EF4444` | Pengeluaran & over-budget (Rose 500) |
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
| `muted` | `#94A3B8` | Teks sekunder / keterangan (Slate 400) |
| `primary` | `#818CF8` | Brand & tombol CTA utama (Indigo 400) |
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
| `qDisplay` | 28–34 / w900, `tabularFigures` | Hero saldo, nominal display utama |
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
- **Elevasi (`AppShadows`)**:
  - `card`: `Offset(0, 4), blurRadius: 16, color: Color(0x080F172A)`
  - `raised`: `Offset(0, 6), blurRadius: 18, color: Color(0x0C0F172A)`
  - `elevated`: `Offset(0, 8), blurRadius: 24, color: Color(0x0D0F172A)`

## Komponen

- **Kartu**: `surface`, radius 20–24, hairline border, padding 14–16.
- **Tombol utama**: `primary` solid, teks putih, radius pill. Sekunder: `surface2` teks ink.
- **Chip/pill**: `surface2` radius 999; status memakai tint (`incomingTint`/`outgoingTint`/`warnTint`).
- **Segmented**: sel aktif `surface` dengan shadow halus, teks `text` w800.
- **Tile transaksi**: ikon kategori 40px lingkaran tint 12%, nama w800, meta muted, nominal tabular berwarna arah.
- **Nav bawah**: `surface` radius 28, elevated shadow, perubahan state aktif pada warna teks dan ikon (`primary`), tanpa background pill, tombol tengah aksi utama.
- **Keypad**: tombol 50dp, haptic feedback, pintasan nominal (000, Backspace, Clear).

## Motion

- Press scale 0.96 dengan spring curve (`QuestMotion.spring`), responsif tanpa memblokir scroll gestur.
- Transisi halaman: slide penuh dari kanan di semua platform via `QuestPageTransitionsBuilder`.
- Pindah tab navbar: pergantian di tempat via `IndexedStack` tanpa efek slide samping; tiap tab memiliki `QuestStage` mandiri.
- Nilai dinamis: ganti halus via `QuestSwap`; bar / grafik beranimasi progresif dari 0 ke nilai akhir saat tab dibuka.
- Hormati `MediaQuery.disableAnimations` (reduced motion).

## Alur Halaman

- **Beranda**: Header salam & lonceng draf → Stacked Hero Cards (`DailyPaceHeroCard` & `TotalBalanceCard`) → Banner Notifikasi Bank Aktif → Transaksi Terbaru (3 baris + "Lihat semua").
- **Transaksi**: Tab filter, ringkasan arus kas (Pemasukan, Pengeluaran, Selisih), daftar transaksi dikelompokkan per hari.
- **Bon**: Ringkasan Piutang dan Utang; daftar bon aktif dengan aksi 1-tap "Lunasi" atau "Hitung & Lunasi".
- **Laporan**: Ringkasan eksekutif arus kas, komposisi kategori pengeluaran, tren mingguan/bulanan.
