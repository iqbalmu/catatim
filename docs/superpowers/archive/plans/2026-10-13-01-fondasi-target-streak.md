# Fondasi IA — Target, Sisihkan, Streak Disiplin

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Skema + engine + repository untuk pos Target, aksi Sisihkan, dan streak hari-disiplin — fondasi data yang dipakai Plan 2–5.

**Architecture:** Tabel drift baru `targets` + `target_deposits`; Sisihkan = baris transfer keluar→pos (model akun-virtual, opsi §8b); engine murni `core/targets.dart` + `dailyBar` di `core/budget.dart`; streak dihitung di `ProgressService.refresh` dari `outSumByDaySince` + `dailyBar`; satu migrasi v6→v7.

**Tech Stack:** Flutter + drift/SQLCipher (tanpa codegen build_runner bila pola tabel manual dipakai — ikuti pola tabel `bons` yang ada); flutter_test + drift NativeDatabase.memory.

**Spec:** `docs/superpowers/specs/2026-10-13-informasi-navigasi-design.md` (§2 anti-tujuan, §7 streak, §8 builder, §10 T1/T2).

## Global Constraints

- Copy UI bahasa Indonesia; nominal selalu via `Money.format` (int rupiah).
- `lib/core/` tetap bebas import drift/Flutter (ADR-003).
- Gaya hanya via widget kit `lib/ui/quest.dart` + token `context.q` (ADR-008); angka pakai `FontFeature.tabularFigures()`.
- Tanpa widget test UI; logika baru wajib test engine dulu (TDD).
- Tanpa dependensi pubspec baru.
- Migrasi mengikuti pola v1–v6 + self-heal (`test/migration_test.dart`).
- Sisihkan mengurangi sisa H/M/B + saldo-spendable; BUKAN keluar/masuk (§10 T1).
- Transfer antar-akun sendiri DIKELUARKAN dari pace/streak/statistik keluar (keputusan pemilik 2026-10-13, opsi A); hanya Sisihkan (transfer ke pos) yang menggerus sisa — dipin di test Plan 02 Task 2.
- Badge Bon dari umur bon (> 30 hari), tanpa kolom skema baru (§10 T2).
## Review Focus

1. Transfer antar-akun sendiri (bukan ke pos) ikut/mengurangi saldo-spendable — pilih satu, pin di test Task 3.
2. Sisihkan RpX saat semua limit null (pause) — pace tetap null, target tetap naik; test di Task 4.
3. `dailyBar` saat hari terakhir bulan / Februari kabisat — pin di test Task 1.
4. Over hari ini = streak 0 SEKARANG (bukan menunggu tengah malam) — pin di test Task 4.
5. Deposit ke target yang sudah dihapus — ditolak, test di Task 3.

---

### Task 1: `dailyBar` — jatah harian (engine murni)

**Files:**
- Modify: `lib/core/budget.dart` (tambah setelah `dailyPace`)
- Test: `test/budget_engine_test.dart` (group baru `'jatah harian'`)

**Interfaces:**
- Consumes: pola prioritas `dailyPace()` (`lib/core/budget.dart:163-195`).
- Produces:
```dart
int? dailyBar({required DateTime now, int? dailyLimit, int? weeklyLimit, int? monthlyTotal});
```
Prioritas: harian → mingguan (`~/ 7`) → bulanan (`~/ hariBulanIni`); `<= 0` dilewati; null bila tanpa limit.

- [ ] **Step 1: Tulis test gagal** — group `'jatah harian'`, `now = DateTime(2026, 10, 13)`:
  - `'prioritas harian'`: `(d: 50000, w: 70000, m: 3100000)` → `50000`.
  - `'tanpa harian: mingguan dibagi 7'`: `(w: 70000, m: 3100000)` → `10000`.
  - `'bulanan dibagi hari bulan'`: `(m: 3100000)` → `100000`; Feb: `(m: 290000, now: 2024-02-15)` → `10000`.
  - `'nol/negatif dilewati'`: `(d: 0, w: -5, m: 3100000)` → `100000`.
  - `'tanpa limit: null'`: `()` → `null`.
