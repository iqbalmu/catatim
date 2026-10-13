# M1 Beranda Baru — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Beranda menjawab "boleh habis berapa hari ini?" dan "uangku di mana?" tanpa buka layar lain — kartu pace harian, saldo per akun, dan insight mini di bawah hero maskot yang tetap.

**Architecture:** Perhitungan baru hidup di engine murni `core/budget.dart` (`DailyPace`, level alokasi per akun), dihitung `ProgressService.refresh` dan query repository, lalu dirender tiga widget baru `ui/home_cards.dart` yang menyalin gaya hero card. UI tanpa widget test sesuai keputusan terbuka di ROADMAP.

**Tech:** Flutter + drift (schema v6), tanpa dependensi baru.

**Spec:** `docs/ROADMAP.md` bagian **M1 — Beranda baru** (+ konvensi `docs/ARCHITECTURE.md`).

## Global Constraints

- Copy UI bahasa Indonesia; nominal selalu via `Money.format` (int rupiah).
- `lib/core/` tetap bebas import drift/Flutter (ADR-003).
- Gaya hanya via widget kit `lib/ui/quest.dart` + token `context.q` (ADR-008); angka pakai `FontFeature.tabularFigures()`.
- Tanpa widget test UI (keputusan terbuka ROADMAP); logika baru wajib test engine dulu (TDD).
- Tanpa dependensi pubspec baru.

## Review Focus

1. Batas tersimpan `0`/negatif → diperlakukan tanpa batas, bukan pembagian nol. Test: Task 1.
2. Hari terakhir bulan: pembagi sisa-hari minimal 1. Test: Task 1 (hari 31).
3. `safeToSpend` negatif tetap negatif dari engine; UI yang menandai OVER. Test: Task 1 + Task 5 (render).
4. Bulan pendek (Feb 29): `daysInMonth` dari `DateTime`, bukan konstanta 30. Test: Task 1.
5. `outSumByDaySince` inklusif hari `since`; hari sebelum `since` terpotong. Test: Task 4.

---

### Task 1: `DailyPace` — engine pace harian

**Files:**
- Modify: `lib/core/budget.dart` (tambah di akhir file)
- Test: `test/budget_engine_test.dart` (group baru)

**Interfaces (Produces):**
```dart
class DailyPace {
  final int? safeToSpend;     // null = tanpa batas apa pun; boleh negatif
  final int dayOfMonth;       // 1-based
  final int daysInMonth;
  final int idealUsedPercent; // round(day/daysInMonth*100)
}

DailyPace dailyPace({
  required DateTime now,
  required int dayOut,      // keluar hari ini
  required int weekOut,     // keluar sejak Senin termasuk hari ini
  required int monthOut,    // keluar bulan berjalan
  int? dailyLimit,
  int? weeklyLimit,
  int? monthlyTotal,        // batas bulan berjalan
});
```
Prioritas: harian → mingguan → bulanan → `null`. Limit `<= 0` = tanpa batas.
- Harian: `dailyLimit - dayOut`.
- Mingguan: `(weeklyLimit - weekOut) / daysLeftWeek`, `daysLeftWeek = 7 - now.weekday + 1` (Senin = 1).
- Bulanan: `(monthlyTotal - monthOut) / daysLeftMonth`, `daysLeftMonth = daysInMonth - day + 1`.
- Pembagian dibulatkan ke bawah ke rupiah penuh. `daysInMonth = DateTime(y, m+1).difference(DateTime(y, m)).inDays`.

- [ ] **Step 1: Tulis test gagal** di `test/budget_engine_test.dart` — group `'pace harian'`, pakai `now = DateTime(2026, 10, 11)` (Minggu, 31 hari):
  - `'prioritas harian di atas mingguan/bulanan'`: daily 50000, dayOut 42500, weekly+monthly juga diisi → `safeToSpend == 7500`.
  - `'harian over tetap negatif'`: dayOut 60000 → `safeToSpend == -10000`.
  - `'fallback mingguan: sisa minggu dibagi sisa hari'`: hanya weekly 300000, weekOut 100000, `now.weekday == 7` → `200000`; versi `DateTime(2026, 10, 7)` (Rabu) → `40000`.
  - `'fallback bulanan: sisa bulan dibagi sisa hari'`: hanya monthly 3100000, monthOut 1000000 → `100000` (2100000/21).
  - `'tanpa batas apa pun: null'` → `safeToSpend == null`.
  - `'limit nol diperlakukan tanpa batas'`: `dailyLimit: 0` + lainnya null → `null`.
  - `'idealUsedPercent dan dimensi bulan'`: `idealUsedPercent == 35`, `dayOfMonth == 11`, `daysInMonth == 31`; `DateTime(2024, 2, 1)` → `daysInMonth == 29`, `idealUsedPercent == 3`.
