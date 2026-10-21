# Design System Bukuduit — "Mainan Hangat" v2.1

Arah visual (diperbarui 2026-10-20, menggantikan "Playful Rapi" 2026-10-11):
**hangat, empuk, dan mainan** — menerjemahkan render 3D maskot Pochy
(lighting, material clay, syal teal, koin emas) ke bahasa UI. Keputusan
lengkap: [ADR-010](decisions/010-palet-dari-piksel-maskot.md). Dokumen ini
satu-satunya sumber kebenaran visual; widget-kit hidup di
`lib/ui/quest.dart` + `lib/theme/`.

## Prinsip

1. **Duit adalah meter, kategori adalah bahasa.** Ekspresi maskot selalu
   mencerminkan kondisi anggaran nyata (ADR-007); warna kategori membawa
   informasi di seluruh app — bukan dekorasi.
2. **Angka adalah raja.** Angka besar, tabular, kontras tinggi. Dekorasi
   tidak boleh menurunkan keterbacaan angka.
3. **Empuk, bukan datar.** Pemisahan via cushion shadow (dua lapis:
   bayangan hangat bawah + highlight tipis atas) — bukan border tebal,
   bukan hard shadow.
4. **Satu kartu = satu ide.** Maksimal satu zona hero per layar.
5. **Semua warna dari piksel Pochy.** Tidak ada hex baru yang dikarang —
   setiap token punya sumber di karakter (tubuh, koin, syal, mulut,
   bintang pastel).
6. **Duit adalah wajah, bukan hiasan.** Karakter tampil besar di tempat
   yang penting (panggung hero, meter batas), menyebut perasaannya, dan
   menyapa dari header Beranda — bukan menempel kecil di sudut kartu.

## Palet — "Pastel Pochy" (satu tema; TANPA dark mode — ADR-010)

| Token | Nilai | Sumber piksel Pochy |
|---|---|---|
| `bg` | `#FBF5EC` | burlap `#E1BC94` dicerahkan |
| `surface` | `#FFFDF9` | putih hangat hue burlap |
| `surface2` | `#F6E9DA` | burlap `#BF946F` + putih |
| `line` | `#EDE0CE` | bayang tipis burlap |
| `ink` | `#5B4433` | tali/mata `#3E2214` dicerahkan |
| `muted` | `#AD9680` | lipatan bayang `#926A4A` |
| emas | `#F9DCA8 → #E8B36B` | bintang kuning `#FDF6BF` → koin `#F1A23A` redup |
| `goldInk` | `#C08A3D` | emas gelap — teks/tautan/CTA teks |
| aksen mint | `#A4D1C9` / `#7FBDB1` | syal teal + bintang mint |
| `accentInk` | `#3E7A6D` | mint diperdalam untuk teks |
| `accentTint` | `#E6F2EF` | mint + putih |
| `good` | `#4A8C7E` | mint diperdalam (menggantikan hijau lama) |
| `bad` | `#B05530` | mulut menangis `#AA3E0C` disiram |

Maskot = satu-satunya elemen full-color pekat; emas tidak lagi warna
"semua halaman" — CTA + zona maskot saja yang paling terang. Aksen
mint mengambil peran "netral-aktif" (segmented, switch, status tenang).

Bahasa kategori: palet 9 warna TIDAK berubah (ADR-010) — itu bahasa
data (`Categories.colorIndex`), bukan chrome: dot transaksi, donut,
chip kategori, garis chart. Tidak dipakai di luar konteks kategorinya.

## Tipografi — Nunito (file TTF dibundel offline via `fonts:` di
`pubspec.yaml`; package `google_fonts` tidak dipakai)

| Peran | Ukuran/berat | Pakai |
|---|---|---|
| Display angka | 26–40 / 800, `tabularFigures` | sisa aman, saldo, total |
| Judul | 17–20 / 800 | judul kartu, layar |
| Body | 14–15 / 400–600 | konten |
| Kecil | 12–13 / 600 | meta, subjudul |
| Eyebrow | 10–10,5 / 800, uppercase, letter-spacing 1,5 | label seksi |

