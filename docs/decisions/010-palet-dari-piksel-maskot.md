# ADR-010: Palet diturunkan dari piksel maskot; tanpa dark mode

## Status
Diterima (2026-10-20).

## Konteks
Maskot Pochy (render 3D) menggantikan vektor v1. Gaya 3D toy/clay —
lighting, material empuk, syal teal-oranye, koin emas — butuh bahasa
desain yang sepadan; UI flat-pastel lama (ADR-008) terasa "nempel dari
planet lain". Pemeriksaan k-means atas 12.000 sampel piksel opak dari
4 gambar mood menemukan bahwa palet lama hampir seluruhnya bukan dari
karakter: honey `#FFB33E`/`#FFA726` persis token lama (koin asli
`#F1A23A`/`#C46913`), teal `#006A60` adalah `SeedColors.seed` lama
bukan syal (syal asli `#559F91`/`#216E5E`), dan hijau `good #1B873B`
tidak punya padanan satu pun di Pochy.

## Keputusan

1. **Palet v2.1 "Pastel Pochy"** — setiap token diturunkan dari piksel
   maskot, dari dua lapisan: tubuh karung (burlap `#E1BC94`/`#BF946F`,
   tali/mata `#3E2214`, koin `#F1A23A`, syal `#A4D1C9`/`#216E5E`,
   mulut `#AA3E0C`) dan bintang pastel mengambang (peach `#F6D0B0`,
   kuning muda `#FDF6BF`, mint `#A4D1C9`). Nilai resmi:
   - `bg #FBF5EC` · `surface #FFFDF9` · `surface2 #F6E9DA` ·
     `line #EDE0CE` · `ink #5B4433` · `muted #AD9680`
   - emas `#F9DCA8 → #E8B36B`, teks emas `#C08A3D`
   - aksen mint `#A4D1C9` / `#7FBDB1`, tint `#E6F2EF`, ink `#3E7A6D`
   - `good #4A8C7E` · `bad #B05530`
2. **Hijau `good` lama diganti teal/mint** — konvensi "hijau=in"
   ditinggalkan demi kesetiaan karakter; teal adalah warna syal Pochy.
3. **Tanpa dark mode** — satu-satunya tema. Konsekuensi: `QuestPalette`
   cukup satu konstanta, `QuestSchemes.dark()` dan `darkTheme` di
   `app.dart` dihapus, seluruh layar bebas dari percabangan brightness.
   Alasan: produk personal satu-perangkat, tema ganda melipatgandakan
   token & uji tanpa kebutuhan nyata; bila suatu saat dibutuhkan,
   tinjau ulang dari palet ini.

## Alternatif yang ditolak
Palet v2.1 penuh (kontras tinggi, emas pekat): lebih berani tapi
ramai; pastel terbukti lebih tenang untuk dipakai harian. Opsi "Senja
Peach": terlalu jauh dari karakter utama dan melemahkan kontras chip
status. Dark mode bertahan: ditolak — lihat keputusan 3.

## Konsekuensi
- Token warna hidup di `tokens.dart` (`SeedColors` v2.1); jangan ada
  warna hardcoded hex baru di layar.
- Palet 9 warna kategori TIDAK berubah (bahasa data, `colorIndex`);
  kecuali opsi ditinjau ulang terpisah.
- Maskot 3D tampil sama di semua konteks — tidak perlu varian tema.
