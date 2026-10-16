# Tab Rekap — Transaksi + Donat + Kalender + Tren

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Satu layar Rekap bersegmen menggantikan tab Riwayat + Laporan: lookup 1 ketuk, analisis ≤2 ketuk, Kalender baru menjawab "tgl X habis berapa".

**Architecture:** `lib/ui/rekap_screen.dart` baru sebagai shell + state filter bersama (kontrak §4 spek); pindahkan view lama sebagai widget: daftar dari `history_screen.dart`, donat+headline+tren dari `report_screen.dart`, kalender baru (`QuestRangeCalendar` sebagai pola); file lama tetap sampai Plan 5 memutus tab lama.

**Tech Stack:** Flutter (kit `ui/quest.dart`); tanpa dependensi baru.

**Spec:** `docs/superpowers/specs/2026-10-13-informasi-navigasi-design.md` (§4 Rekap + kontrak filter, §5 alur B/F).

## Global Constraints

- Copy UI bahasa Indonesia; nominal selalu via `Money.format` (int rupiah).
- `lib/core/` tetap bebas import drift/Flutter (ADR-003).
- Gaya hanya via widget kit `lib/ui/quest.dart` + token `context.q` (ADR-008); angka pakai `FontFeature.tabularFigures()`.
- Tanpa widget test UI; logika baru wajib test engine dulu (TDD).
- Tanpa dependensi pubspec baru.

## Review Focus

1. Filter yang dibawa deep-link vs filter manual yang bertabrakan — kontrak Task 1 mem-pin; uji manual tiap transisi Task 4.
2. Kalender bulan 28/29/30/31 hari + sel di luar bulan — grid 6×7 stabil.
3. Donat tap kategori saat periode custom — kategori + rentang ikut ke Transaksi.
4. Stream gabungan 4 segmen tidak jank di HP kentang — segmen non-aktif tidak subscribe (LazyIndexedStack pola).
5. Periode: pil bulan + rentang custom dipakai SEMUA segmen (satu sumber).

---

### Task 1: State filter bersama (engine murni + test)

- Create: `lib/core/rekap_filter.dart`
- Test: `test/rekap_filter_test.dart` (baru)

**Interfaces:**
- Consumes: kontrak §4 spek.
- Produces:
```dart
class RekapFilter {
  const RekapFilter({this.month, this.range, this.accountId, this.query, this.categoryId, this.day});
  RekapFilter applyDonatTap({required int categoryId, required DateTime monthStart, required DateTime monthEnd});
  RekapFilter applyKalenderTap(DateTime day);
  RekapFilter onSegmentSwitch(); // manual: pertahankan periode/akun/cari; hapus kategori/tanggal
  RekapFilter clearChip(); // hapus kategori/tanggal saja
}
```
Pakai `DateTimeRange` Flutter (core tetap bebas drift — `material.dart`? **Keputusan plan:** `RekapFilter` di `lib/core/` hanya pakai `DateTime` primitif: `rangeStart/rangeEnd DateTime?`, bukan `DateTimeRange` — agar core bebas Flutter).

- [ ] **Step 1: Tulis test gagal** — 5 case sesuai kontrak: donatTap set kategori+bulan; kalenderTap set tanggal; switch hapus kategori/tanggal tapi simpan akun/cari; clearChip; default kosong.
- [ ] **Step 2: Jalankan** `flutter test test/rekap_filter_test.dart` — FAIL.
- [ ] **Step 3: Implementasi** `lib/core/rekap_filter.dart`.
- [ ] **Step 4: Jalankan** — PASS.
- [ ] **Step 5: Commit** `feat(rekap): state filter bersama`.

### Task 2: Shell Rekap + segmen Transaksi (pindah)

**Files:**
- Create: `lib/ui/rekap_screen.dart` (`RekapScreen({required repository})`, `QuestSegmented` 4 segmen, state `RekapFilter`)
- Modify: `lib/ui/history_screen.dart` (ekstrak view daftar → `lib/ui/rekap_transaksi.dart`, terima `RekapFilter` + callback; HistoryTab lama tetap jalan)
- Test: TIDAK ADA (UI)