Angka selalu `FontFeature.tabularFigures()`. Jangan campur font lain.

## Bentuk & elevasi

- Radius: kartu **22**, tile **18**, bingkai kontrol **22**, sheet
  **24**, sel kecil **12**, tombol & chip/pill **999** (`AppRadius`;
  tombol utama memakai pill, tinggi ≥46).
- Elevation — **cushion shadow** (satu-satunya mekanisme pemisah):
  - kartu: `0 8px 18px rgba(90,70,40,.09)` + `inset 0 2px 0
    rgba(255,255,255,.9)` + `inset 0 -2px 0 rgba(120,95,60,.05)`
  - elemen melayang (nav): `0 12px 28px rgba(90,65,30,.20)` + inset
    highlight
  - hero/emas: glow `0 12px 26px rgba(190,140,70,.30)` + inset highlight
- **Dilarang**: border tebal 2–3px, hard shadow offset, outline ganda.
- Spacing: grid `4 / 8 / 16 / 24 / 32` (existing `Spacing`).

## Komponen

- **Kartu**: `surface`, radius 22, cushion shadow, padding 14–16.
- **Zona hero**: gradien emas `#FBE7BE → #E8B36B`, radius 24–26, cushion
  shadow, angka display + Duit di panggung, teks `ink`. Satu per layar.
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
- **Maskot Duit**: karakter kunci aplikasi. Ukuran: **52** (leading
  header Beranda), **64** (kartu penutup Bon), **76** (meter batas di
  Rencana), **124** (panggung hero Beranda). Ekspresi = fungsi kondisi
  nyata. Tidak menempel di setiap kartu.
- **Panggung maskot** (`MascotStage`): glow radial lembut + bayangan
  tanah, karakter berdiri di atasnya. Hero memakai glow putih di atas
  gradien emas; meter Rencana memakai glow `honey50` di atas kartu putih.
- **Kalimat Duit**: pil `surface` 82% di bawah panggung — satu kalimat
  pendek perasaannya ("Duit khawatir", "Duit senang", "Duit merayakan!").
  Mood tanpa render 3D (idle, sleepy) dilukis vektor sebagai Pochy yang
  sama — warna burlap/tali/syal/koin dari palet ADR-010.

## Motion

- Press scale 0,96 dengan curve **spring** (`Cubic(0.34,1.56,0.64,1)`,
  bounce ~6%), durasi 150–200ms.
- Transisi halaman: slide penuh dari kanan (`Offset(1, 0)` → nol) di
  semua platform via `QuestPageTransitionsBuilder`; saat back meluncur
  kembali ke kanan.
- Pindah tab navbar: slide berarah mengikuti urutan menu, 220ms
  (`QuestMotion.medium`) easeOut; tab lama diam di bawah (TickerMode),
  tab baru meluncur di atasnya. State bertahan via reparenting
  GlobalKey — tanpa bekuan citra (`_DirectionalTabView`).
- Bob maskot: sine 2400ms amplitudo 2% (aset raster: translate murni).
- Milestone/berubah level: perayaan singkat (stempel/konfeti) + haptic.
- Hormati `MediaQuery.disableAnimations` (reduced motion).

## Bahasa tulis

Kalimat aktif, sebut aksi nyata, kosakata konsisten antar layar
(tombol "Simpan" → snack "Tersimpan"). Error menjelaskan apa + cara
benar; empty state mengundang aksi ("Belum ada catatan — catat
transaksi pertamamu").

## Alur halaman (disepakati 2026-10-20, mockup 4 halaman)

- **Beranda**: header menyapa dengan Duit (leading 52); hero saldo —
  Duit berdiri di panggung (124) dengan pil kalimat, saldo + avatar mini
  akun (tap → Kelola Akun) di kiri; kartu pace "sisa aman hari ini" +
  chip streak; 3 transaksi terakhir (jembatan ke Rekap); insight
  sparkline + 3 kategori.
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
