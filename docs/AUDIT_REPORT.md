# Laporan Audit — CatatIM

Temuan per aspek rencana [`AUDIT_PLAN.md`](AUDIT_PLAN.md).
Severity: **Kritis** (eksploitasi langsung merugikan) / **Sedang** (perlu
kondisi tertentu) / **Rendah** (hardening) / **✓ Lolos** (terverifikasi aman).

## A. Keamanan & Privasi — 2026-10-31

Verifikasi runtime dilakukan di emulator-5554 (Android 15), app debug
`versionName=1.0.0`, via `adb run-as`.

### Ringkasan

| ID | Temuan | Severity |
|---|---|---|
| A-01 | `allowBackup` aktif (default) — DB + antrian plaintext bisa naik ke cloud backup Google | Sedang — **diperbaiki** |
| A-02 | Semua notifikasi SEMUA app ditulis plaintext ke `capture_queue.jsonl`, tanpa batas waktu | Sedang — **diperbaiki** |
| A-03 | Backup dikunci PIN 4 digit — 10.000 kombinasi, brute force offline feasible | Sedang — **diperbaiki** |
| A-04 | DB terverifikasi terenkripsi SQLCipher | ✓ Lolos |
| A-05 | Tidak ada izin jaringan/analytics, tidak ada log payload | ✓ Lolos |
| A-06 | Passphrase hilang (Keystore reset / restore antar device) → crash generik tanpa UX pemulihan | Rendah — **diperbaiki** |
| A-07 | Tidak ada `FLAG_SECURE` — saldo tersembunyi tetap tercetak screenshot/screen-record | Rendah — **risiko diterima** (keputusan user 2026-10-31) |
| A-08 | Salinan backup tersisa di cache setelah share | Rendah — **diperbaiki** |
| A-09 | `buildCsv()` (ekspor plaintext) dead code — tak dipanggil UI mana pun | Info |
| A-10 | `SharePlus.share()` tak pernah selesai bila sheet ditutup BACK → `_busy` menancap & snackbar tak muncul (bug pra-ada, terungkap saat uji) | Rendah — **diperbaiki** |
| A-11 | Rekey backup→PIN gagal senyap (closure unsendable di `Isolate.spawn`) — file backup TIDAK pernah terkunci PIN & tak bisa dipulihkan | **Kritis — diperbaiki** (ditemukan saat uji A-06) |

### Detail & bukti

**A-01 allowBackup aktif.**
`AndroidManifest.xml` `<application>` tidak menyetel
`android:allowBackup="false"` maupun `dataExtractionRules`. Terkonfirmasi
runtime: `dumpsys package` → `flags=[ … ALLOW_BACKUP ]`. Akibat: (a) file
`capture_queue.jsonl` plaintext bisa tersinkron ke backup cloud Google;
(b) restore data ke perangkat baru memulihkan DB tapi TIDAK passphrase
(Android Keystore tidak ikut pindah) → DB hasil restore terkunci
(berkaitan dengan A-06).
*Rekomendasi:* `android:allowBackup="false"` + `dataExtractionRules`
mengecualikan semuanya. Konsisten dengan model "tanpa cloud" — jalur
backup resmi sudah ada (file PIN, A-03).
*Diperbaiki 2026-10-31:* `android:allowBackup="false"` ditambahkan;
terverifikasi `dumpsys` → flag `ALLOW_BACKUP` hilang setelah reinstall.

**A-02 Antrian notifikasi plaintext tanpa batas waktu.**
`NotificationCatcher.onNotificationPosted` menulis SETIAP notifikasi
non-ongoing dari SEMUA app ke `files/capture_queue.jsonl` — filter bank
terhubung baru terjadi di Dart saat drain. Terbukti runtime: notifikasi
uji dari `com.android.shell` langsung muncul di file:

```
{"packageName":"com.android.shell","title":"BCA","body":"tagtest","postedAt":1793433389357}
```