**Interfaces:**
- Consumes: `RekapFilter` (Task 1); repository stream yang dipakai HistoryTab sekarang.
- Produces: `RekapScreen` dengan default segmen Transaksi; pil periode (bulan/rentang, pola `_PeriodSheet` report) di atas segmen.

- [ ] **Step 1: Ekstrak** daftar transaksi ke `rekap_transaksi.dart` (murni pindah + parameter filter; perilaku identik).
- [ ] **Step 2: Buat shell** `rekap_screen.dart` + segmen; Transaksi tampil default.
- [ ] **Step 3: Jalankan** `flutter analyze` — zero issue; `flutter test` PASS.
- [ ] **Step 4: Commit** `feat(rekap): shell + segmen transaksi`.

### Task 3: Segmen Donat + Tren (pindah) + deep-link kategori

**Files:**
- Modify: `lib/ui/rekap_screen.dart`, `lib/ui/rekap_transaksi.dart`
- Create: `lib/ui/rekap_donat.dart`, `lib/ui/rekap_tren.dart` (ekstrak dari `report_screen.dart`)
- Test: TIDAK ADA (UI)

**Interfaces:**
- Consumes: view donat/headline (`report_screen.dart` `_CategoryDonutCard`, `_HeadlineCard`), tren (`_MonthlyBarCard` + `trendBuckets`).
- Produces: tap kategori → `applyDonatTap` → pindah segmen Transaksi terfilter + chip `✕ Kategori`.

- [ ] **Step 1: Ekstrak** donat + headline + tren ke file rekap; pasang di segmen; SEKALIGUS ganti sumber angka ke keluar MURNI (keputusan A): `sumSpendBetween` + pasangannya, bukan `sumBetween`; transfer biasa & Sisihkan tidak masuk statistik. Smoke Task 4 mem-pin: transfer 5jt tidak mengubah headline.
- [ ] **Step 2: Deep-link** kategori (callback → shell → `setState` filter + segmen Transaksi).
- [ ] **Step 3: Jalankan** `flutter analyze` zero issue; smoke: donat → tap Makanan → daftar terfilter + chip; `flutter test` PASS.
- [ ] **Step 4: Commit** `feat(rekap): donat + tren + deep-link`.

### Task 4: Segmen Kalender (baru) + verify penuh

**Files:**
- Create: `lib/ui/rekap_kalender.dart` (`RekapKalender({repository, month, onDayTap})`)
- Modify: `lib/ui/rekap_screen.dart` (pasang segmen + lompat ke Transaksi)
- Test: TIDAK ADA (UI; heat murni ikut Task engine bila ada — **Keputusan plan:** heat = intensitas `q.honey` alpha by kuantil dalam bulan, inline di painter, tanpa engine)

**Interfaces:**
- Consumes: `watchOutSumByDaySince(monthStart)`, pola grid `QuestRangeCalendar`.
- Produces: grid 6×7 Senin-awal; sel: tanggal + nominal ringkas (`_shortMoney` pola home_cards); hari ini ditandai; tap → panel rincian hari di bawah + tombol "Lihat di Transaksi" (applyKalenderTap + pindah segmen).

- [ ] **Step 1: Buat** `rekap_kalender.dart` sesuai kontrak.
- [ ] **Step 2: Pasang** di shell + lompat Transaksi.
- [ ] **Step 3: Jalankan** `flutter analyze` zero issue.
- [ ] **Step 4: Smoke** emulator: Oktober 2026 (tgl 1 = Kamis — cek offset!), hari bocor tgl 10 Rp450rb tampil; tap → rincian; "Lihat di Transaksi" → terfilter; pindah segmen manual → filter tanggal hilang, periode tetap; `flutter test` PASS.
- [ ] **Step 5: Commit** `feat(rekap): segmen kalender`.