- [ ] **Step 2: Jalankan** `flutter test test/budget_engine_test.dart --plain-name 'jatah harian'` — FAIL.
- [ ] **Step 3: Implementasi** `dailyBar()` di `lib/core/budget.dart` setelah `dailyPace`.
- [ ] **Step 4: Jalankan** `flutter test test/budget_engine_test.dart` — PASS.
- [ ] **Step 5: Commit** `feat(budget): jatah harian untuk streak disiplin`.

### Task 2: Skema Target + migrasi v7

**Files:**
- Modify: `lib/storage/database.dart` (tabel `targets`, `target_deposits`; `schemaVersion` 6→7; `migration` + self-heal)
- Test: `test/migration_test.dart` (case v6→v7)

**Interfaces:**
- Consumes: pola kolom/tabel `bons` (`occurredAt`, `settledAt`, `createdAt`); helper `newUuid()` (`lib/models.dart`).
- Produces (drift tables):
  - `targets`: `id` (auto), `uuid` text unique, `name` text unique, `goalAmount` int, `deadline` DateTime?, `archivedAt` DateTime?, `createdAt`.
  - `target_deposits`: `id`, `uuid` unique, `targetId` FK targets, `accountId` FK accounts?, `amount` int > 0, `occurredAt`, `createdAt`.
  - Constraint: `amount > 0` (CHECK); `ON DELETE CASCADE` deposit saat target dihapus; FK deposit→target dibuat `ON DELETE CASCADE` sesuai pola drift codebase.

- [ ] **Step 1: Tulis test gagal** — `'migrasi v6→v7: target kosong, data lama utuh'`: siapkan DB v6 manual (pola case v5→v6), trigger open+migrasi, expect tabel `targets`/`target_deposits` ada + 1 transaksi lama terbaca.
- [ ] **Step 2: Jalankan** `flutter test test/migration_test.dart --plain-name 'v6'` — FAIL.
- [ ] **Step 3: Implementasi** tabel + migrasi + self-heal di `lib/storage/database.dart` (CREATE TABLE IF NOT EXISTS agar self-heal).
- [ ] **Step 4: Jalankan** `flutter test test/migration_test.dart` — PASS.
### Task 3: Repository Target + Sisihkan (akun-virtual)

**Files:**
- Modify: `lib/storage/repository.dart`
- Test: `test/repository_test.dart` (group baru `'target & sisihkan'`)

**Interfaces:**
- Consumes: `addManual()` (`lib/storage/repository.dart:136`), `sumBetween(start, end, direction)` (`:451`), `getSetting/setSetting` (`:307-:314`).
```dart
Future<Target> addTarget({required String name, required int goalAmount, DateTime? deadline});
Future<void> renameTarget(int id, String name); // nama unik, trim
Future<void> deleteTarget(int id); // cascade deposit; transaksi transfer TIDAK ikut hapus
Future<TargetDeposit> depositToTarget({required int targetId, required int accountId, required int amount, DateTime? occurredAt});
Stream<List<TargetWithProgress>> watchTargets(); // progress = sum deposit per target
Future<int> targetDeposited(int targetId);
Future<int> sumSpendBetween(DateTime start, DateTime end); // keluar MURNI: outgoing TANPA kind transfer
Future<int> sumTargetTransferBetween(DateTime start, DateTime end); // Sisihkan: kind transfer + bankId 'target'
Future<Map<({int? category, int? account}), int>> outSpendPairsBetween(DateTime start, DateTime end); // mirror outPairsBetween + kind ≠ transfer (alokasi spend-murni, Plan 04)
```

- [ ] **Step 1: Tulis test gagal** —
  - `'sisihkan tercatat sebagai transfer, bukan keluar'`: deposit 200rb → `watchAccountBalances()[sumber]` turun 200rb; `targetDeposited` = 200rb; `watchTargets().progress` = 200rb/goal.
  - `'transfer biasa bukan belanja'`: catat transfer biasa 5jt (bankId bank asli) → `sumSpendBetween` 0; payment 40rb → 40rb; sisihkan 20rb → `sumTargetTransferBetween` 20rb.
  - `'deposit ≤0 ditolak'`, `'nama duplikat ditolak'`, `'hapus target: deposit hilang, transaksi tetap'`.
