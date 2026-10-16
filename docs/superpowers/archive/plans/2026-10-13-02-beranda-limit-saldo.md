# Tab Beranda Baru — 3 Limit + Saldo

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Beranda menjawab ①②③⑤⑥ sekali lirik: hero sisa aman + 3 kartu limit + mini keluar/masuk + baris SALDO + alert — tanpa daftar transaksi, tanpa ubin Tren/Kategori/Kewajiban/Jejak.

**Architecture:** Hapus `TrendTile`, `OutTile`, `InTile` (diganti ringkas), `KategoriCard`, `KewajibanStrip`, `JejakStrip` dari `_BerandaTab`; buat `LimitCard` (dailyBar + spendable) + `SaldoRow`; semua via stream/service agar segar; `LimitCard` tap → Rencana·Batas (deep-link via Plan 5 kontrak — sementara tap → halaman Batas bila Plan 5 belum ada, dengan TODO eksplisit).

**Tech Stack:** Flutter (widget kit `ui/quest.dart` + `context.q`); tanpa dependensi baru.

**Spec:** `docs/superpowers/specs/2026-10-13-informasi-navigasi-design.md` (§4 Beranda, §5 alur A/G). Butuh Plan 1 (`dailyBar`, spendable) selesai dulu.

## Global Constraints

- Copy UI bahasa Indonesia; nominal selalu via `Money.format` (int rupiah).
- `lib/core/` tetap bebas import drift/Flutter (ADR-003).
- Gaya hanya via widget kit `lib/ui/quest.dart` + token `context.q` (ADR-008); angka pakai `FontFeature.tabularFigures()`.
- Tanpa widget test UI; logika baru wajib test engine dulu (TDD).
- Tanpa dependensi pubspec baru.
- Sisihkan mengurangi sisa H/M/B + saldo-spendable; BUKAN keluar/masuk (§10 T1).

## Review Focus

1. Total SALDO negatif (utang > aset karena akun manual) — tampil merah, bukan disembunyikan; pin di smoke manual Task 3.
2. LimitCard saat periode ganti (tengah malam / Senin / tanggal 1) — nilai segar tanpa restart; andalkan stream + refresh.
3. SafeToSpend negatif di kartu bulanan — tampil "-RpX · OVER", engine tetap negatif murni.
4. Tap kartu limit saat Plan 5 belum ada — fallback yang jelas, bukan crash.
5. Beranda tetap ringan: tanpa query baru di build (pakai service/repository stream yang ada).

---

### Task 1: Keluar-efektif — spend + sisihan (engine + pakai)

**Files:**
- Modify: `lib/core/budget.dart` (tambah `spendPlusTarget`)
- Modify: `lib/game/progress.dart` (`refresh()`: dayOut/weekOut/monthOut efektif untuk pace + garis global; `monthOut/monthIn` statistik tetap murni)
- Test: `test/budget_engine_test.dart` (group `'keluar efektif'`), `test/progress_test.dart` (case pace)

**Interfaces:**
- Consumes: Plan 01 Task 3 (`sumSpendBetween`, `sumTargetTransferBetween`).
- Produces:
```dart
int spendPlusTarget({required int spend, required int targetTransfer});
```
= `spend + targetTransfer` (tanpa floor — pace boleh OVER). Statistik `monthOut` tetap spend murni; transfer biasa tidak masuk ke mana pun (keputusan pemilik opsi A).

- [ ] **Step 1: Tulis test gagal** — engine: `(spend: 40000, target: 20000)` → `60000`; `(0, 0)` → `0`. Progress: daily 50rb + payment 40rb + sisihkan 20rb → `safeToSpend == -10000`; `monthOut == 40000`; transfer biasa 5jt → pace tidak berubah.
- [ ] **Step 2: Jalankan** `flutter test test/budget_engine_test.dart test/progress_test.dart` — FAIL.
- [ ] **Step 3: Implementasi** — `spendPlusTarget()` + `refresh()`: `dayEff = (await sumSpendBetween(today, dayEnd)) + (await sumTargetTransferBetween(today, dayEnd))` (idem minggu/bulan) untuk pace + garis global; statistik tetap `sumBetween` murni.
- [ ] **Step 4: Jalankan** `flutter test test/budget_engine_test.dart test/progress_test.dart` — PASS.
- [ ] **Step 5: Commit** `feat(game): pace memakai spend + sisihan`.

### Task 2: Beranda baru (UI) + smoke

**Files:**
- Modify: `lib/ui/home_cards.dart` (tambah `LimitCard`, `SaldoRow`, `MiniInOut`; hapus TrendTile/OutTile/InTile/KategoriCard/KewajibanStrip/JejakStrip DARI BERANDA — file-nya tetap, dipakai Plan 3)
- Modify: `lib/ui/home_screen.dart` (`_BerandaTab` susun ulang; `_destinations` tetap 4 — Plan 5 yang mengganti)
- Test: TIDAK ADA (tanpa widget test UI)

**Interfaces:**
- Consumes: `ProgressService.latest` (pace, snapshot, streakDays, mood), `watchAccountBalances()`, `watchAccounts()`, `Money.format`, `QuestCard/QuestBar`, `dailyBar()`.
- Produces: `LimitCard({required String label, required int? limit, required int used, required int safe, required VoidCallback onTap})` — judul "HARIAN/MINGGUAN/BULANAN", angka sisa besar, bar fraksi, sub "dipakai X dari Y · reset …"; `SaldoRow({repository})` — "SALDO RpX · blu RpA · Nagari RpB · Tunai RpC", tap → Kelola Akun.

- [ ] **Step 1: Susun `_BerandaTab`**: Hero → strip alert → 3 LimitCard (Harian/Mingguan/Bulanan) → MiniInOut (keluar+masuk bln, ringkas) → SaldoRow. Hapus pemakaian ubin/kartu lama dari Beranda. Tap LimitCard → `BudgetScreen` (fallback sampai Plan 5; tandai `// TODO(plan5): deep-link Rencana·Batas`).
- [ ] **Step 2: Jalankan** `flutter analyze` — zero issue.
- [ ] **Step 3: Smoke** emulator/device: seed (limit harian 50rb + keluar 40rb + sisihkan 20rb) → hero OVER −10rb; 3 kartu tampil; SaldoRow tap → Kelola Akun; `flutter test` PASS.
- [ ] **Step 4: Commit** `feat(home): beranda 3 limit + saldo`.
