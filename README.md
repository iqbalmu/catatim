# Bukuduit

Pencatat keuangan pribadi, **offline-first**, Android. Transaksi dari push
notifikasi aplikasi bank/e-wallet tertangkap otomatis via
`NotificationListenerService`; semua data tersimpan terenkripsi (SQLCipher)
di perangkat, tanpa server.

## Arsitektur

```
Notifikasi bank (push)
  └─ NotificationCatcher (Kotlin, transport saja — JSON mentah)
       ├─ antrian file (capture_queue.jsonl)   ← tidak hilang saat app mati
       └─ EventChannel → Dart
            └─ CapturePipeline
                 └─ RuleEngine (template JSON per bank)
                      ├─ terkenali → dedup → SQLite (Drift + SQLCipher)
                      └─ tidak     → Capture Log (mentah, untuk tuning)
```

Prinsip: **lapisan native hanya transport**, seluruh logika (parser, dedup,
penyimpanan) di Dart — unit-testable tanpa device.

## Fitur

- **Catat manual**: tombol Catat / FAB kontekstual — nominal, arah
  masuk/keluar, kategori (+ tambah kategori), jenis, tanggal, akun,
  dan pihak/keterangan. Tap transaksi untuk ubah/hapus.
- **Capture otomatis**: notifikasi bank/e-wallet → parser rules per bank →
  kategori + akun otomatis (blu → blu by BCA, nagari → Bank Nagari).
- **Akun**: blu by BCA, Bank Nagari, Tunai (bawaan) + tambah sendiri.
  Kelola (tambah/ubah/hapus) di menu Beranda → *Kelola akun* atau tautan
  *Kelola* di sheet filter Riwayat; filter akun murni memfilter. Tiap
  akun punya saldo awal + saldo berjalan (`awal + masuk − keluar`).
  Sheet transaksi punya picker akun.
- **Bon**: tab utang-piutang — tambah/edit, tandai lunas, total piutang
  vs utang yang belum lunas. Murni lokal, tanpa pengingat server.
- **Anggaran**: alokasi dana per jenis anggaran — bisa di-scope ke akun
  tertentu (mis. "Makanan @ e-wallet") atau berlaku global — plus batas
  harian/mingguan/bulanan (menu Beranda → *Anggaran*). Jenis anggaran
  bisa ditambah/diubah/dihapus; transaksi di jenis yang dihapus pindah
  ke "Lainnya". Progres masuk/keluar dibanding bulan lalu dengan
  penilaian membaik/memburuk.
- **Bukuduit Quest**: maskot Duit merepresentasikan kondisi anggaran —
  khawatir saat batas terlampaui, tenang saat aman. Streak mencatat
  dari data asli (milestone 3/7/14/21/30/60/100 hari).
- **Laporan**: donut kategori interaktif + tren sesuai periode (bulan
  terpilih atau rentang tanggal).
- **Backup**: ekspor CSV + backup `.sqlite` terenkripsi (simpan
  passphrase terpisah!) + restore.

## Struktur

| Path | Isi |
|---|---|
| `lib/rules/` | Rules engine + seed rules (`assets/rules/seed_rules.json`) |
| `lib/capture/` | Channel native + pipeline capture→parse→simpan |
| `lib/storage/` | Drift schema v6 + repository (dedup 120 detik) |
| `lib/ui/` | Beranda, Laporan, Bon, capture log, backup |
| `lib/game/` | Maskot, hero card, streak & mood |
| `lib/theme/` + `lib/ui/quest.dart` | Sistem desain Quest (bukan default Material) |
| `android/.../MainActivity.kt` | MethodChannel/EventChannel + `NotificationCatcher` |

## Menjalankan

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generate drift
flutter run                                  # atau: flutter build apk
```

Alur pertama kali: buka ikon notifikasi di AppBar → baca disclosure →
"Saya mengerti" → beri centang Bukuduit di *Notification access* Android.

## ⚠️ Seed rules = titik awal, bukan final

Pola di `assets/rules/seed_rules.json` disusun dari format umum, **belum
divalidasi dengan notifikasi asli** blu by BCA / Bank Nagari. Validasi:

1. Lakukan satu transaksi kecil (mis. transfer Rp1.000 antar-rekening sendiri).
2. Buka **Capture log** — notifikasi mentah muncul dengan badge `Tercatat`
   (berhasil) atau ikon ⟳ (gagal parse). Tap baris untuk melihat teks
   mentah lengkap.
3. Sesuaikan `matchAll`/`matchAny`/`counterparty`/`amount` di seed rules
   dengan teks asli → hot restart (`R` di sesi `flutter run`) → tap ikon
   **⟳ Parse ulang** pada entri lama — tanpa perlu transaksi ulang.
4. `packageName` asli blu (`com.bcadigital.blu`) sudah divalidasi dari
   capture nyata; lengkapi `packageNames` Bank Nagari dari capture log
   saat notifikasinya tertangkap.

Dedup: notifikasi ganda (bank kirim dua kali / push+SMS) dengan bank+nominal+
arah sama dalam ±120 detik hanya jadi satu transaksi.

## Play Store (checklist)

- [x] Prominent disclosure in-app sebelum minta akses notifikasi
      (`lib/ui/capture_log_screen.dart`) — syarat kebijakan User Data.
- [ ] Privacy policy URL (wajib saat publish).
- [ ] Form *Data safety*: klaim "data tidak dikumpulkan/dibagikan" valid
      karena semua lokal.
- [ ] Akun developer personal baru: wajib closed testing (12 tester, 14 hari)
      sebelum production.

## Catatan risiko

- Enkripsi via SQLCipher dibundel lewat hook native assets
  (`hooks.user_defines.sqlite3.source: sqlcipher` di pubspec.yaml — mekanisme
  `sqlite3` ≥3.x; package `sqlcipher_flutter_libs` lama sudah no-op/EOL).
  Verifikasi cepat di device: `SELECT count(*) FROM pragma_cipher_version`
  harus ≥ 1.
- Akses notifikasi hanya aktif selama user memberi izin; dicabut kapan saja
  di Pengaturan → Akses notifikasi.
