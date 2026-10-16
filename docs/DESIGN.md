# Design System Bukuduit — "Playful Rapi"

Arah visual yang disepakati (2026-10-11): **hangat & playful yang rapi** —
kelezatan datang dari warna, radius lembut, dan maskot; **bukan** dari border
tebal dan hard shadow (gaya papan lama dihapus). Dokumen ini satu sumber
kebenaran visual; widget-kit hidup di `lib/ui/quest.dart` + `lib/theme/`.

## Prinsip

1. **Duit adalah meter, kategori adalah bahasa.** Ekspresi maskot selalu
   mencerminkan kondisi anggaran nyata (ADR-007); warna kategori membawa
   informasi di seluruh app — bukan dekorasi.
2. **Angka adalah raja.** Angka besar, tabular, kontras tinggi. Dekorasi
   tidak boleh menurunkan keterbacaan angka.
3. **Lembut, bukan tebal.** Pemisahan via kontras warna + bayangan lembut.
   Tanpa border tebal, tanpa hard shadow.
4. **Satu kartu = satu ide.** Maksimal satu zona hero per layar.

## Palet (light)

| Token | Nilai | Pakai |
|---|---|---|
| `bg` | `#FFF8EE` | latar app |
| `surface` | `#FFFFFF` | kartu, sheet |
| `surface2` | `#FFF3DC` | tint zone hero, chip lembut |
| `ink` | `#33302B` | teks utama |
| `muted` | `#A39A88` | teks sekunder |
| `honey` | `#FFB33E` | aksen brand |
| `honeyDeep` | `#FFA726` | ujung gradient tombol utama |
| `honeyInk` | `#8A6420` | teks di atas madu |
| `good` | `#1B873B` | masuk, status aman |
| `bad` | `#B3392E` | keluar, OVER |
| `line` | `#EFE6D4` | garis sekunder halus (bukan border kartu) |

Dark: `bg #241F1C` · `surface #2E2823` · `surface2 #3A322B` · `ink
#F7EFE2` · `muted #B9A98F` · honey & palet kategori tetap · bayangan
diganti kontras surface (elevation minimal).

Bahasa kategori: palet 9 warna existing (`SeedColors.categoryPalette`,
diindeks `Categories.colorIndex`) — dipakai untuk dot transaksi, donut,
chip kategori, dan garis chart. Warna kategori **tidak** dipakai di luar
konteks kategorinya.

## Tipografi — Nunito (file TTF dibundel offline via `fonts:` di
`pubspec.yaml`; package `google_fonts` tidak dipakai)

| Peran | Ukuran/berat | Pakai |
|---|---|---|
| Display angka | 30–40 / 800, `tabularFigures` | sisa aman, saldo, total |
| Judul | 17–20 / 800 | judul kartu, layar |
| Body | 14–15 / 400–600 | konten |
| Kecil | 12–13 / 600 | meta, subjudul |
| Eyebrow | 10,5 / 800, uppercase, letter-spacing 1,6 | label seksi |

Angka selalu `FontFeature.tabularFigures()`. Jangan campur font lain.

## Bentuk & elevasi

- Radius: kartu **20**, tile **18**, bingkai kontrol **22**, sheet
  **24**, sel kecil **12**, tombol & chip/pill **999** (`AppRadius`;
  tombol utama memakai pill).
- Elevation (satu-satunya mekanisme pemisah):
  - kartu: `0 6px 18px rgba(80,60,20,.07)`
  - elemen melayang (nav): `0 10px 26px rgba(80,60,20,.14)`
  - FAB/utama: glow honey `0 8px 18px rgba(255,167,38,.45)`
- **Dilarang**: border tebal 2–3px, hard shadow offset, outline ganda.
- Spacing: grid `4 / 8 / 16 / 24 / 32` (existing `Spacing`).

## Komponen

- **Kartu**: `surface`, radius 20, shadow kartu, padding 14–16.
- **Zona hero**: gradient tint `#FFF3DC → #FFE7B8`, radius 24, maskot +
  angka display. Satu per layar.
- **Tombol utama**: gradient `#FFC94D → #FFA726`, teks putih 800,
  radius 16. Sekunder: `surface2` teks ink. Teks tombol = aksi nyata
  ("Simpan", bukan "OK").
- **Chip/pill**: `surface2`, radius 999, teks 600.
- **Tile transaksi**: kartu putih, dot kategori 10px, nama 700, meta
  kecil muted, nominal tabular berwarna arah.
- **Nav melayang**: putih radius 22, shadow nav, FAB gradient honey
  menonjol ke atas.
- **Maskot Duit**: ukuran 48 (chip/inline), 64 (hero), 96 (perayaan/
  empty state). Ekspresi = fungsi kondisi nyata. Tidak menempel di
  setiap kartu.

## Motion

- Press scale 0,96 (`QuestMotion.pressScale`), durasi 150–200ms, curve
  easeOut.
- Transisi halaman: slide penuh dari kanan (`Offset(1, 0)` → nol,
  curve `QuestMotion.easeOut`) di semua platform via
  `QuestPageTransitionsBuilder`; saat back meluncur kembali ke kanan.
- Milestone/berubah level: perayaan singkat (stempel/konfeti) + haptic.
- Hormati `MediaQuery.disableAnimations` (reduced motion).

## Bahasa tulis

Kalimat aktif, sebut aksi nyata, kosakata konsisten antar layar
(tombol "Simpan" → snack "Tersimpan"). Error menjelaskan apa + cara
benar; empty state mengundang aksi ("Belum ada catatan — catat
transaksi pertamamu").

## Checklist migrasi (dari tema lama → Playful Rapi) — selesai

1. `pubspec.yaml`: ~~tambah `google_fonts`~~ — tidak jadi dipakai;
   file TTF Nunito dibundel langsung via `fonts:`. Set `TextTheme`
   Nunito di `QuestSchemes`.
2. `theme/tokens.dart`: tambah `honeyDeep`, `honeyInk`, `line`, gradient
   hero; nilai `bg` → `#FFF8EE`.
3. `ui/quest.dart`: `QuestCard` hapus border+hard shadow → radius 20 +
   shadow lembut; `QuestButton` utama → gradient; chip → 999 + tint;
   nav → putih melayang; eyebrow/tipografi → skala Nunito.
4. ~~Layar beranda dulu … layar push~~ — direvisi di tengah jalan:
   layar lama (Riwayat/Laporan/Anggaran) dipensiunkan, diganti shell
   4 tab (Beranda · Rekap · Rencana · Bon) + layar Menu.
5. Dark mode disesuaikan di setiap langkah, bukan di akhir.
