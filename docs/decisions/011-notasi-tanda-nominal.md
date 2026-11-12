# ADR-011: Tanda arah nominal digambar minimalis (bukan seberat angka)

## Status

Diterima (2026-11-12).

## Konteks

Hero "Net Arus Kas" di Laporan menampilkan `−Rp840.000`: tanda minus
U+2212 digambar dengan ukuran & bobot penuh (`qDisplay` = w900 / 28px)
sehingga menjadi elemen paling dominan di layar, bukan angkanya. Hal ini
melanggar prinsip "Angka adalah Raja" (ADR-008, docs/DESIGN.md).

Masalahnya diperparah oleh tiga hal:

1. **Tidak konsisten** — campur ASCII hyphen `-` (`Money.format`), U+2212
   `−` (`QuestAmount`, Laporan), dan prefiks `+`/`-` manual (ringkasan
   arus kas, pace harian, header harian). Satu nominal bisa tampil dengan
   dua bentuk tanda berbeda tergantung layar.
2. **Tanda `+` suffer hal sama** — `+Rp4.250.000` di ringkasan arus kas
   dan kartu tren juga full-weight.
3. **Glyph salah pilih** — ASCII hyphen pendek dan menggantung di atas
   huruf; U+2212 lebarnya sepadan digit dan duduk di sumbu matematika.

Alternatif yang sempat dipertimbangkan: kurung akuntansi `(Rp840.000)`,
panah arah `↓`, tanda di belakang `Rp840.000−`, atau tanpa tanda sama
sekali (warna + label). Semuanya mengganti simbol yang sedang
dikeluhkan, bukan memperbaikinya. Keputusan: **tanda tetap ada, tapi
turun kelas visual** menjadi marker subordinat.

## Keputusan

1. **Satu sumber kebenaran** — semua nominal bertanda dirender lewat
   `QuestMoney` (`lib/theme/quest.dart`) dengan parameter `MoneyTone`
   (`lib/core/money.dart`). Arah lewat `MoneyTone.incoming/outgoing`;
   tanpa tone, tanda mengikuti tanda nilai nominal (negatif = `−`).
   Prefiks `+`/`−` manual di call site dilarang.

2. **Glyph U+2212** — `Money.format` (string data) memakai U+2212 yang
   sama supaya satu nominal tidak pernah punya dua bentuk tanda.

3. **Treatment "minimalis"** (`QuestSignStyle`):

   | Aspek | Nilai |
   |---|---|
   | Ukuran tanda | 62% ukuran angka (80% bila angka < 16px) |
   | Bobot tanda | 1 tingkat lebih ringan (tangga bundel w400→w600→w700→w800) |
   | Opasitas tanda | 55% warna angka (65% untuk nominal kecil) |
   | Posisi | dinaikkan 0.18 em dari baseline |
   | Jarak | 0.05 em |

   Angka & bobot berasal dari pengukuran metrik glyph Nunito yang dipakai
   app: center vertikal digit `0` = +0.3525 em, center `−` U+2212 =
   +0.2870 em, center `+` = +0.2840 em. Tanpa kompensasi, tanda pada
   62% ukuran duduk 0.175 em di bawah tengah digit dan terbaca meleset;
   karena itu dinaikkan tepat sebesar selisih tersebut.

   Nominal kecil (< 16px) dapat perlakuan lebih ringan karena bar tanda
   akan tipis dari 1px dan hilang kalau diterjemahkan opacity.

4. **Tanda terpisah dari angka** — `QuestMoney` merakit `Row`
   (baseline-aligned) berisi teks awalan, tanda, lalu nominal, dengan
   `Transform.translate` untuk kompensasi optik. `Transform` bersifat
   paint-time sehingga tidak mengubah layout.

5. **Angka absolut** — `Money.formatAbs` untuk tampilan; `Money.format`
   tetap tersedia untuk string data (Semantics, pesan, pencarian).

## Konsekuensi

- **Positif**: satu bahasa tanda di seluruh app; angka kembali jadi fokus;
  glyph minus & plus konsisten dengan tipografi app.
- **Test**: `QuestMoney` kini merakit beberapa `Text`, bukan satu string,
  sehingga `find.text('+Rp4.000.000')` tidak lagi cocok — assertion
  dipecah menjadi tanda & nominal (`test/transaksi_virtualization_test.dart`).
  Finder di `test/stacked_hero_cards_test.dart` dikunci ke
  `TotalBalanceCard` supaya ikut animasi kartu peek tidak menggeser
  hitungan.
- **Aksesibilitas**: `Row` berisi beberapa `Text` dibaca TalkBack sebagai
  node terpisah (tanda lalu nominal) — masih wajar, karena keduanya
  berdekatan. Label `Semantics` eksplisit pada `TransactionTile` tetap
  memuat nominal utuh.
- **Keterbatasan**: kompensasi optik terikat metrik Nunito. Bila font
  diganti, `QuestSignStyle._digitCenterEm` & `_signCenterEm` harus
  diukur ulang.