Artinya OTP, preview chat, email ikut tersimpan plaintext. Pereda:
mode `0600` app-private (terverifikasi), kap 1 MB/1000 baris,
dihapus saat app berikutnya start. Risiko sisa: bertahan tanpa batas
selama app tidak dibuka; dapat dibaca forensic/backup (lihat A-01).
*Diperbaiki 2026-10-31 (opsi allowlist paket):* Dart mendorong daftar
paket bank terhubung ke native (`syncAllowedPackages`); antrean disk
hanya menerima paket dalam daftar + paket yang dipelajari dari
keyword-match (`learnBankPackage`, persist di SharedPreferences).
OTP/chat kini tak pernah menyentuh disk. Sink live tetap penuh agar
pencocokan keyword jalan. ADR-001 diamandemen. Terverifikasi runtime
di emulator: (1) notifikasi non-bank → antrean tetap kosong; (2)
notifikasi keyword-bank dari paket asing → paket tercatat di
`learned_packages`, belum diantrikan; (3) notifikasi berikutnya dari
paket yang sama → masuk antrean. Risiko sisa: app jahat memalsukan
keyword agar paketnya dipelajari — dampak terbatas junk antrean
(kap 1 MB), bukan kebocoran.

**A-03 PIN backup 4 digit.**
`backup_screen.dart` — PIN 4–12 angka, minimum 4 (`pin.length < 4`
ditolak). File backup = DB penuh terenkripsi SQLCipher kunci PIN;
4 digit = 10⁴ kombinasi. KDF default SQLCipher 4 (PBKDF2-SHA512
256.000 iter) memperlambat, tapi file backup memang didesain disimpan
di luar device (share sheet) → serangan offline realistis.
*Rekomendasi:* minimum 6 digit, atau tampilkan peringatan kelemahan
pada 4–5 digit.
*Diperbaiki 2026-10-31:* minimum 6 digit + snack "PIN minimal 6
angka."; snack "PIN tidak sama" yang tadinya kode mati kini benar
dijalankan. Terverifikasi runtime: PIN 4 digit ditolak, 6 digit lolos.

**A-04 Enkripsi DB terverifikasi.** ✅
Header file DB acak (bukan `SQLite format 3`), dan `sqlite3` polos
gagal: `Error: file is not a database (26)`. `PRAGMA key` dijalankan
di `setup:` sebelum akses pertama (`database.dart:358-369`). Passphrase
32 byte acak (256-bit) `Random.secure`, sekali dibuat, tersimpan
`flutter_secure_storage` (Android Keystore). Interpolasi
`PRAGMA key = '$passphrase'` aman: charset hex-only.
Default SQLCipher 4 (tanpa override `kdf_iter`/`cipher_use_hmac`) —
standar baik.

**A-05 Tanpa jaringan & log bersih.** ✅
Manifest: tidak ada `INTERNET` maupun izin lain; service listener
terproteksi `BIND_NOTIFICATION_LISTENER_SERVICE` (signature, hanya
sistem). `grep print(/debugPrint` di `lib/` dan `Log./println` di
Kotlin: nol.

**A-06 Passphrase reset tanpa UX.**
`_passphrase()` (`database.dart:371-382`): baca gagal/kosong → buat
baru. Skenario Keystore reset saat data utuh (mis. restore A-01):
passphrase baru ≠ kunci DB lama → drift melempar di `main()` → app
gagal start dengan error generik, tanpa pesan "data terkunci,
pulihkan dari backup PIN". Jalur pemulihan ada (layar Backup) tapi
user tidak diarahkan ke sana.
*Diperbaiki 2026-10-31:* deteksi `isDatabaseLocked()` di `main()` →
layar "Data terkunci" (`CatatIMLockedApp`) dengan dua jalan:
"Pulihkan dari backup" (alur restore dipindah ke
`restore_flow.dart`, reusable) atau "Mulai dari awal" (hapus DB,
konfirmasi destruktif). Terverifikasi E2E di emulator: hapus kunci →
layar terkunci muncul → pulihkan file PIN → data lama kembali utuh.

**A-07 Tanpa FLAG_SECURE.**
UI punya toggle sembunyikan saldo, tapi `MainActivity`/`styles.xml`
tidak menyetel `FLAG_SECURE` — screenshot & screen recording tetap
menangkap nominal terlihat. *Risiko diterima* (keputusan user
2026-10-31): memblokir screenshot juga melarang screenshot laporan
yang legit. Proteksi toggle dipahami kosmetik.