- [ ] **Step 2: Jalankan** `flutter test test/budget_engine_test.dart` — harapkan FAIL "dailyPace isn't defined".
- [ ] **Step 3: Implementasi** `DailyPace` + `dailyPace()` di `lib/core/budget.dart` sesuai signature di atas.
- [ ] **Step 4: Jalankan** `flutter test test/budget_engine_test.dart` — PASS.
- [ ] **Step 5: Commit** `feat(budget): daily pace engine`.

### Task 2: Level alokasi per akun (dot SaldoCard)

**Files:**
- Modify: `lib/core/budget.dart`
- Test: `test/budget_engine_test.dart`

**Interfaces:**
- Consumes: `Budget` (drift row: `categoryId`, `accountId int?`, `monthlyLimit int`), `LimitLine.level`.
- Produces:
```dart
BudgetLevel? accountBudgetLevel({
  required List<Budget> budgets,
  required Map<({int? category, int? account}), int> usage, // bentuk outPairsBetween
  required int accountId,
}); // null = akun tanpa alokasi ber-scope; hanya alokasi ber-scope akun itu yang dinilai
```

- [ ] **Step 1: Test gagal** — group `'level alokasi per akun'`: budget (cat 5, acc 1, limit 100000); usage `{(5, 1): 150000}` → `BudgetLevel.over`; `80000` → `warning`; `50000` → `ok`; akun 2 tanpa alokasi ber-scope → `null`; alokasi global (`accountId` null) tidak mengubah dot akun → `null`.
- [ ] **Step 2: Jalankan** — FAIL.
- [ ] **Step 3: Implementasi** — hitung used per budget ber-scope dari usage (key `.category == categoryId && .account == accountId`), ambil terburuk.
- [ ] **Step 4: Jalankan** — PASS.
- [ ] **Step 5: Commit** `feat(budget): per-account allocation level`.

### Task 3: `ProgressSummary.dailyPace` + `outSumByDaySince`

**Files:**
- Modify: `lib/game/progress.dart` (field + hitung di `refresh`)
- Modify: `lib/storage/repository.dart` (method baru, mirror `txCountByDaySince` di baris ~269)
- Test: `test/progress_test.dart`, `test/repository_test.dart` (ikuti setup helper yang sudah ada di masing-masing file)

**Interfaces:**
- Consumes: `dailyPace()` (Task 1).
- Produces: `ProgressSummary.dailyPace` (`DailyPace?`); `Future<Map<DateTime, int>> outSumByDaySince(DateTime since)` — keluar per hari lokal, **inklusif** hari `since`.

- [ ] **Step 1: Test gagal** `progress_test.dart`: setup mengikuti test `'over batas harian → mood worried + alert realtime'` (set `budget_daily_limit`, catat tx keluar hari ini) → tambah assertion `summary.dailyPace?.safeToSpend == batasHarian - nominalTx`.
- [ ] **Step 2: Jalankan** `flutter test test/progress_test.dart` — FAIL.
- [ ] **Step 3: Implementasi** — `refresh()` sudah punya `dailyLimit/weekLimit/monthTotalLimit/dayOut/weekOut/monthOut/now`; panggil `dailyPace(...)` dan masukkan ke `ProgressSummary`.
- [ ] **Step 4: Jalankan** — PASS.
- [ ] **Step 5: Test gagal** `repository_test.dart` (mirror test `txCountByDaySince` bila ada; kalau tidak, seed manual): tx keluar 5000 hari ini, 7000 kemarin, 9000 6 hari lalu, 11000 31 hari lalu; `outSumByDaySince(today - 29d)` → hari ini 5000, kemarin 7000, tanpa 11000; `outSumByDaySince(today)` → hanya hari ini.
- [ ] **Step 6: Jalankan** — FAIL.
- [ ] **Step 7: Implementasi** `outSumByDaySince` di `repository.dart`, pola sama dengan `txCountByDaySince` (SUM keluar, group per hari lokal, `isBetween(occurredAt, since, endOfTodayExclusive)`).
- [ ] **Step 8: Jalankan** — PASS.
- [ ] **Step 9: Commit** `feat(data): daily pace in summary + daily out sums`.

