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

## Struktur

| Path | Isi |
|---|---|
| `lib/rules/` | Rules engine + seed rules (`assets/rules/seed_rules.json`) |
| `lib/capture/` | Channel native + pipeline capture→parse→simpan |
| `lib/storage/` | Drift schema + repository (dedup 120 detik) |
| `lib/ui/` | Beranda, capture log, input manual |
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
2. Buka **Capture log** — notifikasi mentah muncul dengan badge
   `Tercatat` (berhasil) atau `Dikenali?` (gagal parse).
3. Sesuaikan `matchAll`/`matchAny`/`counterparty` di seed rules dengan teks
   asli, `flutter run` lagi.
4. Kirim `packageName` asli blu (lihat capture log) untuk melengkapi
   `packageNames` nagari/blu bila ternyata berbeda.

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