**A-08 Sisa file backup di cache.**
`_backup()` menyalin DB ke `cache/CatatIM-backup-*.sqlite`, share,
tanpa menghapus. File terenkripsi (bukan plaintext) jadi risiko
rendah, tapi menetap selamanya di cache. *Rekomendasi:* hapus setelah
share selesai / sebelum membuat baru.
*Diperbaiki 2026-10-31:* dua lapis — (1) salinan lama dihapus
proaktif di awal `_backup()`; (2) hapus pasca-share bila `share()`
benar-benar complete. Terverifikasi runtime: 2 file lama terhapus saat
backup baru dibuat.

**A-09 `buildCsv()` dead code.**
Hanya direferensikan test (`repository_test.dart:168`), tidak ada UI
yang memanggil — ekspor plaintext memang tidak diekspos. Bagus untuk
privasi; pindahkan/hapus saat audit I (dead code).

**A-10 `share()` tak selesai saat sheet ditutup BACK.**
Saat uji A-08 di emulator Android 15: menutup share sheet dengan BACK
tidak menyelesaikan future `SharePlus.instance.share()` — file tidak
terhapus pasca-share (sehingga lapis 1 di A-08 diperlukan), snackbar
"Backup tersimpan" tak pernah muncul, dan `_busy` tetap `true`
(layar Backup tertinggal nonaktif bila user kembali ke sana). BACK
juga sekaligus mem-pop route Backup.
*Diperbaiki 2026-10-31:* `WidgetsBindingObserver.didChangeAppLifecycle`
mereset `_busy` saat app kembali aktif. Smoke runtime: setelah sheet
ditutup BACK, tombol "Simpan datamu" langsung merespons lagi.

**A-11 Rekey backup gagal senyap — file tidak pernah terkunci PIN.**
Ditemukan saat uji E2E A-06. `NativeDatabase.createInBackground(setup:)`
di dalam fungsi async yang konteksnya memuat `BuildContext`/State
membuat `Isolate.spawn` melempar "object is unsendable
(_AsyncCompleter)" — logcat 15:08 membuktikan hal yang sama terjadi di
`_backup` sejak sebelum audit. Akibat: `PRAGMA rekey` tidak pernah
jalan; file backup tetap terkunci kunci perangkat (yang tidak pernah
menemani file keluar device) → backup tak bisa dipulihkan di mana pun,
termasuk device asal (probe PIN selalu gagal). Kesalahan tertangkap
`_run` → snack singkat → pengguna mengira backup sukses. Catatan: file
backup buatan 15:05/15:34 saat uji A-03/A-08 juga terpengaruh.
*Diperbaiki 2026-10-31:* helper top-level `encryptedExecutor(file,
passphrase)` (`database.dart`) — closure setup murni, tanpa rantai
konteks unsendable; dipakai `openAppDatabase`, `_backup`, dan probe
restore. Terverifikasi E2E penuh: backup PIN 778899 → hapus kunci →
layar terkunci → pulihkan file dengan PIN → data lama kembali.

### Yang sudah benar (pertahankan)

- Enkripsi at-rest terukur efektif (A-04), kunci per-device di Keystore.
- Mode file DB & antrian `0600`, direktori `0700`.
- Backup = rekey penuh ke PIN (bukan ZIP-nama), restore diverifikasi
  PIN via probe `sqlite_master` sebelum replace, staging direkey ke
  kunci device baru — dua fase (ADR-006); implementasinya benar, tapi
  pernah patah senyap oleh A-11 sebelum 2026-10-31.
- Input PIN `digitsOnly` — menutup injeksi quote ke `PRAGMA rekey`.
- Native bebas logging; manifest bebas izin berlebih.

## C. Reliability Pipeline Capture — 2026-10-31

Verifikasi runtime di emulator-5554 (termasuk injeksi antrean terkontrol
dan reboot), didukung unit test.