- [ ] **Step 2: Jalankan** `flutter test test/repository_test.dart --plain-name 'target'` — FAIL.
- [ ] **Step 3: Implementasi** di `lib/storage/repository.dart` (mirror `_defaultCategoryId` untuk kategori 'Transfer'; `sumSpendBetween`/`sumTargetTransferBetween` mirror `sumBetween` + filter kind/bankId).
- [ ] **Step 4: Jalankan** `flutter test test/repository_test.dart` — PASS.
- [ ] **Step 5: Commit** `feat(data): target + sisihkan model akun-virtual`.
### Task 4: Streak hari-disiplin di `ProgressService`

**Files:**
- Modify: `lib/game/progress.dart` (`refresh()` + `ProgressSummary.streakDays` tetap; tambah `streakPaused`)
- Modify: `lib/storage/repository.dart` (one-shot `outSpendByDaySince` (spend murni) + `outTargetByDaySince` (sisihan) — mirror `txCountByDaySince`; dipakai gabungan per hari)
- Test: `test/progress_test.dart` (group baru `'streak disiplin'`), `test/repository_test.dart` (case query harian)

**Interfaces:**
- Consumes: `dailyBar()` (Task 1); `sumSpendBetween`/`sumTargetTransferBetween` (Task 3); `kKeyDailyLimit/Weekly/MonthlyTotal`.
- Produces: `ProgressSummary.streakPaused` (`bool`: true bila `dailyBar == null`); streak: mundur dari hari ini; hari `(spend + sisihan) ≤ bar` (Rp0 lolos) lanjut; over = berhenti; transfer biasa tidak dihitung; berhenti di tanggal transaksi pertama; evaluasi ≤ 370 hari. Milestone `kStreakMilestones` tetap.

- [ ] **Step 1: Tulis test gagal** (setup `repo.setSetting(kKeyDailyLimit, ...)` + `addTxAt`) —
  - `'3 hari dalam jatah → streak 3'`, `'kemarin over → streak 0'`, `'hari Rp0 lolos'`, `'hari ini over → 0 sekarang'`, `'tanpa limit: streak 0 + streakPaused true'`, `'surut berhenti di transaksi pertama (bukan 365)'`, `'sisihan ikut menggerus jatah (T1)'`, `'transfer biasa bukan belanja (opsi A)'`.
- [ ] **Step 2: Jalankan** `flutter test test/progress_test.dart --plain-name 'streak disiplin'` — FAIL.
- [ ] **Step 3: Implementasi**: tambah `outSpendByDaySince` + `outTargetByDaySince` one-shot; ganti loop streak di `refresh()` (hapus loop counts-lama, gabung per hari: `(spend + target) ≤ dailyBar`); `streakPaused` dari `dailyBar == null`; `mood/_moodLineFor` pakai istilah "hari disiplin" (copy: sleepy→ relevan pause; pertahankan mood enum).
- [ ] **Step 4: Jalankan** `flutter test test/progress_test.dart test/repository_test.dart` — PASS (test lama streak-catatat WAJIB dihapus/diganti di step ini — kontrak berubah).
- [ ] **Step 5: Commit** `feat(game): streak hari-disiplin`.

### Task 5: Milestone sekali-per-run + verify penuh

**Files:**
- Modify: `lib/game/progress.dart` (`pendingMilestone` → cek setting `milestone_seen_{n}` via `getSetting/setSetting`; tulis sekali saat dirayakan)
- Modify: `test/progress_test.dart` (tambah case restart)

**Interfaces:**
- Consumes: `kStreakMilestones`, `getSetting/setSetting`.
- Produces: perilaku — refresh baru setelah restart TIDAK mengulang snack milestone yang sama; run baru (streak naik ke milestone berikutnya) tetap dirayakan.

- [ ] **Step 1: Tulis test gagal** — `'milestone tidak diulang setelah restart'`: capai 7 → consume → service baru (repo sama) + refresh → `pendingMilestone` null; lalu push ke 8? (bukan milestone) tetap null; simulasikan naik ke 14 → 14.
- [ ] **Step 2: Jalankan** — FAIL.
- [ ] **Step 3: Implementasi** — `_evaluate()` cek `getSetting('milestone_seen_$n')`; `consumePendingMilestone()` tulis setting sebelum return.
- [ ] **Step 4: Jalankan** `flutter test` (seluruh suite) — PASS; `flutter analyze` — zero issue.
- [ ] **Step 5: Commit** `feat(game): milestone streak sekali per run`.
