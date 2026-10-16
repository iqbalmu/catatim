# Shell Navigasi — 4 Tab + FAB + Back

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cutover navigasi: navbar 4 item (Beranda·Rekap·Rencana·Bon) + FAB melayang kontekstual + back-antar-tab + badge Bon + header global; tab lama (Riwayat/Laporan) dan layar Anggaran dipensiunkan.

**Architecture:** `lib/ui/home_screen.dart` jadi shell 4 tab (`RekapScreen`, `RencanaScreen`, `BonTab`, Beranda baru); hapus `QuestBottomNav.centerAction`; FAB `Scaffold.floatingActionButton` per-tab via `ValueListenable`/callback segmen aktif; back via `PopScope`; badge Bon dari `watchBons()` umur > 30 hari; file lama (`history_screen.dart`, `report_screen.dart`, `budget_screen.dart`) dihapus di task terakhir + README/ROADMAP diperbarui.

**Tech Stack:** Flutter (kit `ui/quest.dart`); tanpa dependensi baru.

**Spec:** `docs/superpowers/specs/2026-10-13-informasi-navigasi-design.md` (§4 navbar + chrome, §5 back/FAB/badge, §6 coret). Butuh Plan 2–4 selesai dulu (atau kerjakan paralel dengan stub? — **Keputusan plan: berurutan**, Plan 5 terakhir).

## Global Constraints

- Copy UI bahasa Indonesia; nominal selalu via `Money.format` (int rupiah).
- `lib/core/` tetap bebas import drift/Flutter (ADR-003).
- Gaya hanya via widget kit `lib/ui/quest.dart` + token `context.q` (ADR-008); angka pakai `FontFeature.tabularFigures()`.
- Tanpa widget test UI; logika baru wajib test engine dulu (TDD).
- Tanpa dependensi pubspec baru.

## Review Focus

1. Back dari sheet/dialog dalam tab non-Beranda — menutup sheet dulu, bukan loncat ke Beranda; pin di smoke Task 3.
2. Badge Bon tepat 30 vs 31 hari (batas inklusif?) — **Keputusan plan:** `> 30` (H-31 tidak badge, H-31+ badge? — pin: umur dalam hari kalender `today - occurredAt`; badge bila `> 30`).
3. Ketuk tab aktif saat sheet terbuka — sheet tetap, daftar ke atas? (putuskan: tab-tap hanya saat tidak ada route di atas; else abaikan).
4. `centerAction` dihapus — tidak ada pemanggil sisa (grep wajib Task 4).
5. Deep-link awal (notifikasi? tidak ada) — tidak perlu; cukup state internal.

---

### Task 1: Shell 4 tab + FAB melayang (cutover)

**Files:**
- Modify: `lib/ui/home_screen.dart` (`_destinations` → Beranda/Rekap/Rencana/Bon; `IndexedStack` 4 anak; hapus `centerAction`; `floatingActionButton` + label per tab/segmen)
- Modify: `lib/ui/quest.dart` (`QuestBottomNav`: hapus `centerAction` — BREAKING, satu-satunya pemanggil adalah home_screen)
- Test: TIDAK ADA (UI)

**Interfaces:**
- Consumes: `RekapScreen({repository})` (Plan 3), `RencanaScreen({repository, initialSegment})` (Plan 4), `BonTab` (tetap), `RencanaScreen.fabLabelFor(segment)` (Plan 4 Task 3).
- Produces: shell dengan FAB label: Beranda/Rekap = "Catat transaksi" · Rencana·Batas = "＋ Jenis" (→ dialog di Rencana via callback? **Keputusan plan:** FAB di shell memanggil `GlobalKey` metode publik `RencanaScreenState.openAdd()`? — TERLALU rumit; sederhanakan: FAB selalu milik masing-masing tab (tiap tab punya Scaffold sendiri + FAB sendiri), shell hanya nav. Rencana·Target FAB = "Sisihkan" milik RencanaScreen; Bon FAB = "Catat bon" milik BonTab.)

- [ ] **Step 1: Ubah** `_destinations` + `IndexedStack` + hapus `centerAction` dari nav & kit.
- [ ] **Step 2: FAB per-tab** — tiap tab Scaffold+`floatingActionButton` sendiri (pola CaptureLogScreen/FAB Bon yang ada).
- [ ] **Step 3: Jalankan** `flutter analyze` zero issue; `flutter test` PASS.
- [ ] **Step 4: Commit** `feat(nav): shell 4 tab + FAB per tab`.

### Task 2: Header global + badge Bon + back-antar-tab

**Files:**
- Modify: `lib/ui/home_screen.dart` (lonceng+⋯ di semua tab — ekstrak `_GlobalActions` dipakai tiap tab), `lib/ui/bon_screen.dart` (tambah badge? — badge tampil di NAV, hitung di shell via `watchBons()`)
- Modify: `lib/game/progress.dart`? TIDAK — umur bon dihitung di shell: `watchBons().map((list) => list.any((b) => b.settledAt == null && today.difference(dayOf(b.occurredAt)).inDays > 30))`
- Test: engine kecil? umur-bon murni `DateTime.difference` — **Keputusan plan:** tanpa engine, inline 1 baris + smoke.

**Interfaces:**
- Produces: badge merah di ikon Bon nav + badge lonceng (sudah ada); `PopScope(canPop: _tab == 0, onPopInvoked: kembali ke tab 0)`.

- [ ] **Step 1: Header global** — `_GlobalActions` (lonceng + ⋯) dipakai Beranda/Rekap/Rencana/Bon.
- [ ] **Step 2: Badge Bon** — stream di shell, `Badge(isLabelVisible: adaTua)` pada destinasi Bon.
- [ ] **Step 3: Back** — `PopScope` di shell.
- [ ] **Step 4: Jalankan** `flutter analyze` zero issue.
- [ ] **Step 5: Smoke** — back di Rekap → Beranda; back Beranda → keluar; badge muncul dengan bon 31 hari (seed manual); `flutter test` PASS.
- [ ] **Step 6: Commit** `feat(nav): header global + badge + back`.

### Task 3: Pensiun tab lama + docs + verify akhir

**Files:**
- Delete: `lib/ui/history_screen.dart`, `lib/ui/report_screen.dart`, `lib/ui/budget_screen.dart` (+ file perantara bila Plan 3/4 membuat `*_lama` — TIDAK ADA: plan 3/4 mengekstrak, file lama tetap dipakai sebagai sumber lalu dihapus di sini)
- Modify: `README.md` (struktur + fitur), `docs/ROADMAP.md` (status), `docs/superpowers/specs/...design.md` (Status → DISETUJUI & diimplementasikan? — TIDAK: biarkan DRAF sampai user menyetujui; plan tidak mengubah status spek)
- Test: TIDAK ADA

- [ ] **Step 1: Hapus** file lama; `grep -r "HistoryTab\|ReportTab\|BudgetScreen\|centerAction" lib test` — kosong.
- [ ] **Step 2: Update** README + ROADMAP (fitur Rekap/Rencana/Target/Kalender/streak disiplin; M1 direvisi? — cukup catat "arsitektur info v2").
- [ ] **Step 3: Jalankan** `flutter analyze` zero issue; `flutter test` FULL PASS; smoke akhir semua alur A–K di emulator.
- [ ] **Step 4: Commit** `feat(nav): pensiun tab lama, docs v2`.