| ID | Temuan | Severity |
|---|---|---|
| C-01 | Antrean: baris korup dilewati, duplikat runtuh, transaksi valid jadi draf | ✓ Lolos |
| C-02 | Tidak ada dobel lintas restart — jendela dedup di-jangkar ke `postedAt` | ✓ Lolos |
| C-03 | Listener hidup lagi pasca-reboot & pasca-force-stop tanpa app dibuka | ✓ Lolos |
| C-04 | Notifikasi tertangkap **teredaksi** ("Sensitive notification content hidden") pada kondisi tertentu — tersimpan sebagai sampah yang tak bisa di-parse ulang | Sedang — **perlu verifikasi device fisik** |
| C-05 | Paket yang sudah "dipelajari" tetap diantrikan ke disk meski semua bank diputus | Rendah — **diperbaiki** |

**C-01/C-02/C-03 bukti runtime.** Antrean disuntik 4 baris (1 korup +
2 identik berjarak 1 dtk + 1 unik): baris korup dilewati diam-diam;
draf tepat 2 (duplikat digugurkan → `ignored_dup`); setelah restart
app draf tetap 2. Pasca reboot emulator, notifikasi baru tetap
tertangkap ke antrean **tanpa user membuka app** (sistem me-rebind
listener; izin akses notifikasi persisten). Kap antrean 1 MB / 1000
baris direview kode — pemangkasan benar; catatan kecil:
`readLines()` memuat seluruh file (≤1 MB, aman).

**C-04 teks teredaksi.** Sepanjang sesi emulator pasca-reboot,
notifikasi yang diposting shell (visibilitas PRIVATE) tertangkap
dengan isi "Sensitive notification content hidden" — meski user
unlocked dan listener di-rebind; satu pengecualian teramati (teks
penuh). Pemicu persis belum konklusif di emulator. **Dampak bila
terjadi di device nyata**: transaksi yang datang dalam kondisi
tersebut gagal parse dan tercatat sebagai log sampah — teks asli tak
pernah tersimpan, "baca ulang" tak menolong. *Rekomendasi:*
(1) verifikasi dengan app bank asli di HP fisik; (2) defensif —
NotificationCatcher mendeteksi marker redaksi → jangan tulis sampah,
simpan kunci notifikasi dan tarik ulang via `getActiveNotifications()`
saat `onListenerConnected`/user-unlock.

**C-05 paket belajar vs bank diputus.** *Diperbaiki 2026-10-31:*
`setAllowedPackages` dengan daftar kosong kini menulis allowlist kosong
(tanpa union paket belajar) — putus semua bank benar-benar menghentikan
tulisan ke disk. Terverifikasi runtime: notifikasi saat tak ada bank
terhubung → antrean tetap kosong. (Jalur belajar-paket tak diuji ulang
pasca-fix karena notifikasi shell emulator teredaksi, C-04 —
perilakunya sendiri tidak berubah.)

**Lampu sehat (disetujui user 2026-10-31, usulan implementasi).**
Indikator kesehatan penangkap di layar Pengaturan Capture: (a) izin
listener aktif? (sudah ada), (b) listener terakhir menangkap kapan
(timestamp heartbeat di prefs native), (c) peringatan bila bank
terhubung aktif tetapi 0 notifikasi tertangguh >7 hari.

## D. Rules Engine — 2026-10-31

| ID | Temuan | Severity |
|---|---|---|
| D-01 | Varian nominal & penangkalan promo — 9/9 kasus lolos | ✓ Lolos |
| D-02 | Katalog seed rules tipis: hanya blu, nagari, generik | Sedang |
| D-03 | Format informal "15rb" tidak dikenali (null) | Rendah |
| D-04 | Re-parse idempoten + pangkasan log — tercover unit test | ✓ Lolos |

**D-01 bukti.** Skrip sekali-pakai (dihapus) menembak 9 varian ke
engine dengan seed asli: `Rp111.000`, `Rp 150.000` (spasi),
`Rp150.000,75` (desimal dipotong), `Rp1.234.567`, teks debit BCA
berisi saldo kedua (`SISA Rp500.000` diabaikan — nominal pertama yang
dipakai), promo ber-nominal → null, tanpa nominal → null, `15rb` →
null, keyword nagari + nominal → benar. Semua sesuai ekspektasi.

