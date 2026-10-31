# Arsitektur Bukuduit

Pencatat keuangan pribadi Android, offline-first. Transaksi dari push
notifikasi bank/e-wallet tertangkap otomatis; semua data tersimpan
terenkripsi di perangkat, tanpa server. Dokumen ini ringkas — rincian
alasan tiap keputusan ada di [`decisions/`](decisions/).

## Prinsip

1. **Offline-first, privasi tanpa kompromi.** Tanpa server, tanpa
   analytics, tanpa izin jaringan untuk data. SQLCipher + passphrase di
   secure storage ([ADR-002](decisions/002-enkripsi-lokal-tanpa-server.md)).
2. **Native hanya transport.** Seluruh logika (parse, dedup, simpan) di
   Dart, unit-testable tanpa device
   ([ADR-001](decisions/001-native-transport-only.md)).
3. **Engine murni di bawah, UI di atas.** `core/` dan `rules/engine`
   bebas dependensi drift/Flutter; storage dan UI memakainya
   ([ADR-003](decisions/003-engine-murni.md)).

## Peta lapisan

| Lapisan | Isi | Aturan |
|---|---|---|
| Native (Kotlin) | `MainActivity.kt`, `NotificationCatcher` | Baca notifikasi (lewati ongoing) → JSON mentah → antrian file terbatas + EventChannel. Tidak parse, tidak putuskan apa pun. |
| Capture | `lib/capture/` | Drain antrian (tahan baris korup), filter bank terhubung, antrean pemrosesan berurutan, fallback capture log. |
| Rules | `lib/rules/`, `assets/rules/seed_rules.json` | Parse teks notifikasi → draf transaksi. Seed rules murni, murni Dart. |
| Core | `lib/core/` | Money (int rupiah), buckets tren, budget (`LimitLine`/`BudgetSnapshot`), format tanggal ID. Murni Dart, tanpa drift/Flutter. |
| Storage | `lib/storage/` | Drift schema v10, SQLCipher, `LedgerRepository` satu-satunya akses data. |

## Alur capture

```mermaid
flowchart LR
    A[Notifikasi bank] --> B[NotificationCatcher: antrian capture_queue.jsonl]
    B -->|EventChannel JSON| C[CapturePipeline: drain saat start]
    C --> D{Bank terhubung?}
    D -->|tidak| X[diabaikan diam-diam]
    D -->|ya| E{RuleEngine: seed rules}
    E -->|kenali + dedup ±120s| F[(drafts — menunggu user)]
    E -->|gagal| G[(capture_logs)]
    E -->|dup digugurkan| H[capture_logs.ignored_dup]
    F -->|konfirmasi user| I[(transactions)]
    G -.->|baca ulang| E
    H -.->|catat manual| I
    I --> J[Repository streams → UI + ProgressService]
```

- Antrian file membuat notifikasi tidak hilang saat app mati; ukurannya
  dibatasi (±1 MB, disimpan 1000 baris terakhir) dan notifikasi ongoing
  (musik/unduhan) dilewati.
- Baris antrian yang korup dilewati — satu baris rusak tidak membuang
  antrean lainnya.
- Notifikasi yang gagal parse disimpan mentah di Capture Log; setelah
  rules diperbaiki, entri lama bisa di-parse ulang tanpa transaksi ulang.
- Duplikat yang digugurkan dedup tidak senyap: tercatat dengan penanda
  `ignored_dup` dan tampil di Diagnostik (catat manual / hapus);
  log terbaca/dup >30 hari dipangkas otomatis.
- Setiap transaksi tercatat (konfirmasi draf maupun manual) memicu
  `ProgressService.onTransactionRecorded()` → deteksi garis batas naik
  level / pulih / milestone streak, realtime.

## Rules & model hubungkan bank

Model "hubungkan bank" (menggantikan user rules, ADR-004 digantikan):

1. User menghubungkan bank/e-wallet dari katalog (`connected_banks`
   di `app_settings`); hanya notifikasi bank terhubung yang diproses,
   selebihnya diabaikan diam-diam.
2. Seed rules (`assets/rules/seed_rules.json`) — template per bank,
   dipakai murni tanpa lapisan user rules.
3. Template generik (`unknown`) — pola in/out umum sebagai fallback
   bank yang dikenali tapi formatnya belum ada.

