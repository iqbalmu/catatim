# Tab Rencana — Batas + Target

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Satu layar Rencana bersegmen menggantikan layar Anggaran: atur 3 limit + alokasi (Batas) dan kelola pos tabungan + Sisihkan (Target).

**Architecture:** `lib/ui/rencana_screen.dart` baru; segmen Batas = pindahan `budget_screen.dart` (3 limit + alokasi + progres MoM); segmen Target = kartu pos baru + sheet Sisihkan (Plan 1 API); deep-link segmen via parameter `initialSegment` (janji ke Plan 2 & 5).

**Tech Stack:** Flutter (kit `ui/quest.dart`); tanpa dependensi baru.

**Spec:** `docs/superpowers/specs/2026-10-13-informasi-navigasi-design.md` (§4 Rencana, §5 alur C/K). Butuh Plan 1 (repository Target) selesai dulu.

## Global Constraints

- Copy UI bahasa Indonesia; nominal selalu via `Money.format` (int rupiah).
- `lib/core/` tetap bebas import drift/Flutter (ADR-003).
- Gaya hanya via widget kit `lib/ui/quest.dart` + token `context.q` (ADR-008); angka pakai `FontFeature.tabularFigures()`.
- Tanpa widget test UI; logika baru wajib test engine dulu (TDD).
- Tanpa dependensi pubspec baru.
- Sisihkan mengurangi sisa H/M/B + saldo-spendable; BUKAN keluar/masuk (§10 T1).

## Review Focus

1. Pace target tanpa tenggat — hanya % (tanpa "/bln"); pin di Task 2.
2. Target tercapai 100% — rayakan sekali + tawarkan arsip, bukan diam.
3. Hapus Target: konfirmasi + deposit ikut hilang + transaksi transfer tetap (riwayat utuh).
4. Sisihkan melebihi saldo akun sumber — tolak dengan pesan jelas, bukan saldo negatif diam-diam.
5. Deep-link segmen Target dari Beranda masa depan — `initialSegment` wajib diuji manual Task 4.

---

### Task 1: `targetPace` — engine laju setoran (murni)

**Files:**
- Create: `lib/core/targets.dart` (`targetPace`)
- Test: `test/targets_test.dart` (baru)

**Interfaces:**
- Produces:
```dart
({int? perMonth, int percent}) targetPace({required int goal, required int saved, DateTime? deadline, DateTime? now});
```
`percent = (saved/goal*100).clamp(0,100)`; `perMonth` null bila deadline null/sudah lewat/tercapai; else `ceil((goal-saved)/bulanSisa)` (bulanSisa ≥ 1, hitung dari bulan now → bulan deadline inklusif).

- [ ] **Step 1: Tulis test gagal** — goal 10jt saved 4jt deadline 6 bln → perMonth 1jt, percent 40; tanpa deadline → perMonth null; tercapai → perMonth null percent 100; deadline lewat → null; saved 0 → goal/bulanSisa ceil.
- [ ] **Step 2: Jalankan** `flutter test test/targets_test.dart` — FAIL.
- [ ] **Step 3: Implementasi** `lib/core/targets.dart`.
- [ ] **Step 4: Jalankan** — PASS.
- [ ] **Step 5: Commit** `feat(target): engine laju setoran`.

### Task 2: Segmen Batas (pindah Anggaran)

**Files:**
- Create: `lib/ui/rencana_screen.dart` (`RencanaScreen({required repository, RencanaSegment initialSegment = Batas})`)
- Modify: `lib/ui/budget_screen.dart` (ekstrak isi → `lib/ui/rencana_batas.dart`; BudgetScreen lama tetap jalan)
- Test: TIDAK ADA (UI)

**Interfaces:**
- Consumes: seluruh logika `budget_screen.dart` (limits, alokasi, MoM delta).
- Produces: segmen Batas berperilaku identik + tanpa tombol kembali (akar tab).

- [ ] **Step 1: Ekstrak + pasang** di shell Rencana; SEKALIGUS alokasi spend-murni (keputusan A): pemakaian alokasi Jenis memakai pasangan spend-murni `outPairsBetween` (tambah `outSpendPairsBetween` di Plan 01 bila perlu — **Keputusan plan: tambah di Plan 01 Task 3**, mirror `outPairsBetween` + filter kind ≠ transfer); transfer biasa tidak menggerogoti alokasi. Sisihkan berkategori Transfer (bukan alokasi user) jadi netral otomatis.
- [ ] **Step 2: Jalankan** `flutter analyze` zero issue; `flutter test` PASS.
- [ ] **Step 3: Commit** `feat(rencana): shell + segmen batas`.

### Task 3: Segmen Target + sheet Sisihkan (baru)

**Files:**
- Create: `lib/ui/rencana_target.dart` (`RencanaTarget({repository})`: kartu pos + progress + pace + dialog ＋Target + arsip)
- Modify: `lib/ui/rencana_screen.dart` (pasang segmen; FAB-label dikirim ke Plan 5 via callback `onFabLabel`? — **Keputusan plan:** RencanaScreen expose `fabLabelFor(RencanaSegment)` statis agar Plan 5 tidak menebak)
- Test: TIDAK ADA (UI)

**Interfaces:**
- Consumes: Plan 1 (`watchTargets()`, `depositToTarget`, `addTarget`, `deleteTarget`); `targetPace()` (Task 1); sheet pola `BonSheet.show`.
- Produces: kartu pos (nama, RpX/RpY, %, pace "−RpZ/bln s/d Mar" atau "% saja"); sheet Sisihkan (pos terkunci, nominal, akun sumber dropdown saldo); validasi saldo cukup; tercapai → badge "Tercapai 🎉" + aksi Arsip.

- [ ] **Step 1: Buat** kartu + dialog ＋Target + arsip.
- [ ] **Step 2: Buat** sheet Sisihkan + validasi.
- [ ] **Step 3: Jalankan** `flutter analyze` zero issue.
- [ ] **Step 4: Smoke** emulator: ＋Target Dana darurat 10jt → Sisihkan 200rb dari blu → progres 2% + pace segar + Beranda ikut berubah (T1!); over-saldo ditolak; `flutter test` PASS.
- [ ] **Step 5: Commit** `feat(rencana): segmen target + sisihkan`.

### Task 4: Deep-link segmen + verify penuh

**Files:**
- Modify: `lib/ui/rencana_screen.dart` (`initialSegment` + `didUpdateWidget` agar tap berulang dari Beranda pindah segmen)
- Test: TIDAK ADA (UI)

- [ ] **Step 1: Implementasi** `initialSegment` + reaksi perubahan.
- [ ] **Step 2: Smoke** — dari Beranda (setelah Plan 5) tap limit → Batas; dari Target ringkas → Target. (Bila Plan 5 belum ada: smoke via harness sementara `RencanaScreen(initialSegment: target)`.)
- [ ] **Step 3: Jalankan** `flutter analyze` zero issue; `flutter test` PASS.
- [ ] **Step 4: Commit** `feat(rencana): deep-link segmen`.