**D-02 katalog tipis.** `seed_rules.json` hanya memuat 3 entri (blu,
nagari, `unknown`). UI sudah mengantisipasi e-wallet lain (deteksi
jenis akun menyebut gopay/ovo/dana/shopeepay) tetapi tidak ada
rules-nya — user e-wallet selain blu tidak terlayani capture.
*Rekomendasi:* tambahkan template per bank/e-wallet populer
(progressif, mulai dari yang user pakai).

**D-04 tercover test.** `repository_test`: log identik dicatat sekali,
re-parse → draf + log ditandai terbaca, dup digugurkan tercatat
`ignored_dup` (terlihat), prune hapus log terbaca >30 hari (yang
belum terbaca utuh), draf juga ter-dedup terhadap transaksi
terkonfirmasi.

## B. Integritas Data — 2026-10-31

| ID | Temuan | Severity |
|---|---|---|
| B-01 | Money: parsing & batas nominal aman | ✓ Lolos |
| B-02 | Konvensi periode `[start, end)` terdokumentasi, implementasi `BETWEEN` inklusif — transaksi tepat 00:00:00.000 tanggal 1 masuk dua bulan | Rendah — **diperbaiki** |
| B-03 | Draf terisolasi dari saldo/laporan; fallback hapus kategori benar | ✓ Lolos |
| B-04 | Dedup ±120 dtk — terverifikasi runtime (lihat C-01) | ✓ Lolos |
| B-05 | Streak & mood dihitung ulang murni dari data | ✓ Lolos |
| B-06 | Restore dua fase — terverifikasi E2E (lihat A-11) | ✓ Lolos |

**B-01.** `Money.parseGroup`: strip non-digit, koma desimal dipotong ke
bawah, angka >int64 melempar `FormatException` → `tryParseGroup`
null. Engine memagari 1 ≤ nominal ≤ 1 triliun (`_minSaneAmount` /
`_maxSaneAmount`) — `Rp0` dan nominal gila ditolak. Arah +/- bukan
bagian nominal (terpisah sebagai direction).

**B-02.** Pemanggil memakai `end = awal bulan berikutnya` dan
`isBetweenValues` → SQL `BETWEEN` (inklusif dua ujung). Laporan
rentang kustom sudah dinormalisasi benar (`end = hari terakhir + 1`,
`laporan_screen.dart:94`). Sisa risiko: transaksi bertimecode persis
00:00:00.000 tanggal 1 terhitung di dua bulan (notifikasi bank: 1 dari
~86 juta ms per hari; input manual memakai `DateTime.now()` — aman).
*Rekomendasi:* ganti ke `isBiggerOrEqualValue(start) &
isSmallerThanValue(end)` agar sesuai konvensi, atau perbaiki
dokumentasinya.
*Diperbaiki 2026-10-31:* `_withCategoryQuery` kini eksklusif ujung atas
(konsisten dengan query agregat yang memang sudah benar) + test batas
periode permanen.

**B-03.** Saldo = `openingBalance` + transaksi (`repository.dart:747`);
query laporan (`_withCategoryQuery`) hanya membaca tabel transactions —
draf tidak pernah masuk. Hapus kategori → transaksi dipindah ke
fallback ("Lainnya") + alokasi ikut terhapus (`deleteCategory`).

**B-05.** Streak dihitung dari `txCountByDaySince` (data asli) tiap
refresh; tidak ada kolom state streak/mood di schema — tidak bisa
drift. Mood = fungsi kondisi murni.

## E. Storage & Migrasi — 2026-10-31

| ID | Temuan | Severity |
|---|---|---|
| E-01 | Tangga migrasi solid & self-heal, tapi transisi v3→v5, v6→v7, dan lompatan v1→v10 langsung tak ada fixture test | Rendah — **diperbaiki** |
| E-02 | Nol index pada tabel transaksi — `EXPLAIN QUERY PLAN`: `SCAN transactions` | Rendah — **diperbaiki** |
| E-03 | `LedgerRepository` satu-satunya pintu data | ✓ Lolos |

