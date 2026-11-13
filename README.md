# CatatIn

Pencatat keuangan pribadi, **offline-first**, Android. Transaksi dari push
notifikasi aplikasi bank/e-wallet tertangkap otomatis via
`NotificationListenerService`; semua data tersimpan terenkripsi (SQLCipher)
di perangkat, tanpa server.

Rancangan lengkap: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) ·
[docs/ROADMAP.md](docs/ROADMAP.md) · [docs/decisions/](docs/decisions/)

## Fitur

Navigasi utama 4 tab: **Beranda · Rekap · Rencana · Bon**, dengan tombol +
kontekstual per tab (tengah navbar; tanpa FAB melayang di tab Rencana) dan
header global (lonceng capture + menu) di semua tab.
- **Catat manual**: tombol Catat / FAB kontekstual — nominal, arah
  masuk/keluar, kategori (+ tambah kategori), jenis, tanggal, akun,
  dan pihak/keterangan. Tap transaksi untuk ubah/hapus.
- **Capture otomatis**: notifikasi bank/e-wallet → parser rules per bank →
  kategori + akun otomatis (blu → blu by BCA, nagari → Bank Nagari).
  Satu layar pengaturan utuh di **Menu ⋯ → Catat otomatis**: status izin,
  hubungkan/matikan bank, baca ulang notifikasi mentah, pengaturan baterai.
- **Akun**: blu by BCA, Bank Nagari, Tunai (bawaan) + tambah sendiri
  (layar Menu ⋯ → *Bank & akun*). Tiap akun punya saldo awal + saldo
  berjalan (`awal + masuk − keluar`).
- **Bon**: tab utang-piutang — tambah/edit, tandai lunas, total piutang
  vs utang belum lunas.
- **Rekap** (4 segmen): **Transaksi** (cari + filter akun & periode),
  **Donat** (kategori interaktif, statistik keluar murni — transfer
  tidak dihitung), **Tren** (mingguan/bulanan), dan **Kalender**
  (aktivitas per hari, rentang bebas).
- **Rencana**: **Batas** — batas harian/mingguan/bulanan +
  alokasi per jenis anggaran, bisa di-scope ke akun tertentu (mis.
  "Makanan @ e-wallet"), progres vs bulan lalu.

- **CatatIn Quest**: maskot Duit mencerminkan kondisi batas — khawatir
  saat terlampaui, tenang saat aman. **Streak disiplin** menghitung
  hari berturut jaga batas dari data asli (milestone 3/7/14/21/30/60/
  100 hari).
- **Backup**: ekspor CSV + backup `.sqlite` terenkripsi (simpan
  passphrase terpisah!) + restore.

## Menjalankan

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generate drift
flutter run                                  # atau: flutter build apk
```

Alur pertama kali: Menu ⋯ → **Catat otomatis** → tombol *Mulai* → baca
disclosure → "Saya mengerti" → beri centang CatatIn di *Notification
access* Android — sambungan bank lanjut otomatis begitu kembali.

## Capture & tuning rules

Seed rules (`assets/rules/seed_rules.json`) disusun dari format umum,
**belum divalidasi dengan notifikasi asli** blu/Bank Nagari (jadwal:
roadmap M3). Cara tuning:

1. Lakukan satu transaksi kecil (mis. transfer Rp1.000 antar-rekening
   sendiri).
2. Buka **Menu ⋯ → Catat otomatis** — bagian *Perawatan* menunjukkan
   jumlah notifikasi yang belum terbaca; tombolnya membaca ulang semuanya.
3. Sesuaikan `matchAll`/`matchAny`/`counterparty`/`amount` di rules →
   hot restart (`R` di sesi `flutter run`) → tap **baca ulang** di bagian
   *Perawatan*, tanpa transaksi ulang.
4. `packageName` blu (`com.bcadigital.blu`) sudah tervalidasi dari
   capture nyata; lengkapi `packageNames` Bank Nagari saat notifikasinya
   tertangkap.

Dedup: notifikasi ganda (push+SMS / resend) dengan bank+nominal+arah
sama dalam ±120 detik hanya jadi satu transaksi.

## Struktur

| Path | Isi |
|---|---|
| `lib/rules/` | Rules engine + seed rules (`assets/rules/seed_rules.json`) |
| `lib/capture/` | Channel native + pipeline capture→parse→simpan |
| `lib/storage/` | Drift schema v8 + repository (dedup 120 detik) |
| `lib/ui/` | Shell 4 tab (Beranda, Rekap, Rencana, Bon) + sheet transaksi, catat otomatis (pengaturan capture), bank & akun, backup, menu |
| `lib/game/` | Maskot, hero card, streak & mood |
| `lib/theme/` + `lib/ui/quest.dart` | Sistem desain Quest (bukan default Material) |
| `android/.../MainActivity.kt` | MethodChannel/EventChannel + `NotificationCatcher` |
| `docs/` | Arsitektur, roadmap, keputusan desain (ADR) |
