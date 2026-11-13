# CatatIn

Pencatat keuangan pribadi, offline-first, untuk Android. Transaksi dari
notifikasi aplikasi bank/e-wallet tertangkap otomatis lewat
`NotificationListenerService`, lalu dikurasi jadi transaksi lewat rules
per bank. Semua data tersimpan terenkripsi (SQLCipher) di perangkat:
tanpa server, tanpa akun, tanpa iklan.

## Fitur

Empat tab utama: **Beranda · Transaksi · Bon · Laporan**, dengan tombol +
kontekstual di tengah navbar.

- **Capture otomatis**: notifikasi bank/e-wallet → draf → rules per bank →
  transaksi final. Draf yang belum yakin masuk kotak masuk untuk kurasi
  manual (terima, abaikan sekali, atau abaikan polanya selamanya).
  Dedup: notifikasi ganda (push + SMS / resend) dengan bank, nominal, dan
  arah sama dalam ±120 detik hanya jadi satu transaksi.
- **Pindai struk**: foto struk/bukti dibaca OCR on-device (ML Kit), tanpa
  upload ke mana pun. Juga menerima share teks/gambar dari aplikasi lain.
- **Transaksi**: daftar dengan pencarian, filter akun & periode, dan
  ringkasan arus kas. Tap transaksi untuk ubah/hapus.
- **Laporan**: ringkasan arus kas, tren mingguan/bulanan, komposisi
  kategori, dan pengeluaran terbesar, untuk bulan pilihan atau rentang
  bebas.
- **Rencana (Batas)**: batas harian/mingguan/bulanan plus alokasi per
  kategori, bisa di-scope ke akun tertentu (mis. "Makanan @ e-wallet").
  Bisa dibuka dari Beranda atau Pengaturan.
- **Bon**: piutang/utang dengan aksi satu-tap "Lunasi"; bon tua lebih dari
  30 hari muncul sebagai badge di navbar.
- **Notifikasi**: pusat perhatian (izin mati, batas terlampaui, bon tua)
  dan tab tangkapan mentah untuk melatih rules.
- **CatatIn Quest**: maskot Pochy mencerminkan kondisi batas, streak
  disiplin dari data asli (milestone 3/7/14/21/30/60/100 hari).
- **Multi-akun**: bank, e-wallet, dan tunai; tiap akun punya saldo awal
  dan saldo berjalan.
- **Backup**: salinan database terenkripsi dengan PIN + restore. Kunci DB
  terikat perangkat (Keystore), jadi backup dari perangkat lain masuk lewat
  alur pemulihan.
- **Tema** terang/gelap mengikuti sistem; preferensi tersimpan.

## Izin yang dipakai

| Izin | Alasan |
|---|---|
| Notification access | Membaca notifikasi bank/e-wallet sebagai sumber transaksi. Fitur inti; tidak ada notifikasi lain yang dipakai selain untuk draf. |
| `CAMERA` | Foto struk/bukti untuk OCR on-device. |
| `POST_NOTIFICATIONS` | Menampilkan peringatan batas lokal (bukan notifikasi pemasaran). |
| `INTERNET` | Dibawa dependensi ML Kit. Kode aplikasi sendiri tidak melakukan panggilan jaringan: dependensinya tanpa HTTP client, tanpa Firebase, tanpa analytics. |

## Menjalankan

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generate drift
flutter run                                   # atau: flutter build apk
```

Butuh Flutter yang menyediakan Dart SDK `^3.12.1` (lihat `pubspec.yaml`)
dan Android SDK.

Alur pertama kali: Pengaturan → **Catat otomatis** → *Mulai* → baca
disclosure → "Saya mengerti" → centang CatatIn di *Notification access*
Android. Untuk melihat aplikasi hidup tanpa data asli, Pengaturan menyediakan
**Isi Data Contoh** (hanya build debug).

## Uji notifikasi via adb

`scripts/test_capture.sh` menembakkan notifikasi simulasi ke device lewat
`BroadcastReceiver` bawaan (khusus build debug), tanpa transfer uang asli:

```bash
./scripts/test_capture.sh blu      # preset blu by BCA
./scripts/test_capture.sh nagari   # preset Bank Nagari / Ollin
./scripts/test_capture.sh guard    # negatif: OTP/promo harus ditolak
./scripts/test_capture.sh send --pkg com.bca --title "t" --body "b"
```

Seed rules (`assets/rules/seed_rules.json`) disusun dari format umum dan
belum tervalidasi dengan notifikasi asli semua bank. Cara tuning: lakukan
satu transaksi kecil, buka **Catat otomatis → Perawatan**, sesuaikan
`matchAll`/`matchAny`/`counterparty`/`amount` di rules, lalu tap *baca
ulang* untuk memproses ulang notifikasi mentah tanpa transaksi baru.

## Struktur

| Path | Isi |
|---|---|
| `lib/capture/` | MethodChannel/EventChannel native + pipeline capture → parse → simpan |
| `lib/rules/` | Rules engine + format rule (`assets/rules/seed_rules.json`) |
| `lib/storage/` | Drift (SQLCipher) schema + repository, dedup 120 detik |
| `lib/notify/` | Channel notifikasi lokal + peringatan batas |
| `lib/ui/` | Shell 4 tab: Beranda, Transaksi, Bon, Laporan; Pengaturan, Rencana, Bon, pindai struk, dan sheet pendukung |
| `lib/game/` | Maskot, streak, progres quest |
| `lib/theme/` | Sistem desain Quest (Slate-Indigo, bukan default Material) |
| `android/.../MainActivity.kt` | `MainActivity`, `NotificationCatcher`, `NotificationSimulatorReceiver` |
| `scripts/` | Injeksi notifikasi simulasi via adb |

## Dokumentasi

- [Arsitektur](docs/ARCHITECTURE.md): peta lapisan, alur capture, model data, konvensi.
- [Desain visual](docs/DESIGN.md): sistem Slate-Indigo, token, komponen.
- [Roadmap](docs/ROADMAP.md).
- [Audit keamanan](docs/AUDIT_REPORT.md): temuan dan status perbaikannya.
- [Keputusan desain (ADR)](docs/decisions/).
- [Arsip perencanaan](docs/internal/): mockup dan rencana kerja lama.

## Lisensi

[MIT](LICENSE).