**E-01.** Tangga migrasi pakai guard `_hasColumn` + `beforeOpen`
self-heal (buat-ulang tabel hilang, seed idempoten, backfill
category/account NULL-only) — desainnya kuat. Fixture test yang ada:
v1→v2, v2→v3, v5→v6, v7→v8, v8→v9, v9→v10. Yang belum: DB v3 & v6
langsung ke v10, dan v1→v10 sekali jalan. *Rekomendasi:* tambah
fixture untuk jalur lompatan (paling realistis: user lama tidak update
app berbulan-bulan).
*Diperbaiki 2026-10-31:* fixture lompatan v3→v11 & v6→v11 ditambahkan
(lompatan v1→terbaru memang sudah teruji oleh test v1 yang membuka DB
dengan schemaVersion terkini). Bonus temuan saat menulis fixture: DDL
legacy harus memuat DEFAULT kolom timestamp — seed akun bergantung
padanya sebelum migrasi lengkap terpasang.

**E-02.** Tidak ada satu pun `CREATE INDEX`/`@TableIndex`. Query panas
(periode+akun pada transactions) melakukan full scan; semua stream
`watch()` mengulang scan pada tiap perubahan tabel. Pada skala
personal (ribu-tahun baris) masih mikro-detik — tidak terasa — tapi
murah untuk dicegah. *Rekomendasi:* `@TableIndex` pada
`transactions.occurredAt` (plus `accountId` bila audit F menunjukkan
jank), migrasi v11.
*Diperbaiki 2026-10-31:* migrasi v11 + self-heal `beforeOpen`
`CREATE INDEX IF NOT EXISTS idx_transactions_occurred_at` — jalur
migrasi lama→v11 tereksekusi di semua fixture test migration (suite
hijau).

**E-03.** Import drift hanya di `lib/storage/`; tiga file UI
mengimpor `class Value` semata (companion builder — bukan akses DB).
`PRAGMA foreign_keys = ON` dijalankan tiap `beforeOpen`.

## F. Performa — 2026-10-31

Pengukuran pakai build **release** (APK terpasang di emulator
SwiftShader — angka absolut membesar; pakai sebagai indikator relatif,
verifikasi di device nyata).

| ID | Temuan | Severity |
|---|---|---|
| F-01 | Startup dingin 2,6–3,2 dtk (emulator); `main()` membuka DB 2× + seed + muat asset sebelum frame pertama | Sedang — **diperbaiki** |
| F-02 | Konvensi stream-disematkan dijaga; daftar panas `ListView.builder` | ✓ Lolos |
| F-03 | 12 stream `watch()` di repository — re-run selektif per tabel, ok di skala personal | ✓ Lolos (catatan E-02) |
| F-04 | APK release 73,5 MB (fat APK 3 ABI); `libsqlcipher.so` 5,1 MB per ABI | Rendah |
| F-05 | Statistik frame tak terukur via `gfxinfo` (Impeller tak terlacak) | Catatan |

**F-01.** `am start -W` ×3: TotalTime 3094/3158/2572 ms. Urutan
`main()`: `applyPendingRestore` (I/O) → `isDatabaseLocked` (buka DB
penuh + SELECT + **close**) → `openAppDatabase` (buka **lagi**) →
seed (debug) → `loadSeedRuleSet` (asset) → baru `runApp`. Semua itu
menahan frame pertama; di device lambat/penyimpanan padat akan terasa.
Catatan baik: data demo terpasang **hanya di debug**
(`seed_dummy.dart:23 if (!kDebugMode)`); layar kosong release benar.
*Rekomendasi:* `runApp` lebih dulu (splash) lalu init async, atau
probe lock memakai koneksi yang sama dengan DB utama, dan tunda
*Diperbaiki 2026-10-31:* `main()` kini `runApp` langsung (splash) —
init berat jalan async di `CatatIMBootstrap`, DB dibuka SEKALI (probe
kunci pakai koneksi yang sama), `isDatabaseLocked()` dipensiunkan.
Hasil ukur ulang: rata-rata 2.941 → 2.135 dtk (**−28%**) di emulator;
jalur layar terkunci tetap terverifikasi runtime.

**F-02.** Laporan menyematkan stream di field + kunci `_streamKey`
(tidak re-subscribe tiap build); home memakai stream di
`initState`; daftar transaksi/laporan `ListView.builder` (lazy);
"transaksi terbaru" di home dibatasi 5 baris — Column wajar. `const`
dipakai sehat (126/74/47/64 di empat layar besar).

