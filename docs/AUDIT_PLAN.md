# Rencana Audit Total — Bukuduit

Audit menyeluruh per aspek, dibasahkan ke struktur repo nyata (bukan
checklist generik): tiap butir punya target file dan metode verifikasi.
Urutan eksekusi disarankan: **A → C+D → B+E → F → G–K**. Output per
aspek: tabel temuan `[Kritis/Sedang/Rendah] + bukti + rekomendasi`.

## Temuan awal (terkonfirmasi saat penyusunan rencana)

1. `AndroidManifest.xml` tidak menyetel `android:allowBackup="false"`
   dan tidak punya `dataExtractionRules` — default `true`, sehingga DB
   dan antrian capture bisa naik ke backup cloud Google.
2. Tidak ada CI (`.github/` tidak ada) — 133 test hanya jalan lokal.
3. `capture_queue.jsonl` menampung notifikasi bank mentah dalam
   plaintext di disk sampai di-drain (perlu verifikasi retensi & mode).

## A. Keamanan & Privasi (prioritas 1 — app keuangan)

| # | Item audit | Target | Metode |
|---|---|---|---|
| A1 | SQLCipher benar-benar mengenkripsi: `PRAGMA key` sebelum operasi lain, `kdf_iter`, `cipher_use_hmac`, versi cipher | `lib/storage/database.dart`, hook `sqlite3: sqlcipher` di `pubspec.yaml` | Buka file DB dengan `sqlite3` polos → harus gagal `file is not a database`; cek `PRAGMA cipher_version` |
| A2 | Manajemen kunci: passphrase di `flutter_secure_storage` (Android Keystore), rotasi, perilaku saat keystore di-reset (clear data) — DB jadi brankas terkunci tanpa kunci? | Call-site `FlutterSecureStorage` | Review kode + uji clear data lalu jalankan app |
| A3 | Sisa plaintext di disk: antrian notifikasi mentah (nominal, pihak, saldo) tidak terenkripsi sampai drain. Cek path, mode file, retensi, ikut backup? | `NotificationCatcher.kt`, `lib/capture/pipeline.dart` | `adb shell run-as` / `ls -la` files dir; inspeksi isi file saat idle |
| A4 | Backup Android: set `allowBackup=false` / `dataExtractionRules` | `android/app/src/main/AndroidManifest.xml` | Review manifest (terkonfirmasi bermasalah) |
| A5 | Ekspor data: CSV `share_plus` = plaintext data keuangan; restore staging (ADR-006) — file staging terenkripsi/dihapus setelah selesai? | UI laporan/ekspor, `lib/storage/repository.dart` | Review + uji ekspor, cek sisa file |
| A6 | Tidak ada izin jaringan / analytics / log berisi isi notifikasi | Manifest (sudah dicek: bersih), `grep -rn "print(" lib/` | grep + review |
| A7 | Permukaan Android: listener terproteksi `BIND_NOTIFICATION_LISTENER_SERVICE`, tidak ada komponen `exported` lain, FLAG_SECURE untuk layar saldo | Manifest, `MainActivity.kt` | Review |

## B. Integritas Data & Kebenaran Logika

- **B1 Money**: `lib/core/money.dart` — parse "Rp1.234,56", koma dipotong
  ke bawah, batas int64, nominal 0/negatif ditolak.
- **B2 Periode `[start, end)`**: konsisten di budget, tren bucket,
  laporan; transaksi tengah malam & akhir bulan; timezone berubah.
- **B3 Saldo**: saldo awal + arah transaksi; hapus akun/kategori →
  fallback "Lainnya"; **draf tidak boleh masuk saldo/laporan**
  (klaim arsitektur — buktikan).
- **B4 Dedup ±120 detik** (ADR-005): raceless setelah commit
  `cf1570a` — uji dua notifikasi identik berselisih 119s/121s, dan
  lewat restart app (memori vs DB).
- **B5 Streak & mood**: dihitung ulang dari data asli (ADR-007) —
  pastikan tidak ada state tersimpan yang bisa drift; hari tanpa catat
  tidak memutus.
- **B6 Restore dua fase** (ADR-006): marker + restart, restore
  parsial/gagal, restore DB schema lama.

## C. Reliability Pipeline Capture

- **C1** Antrian file: baris korup dilewati, batas 1 MB/1000 baris
  benar dipangkas, tidak deadlock saat app dibunuh di tengah drain.
- **C2** EventChannel + drain saat start: notifikasi saat app mati
  tidak hilang; saat foreground tidak dobel (queue + event).