### Task 4: Tiga kartu beranda + navigasi

**Files:**
- Create: `lib/ui/home_cards.dart` (`PaceCard`, `SaldoCard`, `InsightCard`, `_Sparkline` painter)
- Modify: `lib/ui/home_screen.dart` (`_BerandaTab`: sisip 3 kartu setelah `GameHeroCard`; `HomeScreen`: tambah `onOpenReports` ala `onOpenHistory`, kirim ke `_BerandaTab`)

**Interfaces:**
- Consumes: `DailyPace` (Task 3 via `ProgressSummary`), `accountBudgetLevel` (Task 2), `watchAccountBalances`, `watchAccounts`, `watchBudgets`, `outPairsBetween`, `outSumByDaySince`, `watchCategories`, `Money.format`, `QuestCard`/`QuestBar`/`QuestSegmented`/`QuestSectionHeader`.
- Produces: `PaceCard({required ProgressService service})` (ListenableBuilder), `SaldoCard({required LedgerRepository repository})` (tap → `AccountManageScreen`), `InsightCard({required LedgerRepository repository, required VoidCallback onOpenReports})`.

Aturan render (dikunci):
- **PaceCard**: judul `context.qEyebrow()` "SISA AMAN HARI INI"; angka besar `context.qDisplay(34)` `Money.format(safeToSpend)`; `safeToSpend == null` → teks "Tanpa batas — atur di menu ⋯ → Anggaran" (tone `q.muted`), tanpa angka; `safeToSpend < 0` → label "OVER" merah (`q.bad`) dan angka tetap negatif; sub-baris `"tgl ${p.dayOfMonth} · ideal ${p.idealUsedPercent}%"` + `QuestBar` fraksi `dayOfMonth/daysInMonth`.
- **SaldoCard**: header "SALDO" + total (fold balances); satu baris per akun: nama, `Money.format(balance)`, dot 8px warna `accountBudgetLevel` (over→`q.bad`, warning→`q.honey`, ok→`q.good`, null→`q.line`); seluruh kartu tap → push `AccountManageScreen`.
- **InsightCard**: `QuestSegmented` "7 hari"/"30 hari" (default 7) → `outSumByDaySince(now - (n-1)d)` → `_Sparkline` (`CustomPainter`, polyline `q.honey`, garis dasar `q.line`, tinggi 48); di bawah: 3 kategori teratas bulan berjalan dari `outPairsBetween(monthStart, monthEnd)` difold per kategori + nama dari `watchCategories` — baris "nama · Money.format(sum)"; tap kartu → `onOpenReports()`.

- [ ] **Step 1: Tulis** `lib/ui/home_cards.dart` sesuai aturan render di atas (pola gaya: `game/hero_card.dart` `_BudgetRow`).
- [ ] **Step 2: Wire** `home_screen.dart`: `onOpenReports` (index tab 2), sisip kartu: `GameHeroCard` → `PaceCard` → `SaldoCard` → `InsightCard` → seksi "Hari ini" yang ada.
- [ ] **Step 3: Jalankan** `flutter analyze` — zero issue.
- [ ] **Step 4: Commit** `feat(home): pace, balances, and insight cards`.

### Task 5: Verifikasi penuh + smoke

- [ ] **Step 1:** `flutter test` — seluruh suite PASS (termasuk 74 test lama).
- [ ] **Step 2:** `flutter analyze` — zero issue.
- [ ] **Step 3: Smoke** — `flutter devices`; bila ada device/emulator: `flutter run`, cek beranda (kartu pace angka sesuai data seed, saldo per akun, sparkline, tap kartu → Laporan, tap saldo → Kelola Akun). Bila tidak ada device: `flutter build apk --debug` sebagai smoke kompilasi dan catat jujur bahwa permukaan visual belum terverifikasi.
- [ ] **Step 4:** Update `docs/ROADMAP.md` — centang M1 selesai (pindah ke "Selesai" dengan catatan hasil smoke).
- [ ] **Step 5:** Commit `docs: mark M1 beranda baru done`.