Hasil parse selalu menjadi **draf** menunggu keputusan user — tidak
pernah auto-catat. Timpa perilaku parsing dilakukan lewat loop
capture log → perbaiki seed → parse ulang, bukan aturan per-user.

## Model data (drift schema v10)

| Tabel | Isi |
|---|---|
| `transactions` | Transaksi: uuid, arah, nominal, kategori, akun, jenis, pihak, sumber (manual/capture), waktu |
| `drafts` | Draf hasil capture bank terhubung — menunggu konfirmasi/dibuang; tak masuk saldo/laporan |
| `categories` | Kategori + warna; hapus → transaksi pindah ke fallback "Lainnya" |
| `accounts` | Akun (blu, Nagari, Tunai bawaan + tambahan), jenis, saldo awal, tautan `bank_id` |
| `budgets` | Alokasi bulanan per kategori, opsional di-scope ke akun |
| `app_settings` | Batas harian/mingguan/bulanan, marker restore, bank terhubung |
| `bons` | Utang-piutang: arah, nominal, pihak, status lunas |
| `capture_logs` | Notifikasi mentah + status parse + penanda `ignored_dup`; bahan tuning rules |

Migrasi v1→v10 self-heal: tabel/kolom yang hilang dibuat ulang, broken
v2 diperbaiki, kategori/akun ter-seed, backfill dijalankan di
`beforeOpen`. v8 memensiunkan Target/Sisihkan (ADR-009); v9 menambah
draf + tautan akun↔bank; v10 membuang `user_rules` dan menambah
`capture_logs.ignored_dup`.

## Konvensi

- **Uang**: int rupiah penuh (`Money`); desimal koma dipotong ke bawah.
- **Periode**: `[start, end)` eksklusif ujung atas; waktu lokal device.
- **Tren**: bucket mingguan 7-hari, menjadi bulanan bila rentang >62
  hari (maks 24 bucket).
- **Streak**: dihitung ulang dari data transaksi asli setiap refresh —
  bukan counter tersimpan, tidak bisa drift. Belum mencatat hari ini
  tidak memutus.
- **Mood maskot**: fungsi murni kondisi — over → khawatir, warning →
  idle/waspada, ok + catat hari ini → senang, tanpa data → idle,
  streak 0 → mengantuk
  ([ADR-007](decisions/007-gamifikasi-berbasis-kondisi.md)).
- **Stream disematkan**: `StreamBuilder`/`FutureBuilder` memakai objek
  stream/future yang disematkan sekali per umur `State` (`initState` +
  buat ulang di `didUpdateWidget` bila param berubah) — jangan dibuat
  inline di `build`. Objek baru tiap rebuild memicu subscribe ulang →
  skeleton berkedip setiap pindah tab.

## Keputusan kunci

| ADR | Keputusan |
|---|---|
| [001](decisions/001-native-transport-only.md) | Native hanya transport JSON mentah + antrian file |
| [002](decisions/002-enkripsi-lokal-tanpa-server.md) | SQLCipher lokal, tanpa server/cloud |
| [003](decisions/003-engine-murni.md) | Core + rules bebas drift/Flutter |
| [004](decisions/004-prioritas-rules.md) | ~~User rules > seed > generik~~ — digantikan model hubungkan bank (seed murni) |
| [005](decisions/005-dedup-120-detik.md) | Dedup push ganda ±120 detik |
| [006](decisions/006-restore-dua-fase.md) | Restore via staging + marker + restart |
| [007](decisions/007-gamifikasi-berbasis-kondisi.md) | Gamifikasi = cermin kondisi nyata; XP/level dihapus |
| [008](decisions/008-quest-design-system.md) | Design system Quest sendiri, tanpa state library |
| [009](decisions/009-pensiun-target-sisihkan.md) | Target/Sisihkan dipensiunkan; Rencana = Batas, belanja murni tunggal |

## Pengujian

133 test, 10 file: rule engine (seed + fallback), budget, progress/
streak/mood, repository (dedup, saldo, migrasi v1→v10, alokasi, log
lifecycle), pipeline (draf, dedup, baris korup), money, buckets,
rekap filter, CSV, history.
UI sengaja belum punya widget test — logika dipagari di engine murni
sesuai prinsip 3.