- **C3** Siklus hidup listener: Android membunuh service
  (doze/reboot/update) → auto-rebind `onListenerConnected`; permission
  dicabut user → UX pemberitahuan.
- **C4** Bank tidak terhubung diabaikan diam-diam — verifikasi
  benar-benar senyap tapi terdiagnosis (layar Diagnostik).

## D. Rules Engine

- **D1** Coverage seed rules per bank: kumpulkan notifikasi nyata per
  bank → ukur tingkat keberhasilan parse; false positive template
  `unknown`.
- **D2** Parsing nominal: "Rp 150.000", "150.000,00", "15rb";
  notifikasi promo bank harus TIDAK jadi draf.
- **D3** Loop re-parse capture log idempoten: parse ulang dua kali
  tidak menduplikasi draf; pangkasan log >30 hari jalan.

## E. Storage & Migrasi

- **E1** Migrasi v1→v10 self-heal: uji tiap versi perantara (fixture
  DB lama), kolom hilang dibuat ulang, downgrade ditolak dengan pesan
  jelas.
- **E2** Index pada kolom yang sering difilter (`transactions.time`,
  akun, kategori) — cek `database.dart` + `EXPLAIN QUERY PLAN`.
- **E3** `LedgerRepository` satu-satunya pintu data — grep akses drift
  di luar `lib/storage/` (harus kosong).

## F. Performa

- **F1** Startup dingin device kelas bawah: buka SQLCipher + migrasi
  `beforeOpen` memblokir first frame? `flutter run --trace-startup` /
  `adb shell am start -W`.
- **F2** Rebuild UI: layar besar (`laporan_screen.dart` 2471 baris,
  `home_cards` 1230, `rencana_batas` 1160) — stream disematkan
  (konvensiasi arsitektur), `const` widget, `ListView.builder` vs
  `Column` untuk transaksi panjang.
- **F3** Watch stream drift: 1 transaksi baru memicu berapa query
  ulang.
- **F4** Aset: ukuran `assets/mascot/` & font, ukuran APK, tree-shake
  ikon.

## G. Integrasi Android

- **G1** Target/min SDK vs kebutuhan `NotificationListenerService` &
  `share_plus`/`file_selector` (SAF, bukan path langsung) di
  Android 14+.
- **G2** Predictive back, edge-to-edge, dark mode + `dynamic_color`.
- **G3** Build release: signing, R8/minify, `--obfuscate`, tidak ada
  artefak debug bocor.

## H. UI/UX, Aksesibilitas, Lokalisasi

- **H1** String hardcoded vs `flutter_localizations` (dependensi ada —
  dipakai tidak?), `dates_id` konsisten.
- **H2** Semantics: label ikon, target sentuh ≥48dp, kontras warna
  kategori di chart, screen reader pada saldo yang bisa disembunyikan.
- **H3** Empty/error/loading state tiap layar; skeleton tidak berkedip
  antar-tab.
- **H4** Konsistensi design system Quest (`lib/theme/quest.dart`) —
  styling liar di luar tokens.

## I. Kualitas Kode & Maintainability

- **I1** Pecah file raksasa: `laporan_screen.dart`, `home_cards.dart`,
  `rencana_batas.dart` → widget per-section.
- **I2** Dead code: `lib/storage/seed_dummy.dart` (10KB di lib
  produksi) — pindah ke test/dev atau hapus; duplikasi `ui/quest.dart`
  vs `theme/quest.dart`.
- **I3** `flutter analyze` bersih; naikkan dari `flutter_lints` dasar
  (`prefer_const_constructors`, `unawaited_futures`, dsb.).

## J. Testing & CI

- **J1** Coverage gap: engine/repository/pipeline tertutup; UI nol
  widget test (keputusan terdokumentasi — audit pagar masih utuh,
  logika tidak bocor ke UI).
- **J2** Tidak ada integration test device nyata untuk alur capture
  end-to-end (notif → draf → konfirmasi → saldo).
- **J3** Bangun CI minimal: `flutter analyze` + `flutter test` per
  push (temuan awal #2).

## K. Dokumentasi & Kepatuhan

- **K1** Dokumen (ARCHITECTURE, DESIGN, ROADMAP, ADR 001–009) vs
  realitas kode — verifikasi klaim "133 test / schema v10" masih
  benar.
- **K2** Jika rilis Play Store: deklarasi NotificationListenerAccess
  (form data safety), UU PDP — klaim "data tidak keluar device" harus
  terbukti di A6.
