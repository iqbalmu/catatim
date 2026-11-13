# ADR-012: Peringatan batas = notifikasi lokal, native transport

## Status

Diterima (2026-11-13).

## Konteks

Fitur pertama notifikasi Android: memperingatkan user saat pengeluaran
menyentuh persentase tertentu dari batas (harian/mingguan/bulanan).
Dua pilihan jalur: package `flutter_local_notifications`, atau channel
native sendiri.

## Keputusan

Channel native sendiri (`bukuduit/notify` → `MainActivity` →
`BudgetNotifier`), konsisten ADR-001: Kotlin HANYA membuat channel,
mengecek izin (`canPost`, runtime `POST_NOTIFICATIONS` Android 13+),
dan menampilkan notifikasi berteks dari Dart. Seluruh keputusan —
kapan mengingatkan, garis mana, berapa persen, dedup per periode —
di Dart murni:

- Engine `lib/core/budget_alert.dart` (tanpa drift/Flutter, ADR-003):
  `planBudgetAlerts` memutuskan garis yang baru menyentuh ambang;
  state dedup `{scope#jenis: periodKey}` disimpan di `app_settings`
  sehingga satu garis bunyi maksimal sekali per periode, dan over
  (100%+) dikirim terpisah dari ambang.
- `BudgetAlertService.check(snapshot)` dipanggil dari
  `ProgressService._evaluate()` tiap transaksi tercatat — bukan saat
  app dibuka, agar tidak berisik saat user membuka app (kondisi
  terkini sudah di hero Beranda). Pipeline capture juga memanggil
  `progress.onTransactionRecorded()` setelah draf dicatat otomatis —
  menutup celah lama di mana alert in-app tidak segar untuk jalur
  auto-record.
- `BudgetAlertService` + `NotifyChannel` menelan semua error: gagal
  menampilkan notifikasi tidak boleh menggagalkan pencatatan.

## Konsekuensi

- Nol dependensi baru; `flutter_local_notifications` tidak dibutuhkan
  untuk kasus "post teks sederhana + channel".
- Batasan: Dart hanya jalan saat proses app hidup (konsisten capture).
  Crossing yang terjadi saat proses mati menyusul di event transaksi
  berikutnya; dedup mencegah dobel. Foreground service disengaja —
  biaya liveness jauh lebih besar daripada manfaatnya.
- Notifikasi memakai satu id tetap (`2001`) → peringatan baru
  menggantikan yang lama, tidak menumpuk di tray.