**F-03.** Drift hanya menjalankan ulang stream yang tabelnya berubah;
12 stream aktif tak masalah di skala personal — tetapi tanpa index
(E-02) tiap re-run query transaksi = full scan. Perbaikan E-02
sekalian mengurus ini.

**F-04.** Fat APK berisi arm64 (23,2 MB) + armeabi-v7a (20,0 MB) +
x86_64 (25,4 MB). *Rekomendasi:* `flutter build apk --split-per-abi`
atau App Bundle saat rilis → ~24 MB per device. `libsqlcipher.so`
5,1 MB/arm64 — patut dicek stripping simbolnya. Icon tree-shake
efektif (1,6 MB → 15 KB) ✓; font Nunito 496 KB & maskot 260 KB wajar.

**F-05.** `dumpsys gfxinfo` melaporkan 0 frame (Impeller melewati
pipeline hwui yang dilacak) — jank harus diukur lewat
`flutter run --profile` + timeline di device nyata. Di-emulator,
scroll laporan & navigasi terasa lancar secara kualitatif; layar
laporan release terverifikasi render benar (empty state konsisten).

## G. Integrasi Android — 2026-10-31

| ID | Temuan | Severity |
|---|---|---|
| G-01 | Build release ditandatangani **debug key** (`build.gradle.kts:32`, TODO asli Flutter) | Sedang — blokir rilis |
| G-02 | `dynamic_color` dependensi mati — tak dipakai di `lib/` (konsisten ADR-010 satu tema terang) | Rendah |
| G-03 | Predictive back tidak diaktifkan (`enableOnBackInvokedCallback` absen) — back klasik, tanpa animasi prediktif Android 14+ | Rendah |
| G-04 | minSdk 24 / targetSdk 36 — modern, cukup untuk listener & SAF | ✓ Lolos |

**G-01.** `signingConfig = signingConfigs.getByName("debug")` — APK
release tak bisa diunggah Play Store dan terpasang dari sumber mana pun
tanpa peringatan sistem. *Rekomendasi:* buat keystore rilis + isi
signingConfig sebelum distribusi; jangan commit kredensial.

**G-02.** `dynamic_color: 1.9.0` di pubspec tanpa satu pun pemakaian —
hapus dari dependensi (mengurangi dependensi build). Bertabrakan dgn
niat ADR-010 memang tidak — hanya tidak terpakai.

**G-03.** Tanpa `android:enableOnBackInvokedCallback="true"`, gesture
back tetap berfungsi (klasik) tetapi animasi prediktif Android 14+
tidak muncul. Opsional; uji dulu transisi kustom (QuestPageTransitions)
tidak bentrok bila diaktifkan.

**G-04.** targetSdk 36 ⇒ edge-to-edge diwajibkan Android 15+ — aman:
layar terverifikasi render benar (header & konten tidak menempel
status bar). Tidak ada `dataExtractionRules` — menerima berkat
`allowBackup=false` (A-01).

## H. UI/UX, Aksesibilitas, Lokalisasi — 2026-10-31

| ID | Temuan | Severity |
|---|---|---|
| H-01 | Tombol ikon tanpa label semantik (bell, gear, dsb.) — pembaca layar membaca kosong; hanya 6 Tooltip/Semantics di seluruh UI | Sedang |
| H-02 | String Indonesia hardcoded di mana-mana — by-design satu bahasa; belum siap multi-bahasa | Catatan |
| H-03 | Empty state & skeleton baik; error state stream minim (home tanpa penanganan error stream) | Rendah |

**H-01.** Bukti runtime (uiautomator): tombol lonceng & gear di header
home memiliki `content-desc` kosong; switch koneksi bank justru berlabel
baik ("Capture blu by BCA"), begitu juga kartu draf. *Rekomendasi:*
bungkus tombol ikon dengan `Tooltip`/`Semantics` (murah, menyentuh
QuestIconButton sekali).

**H-02.** `Locale('id')` tunggal + `flutter_localizations` untuk string
internal Material ✓; `dates_id` konsisten. Bila suatu hari mau
multi-bahasa, string tersebar di semua layar — biaya migrasi besar,
tapi bukan masalah hari ini.

**H-03.** Empty state laporan terverifikasi runtime (pesan + instruksi
benar). Skeleton loading ada (konvensi arsitektur). Stream drift nyaris
tak pernah error lokal — risiko rendah, cukup sadar.

## I. Kualitas Kode & Maintainability — 2026-10-31

| ID | Temuan | Severity |
|---|---|---|
| I-01 | 5 file UI >900 baris (laporan 2.471, quest 1.280, home_cards 1.230, rencana_batas 1.160, transaksi 981) | Sedang — **diperbaiki 4/5** |
| I-02 | Dead code: `buildCsv()` (A-09), dependensi `dynamic_color` (G-02) | Rendah |
| I-03 | Lints: set dasar `flutter_lints` tanpa aturan tambahan | Rendah |

**I-01.** File raksasa memperlambat navigasi editor & review. Laporan
sudah memakai pola bagus di dalamnya (stream field + `_streamKey`).
*Rekomendasi:* pecah per-seksi jadi widget privat per file — refaktor
mekanis, tanpa ubah perilaku, satu layar per PR.
*Diperbaiki 2026-10-31:* laporan_screen 2.471 → 765 (6 part),
quest.dart 1.280 → 18 (8 part), home_cards 1.230 → 239 (4 part),
rencana_batas 1.160 → 542 (2 part) — semua via part files: satu
library, nama privat utuh, perilaku identik. transaksi_screen
sengaja tidak dipecah: State-nya 890 baris, butuh refaktor
per-metode — pemecahan mekanis tak memberi nilai. Verifikasi:
analyze bersih, 149/149 test, render runtime per layar di emulator.

**I-02.** *Diperbaiki 2026-10-31:* `buildCsv()` + test-nya dihapus
(ekspor plaintext memang tak pernah diekspos, A-09); `dynamic_color`
dan `cupertino_icons` (nol pemakaian juga) dikeluarkan dari pubspec.
`seed_dummy.dart` tetap di `lib/` tapi dijaga `kDebugMode` —
ter-tree-shake dari build release (terverifikasi: rilis fresh-install
kosong) — bukan masalah.

**I-03.** *Rekomendasi:* tambah `prefer_const_constructors`,
`unawaited_futures`, `avoid_redundant_argument_values` — jalankan
sekali dengan `--fix`.

## J. Testing & CI — 2026-10-31

| ID | Temuan | Severity |
|---|---|---|
| J-01 | Tidak ada CI — 147 test hanya jalan lokal penulis | Sedang |
| J-02 | Tidak ada integration test device (notif → draf → konfirmasi → saldo) | Rendah |

**J-01.** Tanpa CI, regresi seperti A-11 (rekey senyap gagal berbulan)
tak terdeteksi. *Rekomendasi minimal:* GitHub Actions —
`flutter analyze` + `flutter test` per push (±3 menit). Test backup
E2E (buat backup → buka ulang dengan PIN) layak jadi test integrasi
pertama karena pernah patah.

**J-02.** Jalur kritis paling berisiko justru lintas proses (listener
→ antrean → drain) — tak bisa diuji murni Dart. Integration test
`flutter drive` + `cmd notification post` di emulator CI adalah
jawabannya, tapi investasi besar; alternatif murah: skrip audit seperti
hari ini didokumentasikan sebagai prosedur manual rutin.

## K. Dokumentasi & Kepatuhan — 2026-10-31

| ID | Temuan | Severity |
|---|---|---|
| K-01 | Klaim usang di ARCHITECTURE: "133 test/10 file", "UI belum punya widget test" (nyatanya 147/15, 6 file widget test) | Rendah — **diperbaiki saat audit** |

**K-01.** Bagian Pengujian ARCHITECTURE diperbarui saat audit ini.
ADR lengkap & akurat (001 diamendemen allowlist). Untuk rilis Play
Store kelak: form data safety wajib mendeklarasikan Notification
Listener access; klaim "data tak keluar device" sudah terbukti audit
A-05 (nol izin jaringan).
