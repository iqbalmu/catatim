import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/budget.dart';
import '../core/money.dart';
import '../game/progress.dart';
import '../models.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Alur tambah kategori baru + alokasi awal opsional.

// Dipecah ke part files (audit I-01).
part 'rencana/cards.dart';
part 'rencana/dialogs.dart';

Future<void> showAddCategoryFlow(
  BuildContext context,
  LedgerRepository repository,
) async {
  final result = await showQuestDialog<_NewCategory>(
    context,
    title: 'Tambah Kategori Baru',
    content: _NewCategoryForm(),
    actions: [
      QuestButton(
        label: 'Batal',
        tone: QuestTone.secondary,
        onPressed: () => Navigator.pop(context),
      ),
      QuestButton(
        label: 'Tambah',
        icon: Icons.add_rounded,
        onPressed: () {
          final state = _NewCategoryForm.maybeOf(context);
          Navigator.pop(
            context,
            state == null
                ? null
                : _NewCategory(
                    name: state.nameCtrl.text,
                    limit: state.limitCtrl.text.trim().isEmpty
                        ? null
                        : int.tryParse(
                            state.limitCtrl.text.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            ),
                          ),
                  ),
          );
        },
      ),
    ],
  );
  if (result == null || result.name.trim().isEmpty) return;
  if (!context.mounted) return;
  try {
    final category = await repository.addCategory(result.name);
    if (result.limit != null && result.limit! > 0) {
      await repository.setBudget(category.id, result.limit!);
    }
    if (!context.mounted) return;
    questSnack(
      context,
      'Kategori "${category.name}" berhasil ditambahkan.',
      icon: Icons.check_rounded,
    );
  } catch (_) {
    if (!context.mounted) return;
    questSnack(
      context,
      'Nama kategori "${result.name}" sudah dipakai — coba nama lain.',
      icon: Icons.info_outline_rounded,
    );
  }
}

/// Segmen Batas layar Rencana (eks layar Anggaran): batas
/// harian/mingguan/bulanan, jenis anggaran yang bisa dikelola user +
/// alokasi dana (opsional di-scope per akun), dan progres masuk/keluar
/// bulan ini vs bulan lalu.
///
/// Pemakaian alokasi memakai pasangan belanja-murni (transfer
/// dikecualikan) — transfer biasa tidak menggerogoti alokasi Jenis.

class RencanaBatas extends StatefulWidget {
  const RencanaBatas({super.key, required this.repository, this.progress});

  final LedgerRepository repository;

  /// Opsional — sumber maskot meter, chip "vs bulan lalu", dan chip
  /// progres 7 hari (mockup v2.1). Null → kartu disiplin disembunyikan.
  final ProgressService? progress;

  @override
  State<RencanaBatas> createState() => _RencanaBatasState();
}

class _RencanaBatasState extends State<RencanaBatas> {
  /// Stream disematkan per bulan (bukan dibuat di build) agar rebuild
  /// biasa tak subscribe ulang (anti-kedip). Dibuat ulang hanya saat
  /// bulan berganti lewat [_ensureStreams].
  DateTime _usageMonth = DateTime(0);
  late Stream<({int day, int week, int month})> _usage;
  late Stream<List<Category>> _categories;
  late Stream<List<Budget>> _budgets;
  late Stream<List<Account>> _accounts;
  late Stream<Map<({int? category, int? account}), int>> _outPairs;
  late Stream<int?> _monthlyLimitStream;
  late Stream<int?> _weeklyLimitStream;
  late Stream<int?> _dailyLimitStream;

  @override
  void initState() {
    super.initState();
    _initLimitStreams();
  }

  void _initLimitStreams() {
    _monthlyLimitStream = widget.repository.watchIntSetting(kKeyMonthlyTotal);
    _weeklyLimitStream = widget.repository.watchIntSetting(kKeyWeeklyLimit);
    _dailyLimitStream = widget.repository.watchIntSetting(kKeyDailyLimit);
  }

  @override
  void didUpdateWidget(covariant RencanaBatas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _initLimitStreams();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);
    _ensureStreams(monthStart, monthEnd);
    return ListView(
      // Ekor list diberi clearance navbar floating (extendBody menyuntik
      // tinggi navbar sebagai padding.bottom).
      padding: EdgeInsets.fromLTRB(
        Spacing.m,
        Spacing.s,
        Spacing.m,
        Spacing.l + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        StreamBuilder<({int day, int week, int month})>(
          stream: _usage,
          builder: (context, usageSnap) {
            if (usageSnap.connectionState == ConnectionState.waiting) {
              return const QuestSkeleton(rows: 1, height: 80);
            }
            final usage = usageSnap.data;
            return StreamBuilder<int?>(
              stream: _monthlyLimitStream,
              builder: (context, monthSnap) {
                final monthlyTotal = monthSnap.data;
                return StreamBuilder<int?>(
                  stream: _weeklyLimitStream,
                  builder: (context, weekSnap) {
                    final weeklyLimit = weekSnap.data;
                    return StreamBuilder<int?>(
                      stream: _dailyLimitStream,
                      builder: (context, dailySnap) {
                        final dailyLimit = dailySnap.data;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Kartu batas bulanan utama
                            QuestTabEnter(
                              index: 1,
                              child: _BatasBulananCard(
                                used: usage?.month ?? 0,
                                limit: monthlyTotal,
                                onTap: () => _editLimit(
                                  title: 'Total bulanan',
                                  current: monthlyTotal,
                                  save: (v) => _saveLimit(kKeyMonthlyTotal, v),
                                ),
                              ),
                            ),
                            const SizedBox(height: Spacing.s),
                            Row(
                              children: [
                                Expanded(
                                  child: QuestTabEnter(
                                    index: 2,
                                    child: _LimitMiniCard(
                                      label: 'Mingguan',
                                      used: usage?.week ?? 0,
                                      limit: weeklyLimit,
                                      onTap: () => _editLimit(
                                        title: 'Batas mingguan',
                                        current: weeklyLimit,
                                        save: (v) => _saveLimit(kKeyWeeklyLimit, v),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Spacing.s),
                                Expanded(
                                  child: QuestTabEnter(
                                    index: 3,
                                    child: _LimitMiniCard(
                                      label: 'Harian',
                                      used: usage?.day ?? 0,
                                      limit: dailyLimit,
                                      onTap: () => _editLimit(
                                        title: 'Batas harian',
                                        current: dailyLimit,
                                        save: (v) => _saveLimit(kKeyDailyLimit, v),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
        const SizedBox(height: Spacing.m),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuestTabEnter(
              index: 4,
              child: Padding(
                padding: const EdgeInsets.only(top: Spacing.s),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Alokasi Anggaran Kategori',
                      style: context.qTitle(15),
                    ),
                    QuestPress(
                      onTap: () => showAddCategoryFlow(
                        context,
                        widget.repository,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: context.q.primaryLight,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 15,
                              color: context.q.primaryText,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Tambah',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: context.q.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.s),
            StreamBuilder<List<Category>>(
              stream: _categories,
              builder: (context, catSnap) {
                return StreamBuilder<List<Budget>>(
                  stream: _budgets,
                  builder: (context, budgetSnap) {
                    return StreamBuilder<List<Account>>(
                      stream: _accounts,
                      builder: (context, accSnap) {
                        return StreamBuilder<
                          Map<({int? category, int? account}), int>
                        >(
                          // Pemicu reaktif: watch semua keluar; datanya
                          // belanja-murni supaya transfer tidak
                          // menggerogoti alokasi Jenis.
                          stream: _outPairs,
                          builder: (context, usedSnap) {
                            final rawCategories =
                                catSnap.data ?? const <Category>[];
                            final categories = rawCategories
                                .where((c) => c.name != 'Transfer')
                                .toList();
                            final budgets = budgetSnap.data ?? const <Budget>[];
                            final accounts = accSnap.data ?? const <Account>[];
                            final used =
                                usedSnap.data ??
                                const <({int? category, int? account}), int>{};
                            if (categories.isEmpty) {
                              return QuestTabEnter(
                                index: 5,
                                child: QuestEmpty(
                                  title: 'Belum ada kategori',
                                  hint:
                                      'Tambah kategori pertama untuk mulai '
                                      'mengalokasikan anggaran.',
                                  actionLabel: 'Tambah Kategori',
                                  onAction: () => showAddCategoryFlow(
                                    context,
                                    widget.repository,
                                  ),
                                ),
                              );
                            }
                            final accountNames = {
                              for (final a in accounts) a.id: a.name,
                            };
                            final cards = <Widget>[
                              for (final c in categories) ...[
                                // Alokasi yang sudah ada (global + per akun).
                                for (final b in budgets.where(
                                  (b) => b.categoryId == c.id,
                                ))
                                  _AllocationRow(
                                    name: c.name,
                                    scopeLabel: b.accountId == null
                                        ? null
                                        : accountNames[b.accountId],
                                    used: _usedFor(used, b),
                                    limit: b.monthlyLimit,
                                    onTap: () => _manageCategoryAndBudget(
                                      c,
                                      existing: b,
                                      accounts: accounts,
                                    ),
                                  ),
                                // Kategori tanpa alokasi sama sekali.
                                if (!budgets.any((b) => b.categoryId == c.id))
                                  _AllocationRow(
                                    name: c.name,
                                    used: _usedForCategory(used, c.id),
                                    limit: null,
                                    onTap: () => _manageCategoryAndBudget(
                                      c,
                                      existing: null,
                                      accounts: accounts,
                                    ),
                                  ),
                              ],
                            ];
                            // Daftar baris penuh (mockup v2.1): nama + bar
                            // progres + "pakai/plafon" — bukan grid.
                            return Column(
                              children: [
                                for (var i = 0; i < cards.length; i++) ...[
                                  QuestTabEnter(index: 5 + i, child: cards[i]),
                                  const SizedBox(height: Spacing.s),
                                ],
                                const SizedBox(height: Spacing.xs),
                                QuestTabEnter(
                                  index: 5 + cards.length,
                                  child: QuestPress(
                                    onTap: () => showAddCategoryFlow(
                                      context,
                                      widget.repository,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.q.surface2,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.tile,
                                        ),
                                        border: Border.all(
                                          color: context.q.line.withValues(alpha: 0.6),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_circle_outline_rounded,
                                            size: 18,
                                            color: context.q.primaryText,
                                          ),
                                          const SizedBox(width: Spacing.xs),
                                          Text(
                                            'Tambah Kategori Baru',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: context.q.primaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  int _usedForCategory(
    Map<({int? category, int? account}), int> used,
    int categoryId,
  ) => used.entries
      .where((e) => e.key.category == categoryId)
      .fold(0, (total, e) => total + e.value);

  /// Isi ulang stream turunan bulan; idempoten — hanya bekerja saat
  /// bulan berganti, sehingga rebuild biasa memakai objek stream yang
  /// sama (tanpa subscribe ulang, tanpa kedip).
  void _ensureStreams(DateTime monthStart, DateTime monthEnd) {
    if (monthStart == _usageMonth) return;
    _usageMonth = monthStart;
    _usage = _limitsUsage();
    _categories = widget.repository.watchCategories();
    _budgets = widget.repository.watchBudgets();
    _accounts = widget.repository.watchAccounts();
    _outPairs = widget.repository
        .watchOutPairsBetween(monthStart, monthEnd)
        .asyncMap(
          (_) => widget.repository.outSpendPairsBetween(monthStart, monthEnd),
        );
  }

  /// Pemakaian belanja murni hari/minggu/bulan berjalan untuk kartu mini
  /// batas. Trigger reaktif: watchOutSumByDaySince (emit tiap transaksi
  /// keluar berubah); rentang dihitung ulang tiap emit — pola asyncMap
  /// yang sama dengan baris alokasi.

  Stream<({int day, int week, int month})> _limitsUsage() {
    final now = DateTime.now();
    return widget.repository
        .watchOutSumByDaySince(DateTime(now.year, now.month))
        .asyncMap((_) async {
          final at = DateTime.now();
          final today = DateTime(at.year, at.month, at.day);
          final dayEnd = DateTime(at.year, at.month, at.day + 1);
          final weekStart = today.subtract(Duration(days: at.weekday - 1));
          final monthStart = DateTime(at.year, at.month);
          final monthEnd = DateTime(at.year, at.month + 1);
          return (
            day: await widget.repository.sumSpendBetween(today, dayEnd),
            week: await widget.repository.sumSpendBetween(weekStart, dayEnd),
            month: await widget.repository.sumSpendBetween(
              monthStart,
              monthEnd,
            ),
          );
        });
  }

  int _usedFor(Map<({int? category, int? account}), int> used, Budget b) => used
      .entries
      .where(
        (e) =>
            e.key.category == b.categoryId &&
            (b.accountId == null || e.key.account == b.accountId),
      )
      .fold(0, (total, e) => total + e.value);

  Future<void> _saveLimit(String key, int? value) async {
    if (value == null) {
      // Tidak ada API hapus setting — simpan kosong agar tak terbaca.
      await widget.repository.setSetting(key, '');
      return;
    }
    await widget.repository.setSetting(key, '$value');
  }

  Future<void> _editLimit({
    required String title,
    required int? current,
    required Future<void> Function(int?) save,
  }) async {
    final value = await _askAmount(context, title: title, current: current);
    if (value == current) return;
    if (!mounted) return;
    await save(value);
    if (!mounted) return;
    questSnack(
      context,
      value == null ? '$title dihapus, ya.' : '$title tersimpan.',
      icon: Icons.check_rounded,
    );
  }

  /// Kelola kategori & anggaran sekaligus dalam 1 modal tunggal:
  /// ubah nama, atur/hapus batas alokasi, scope akun, dan hapus kategori.
  Future<void> _manageCategoryAndBudget(
    Category category, {
    required Budget? existing,
    required List<Account> accounts,
  }) async {
    final lainnya = (await widget.repository.watchCategories().first)
        .where((c) => c.name.toLowerCase() == 'lainnya' && c.id != category.id)
        .toList();
    final canDelete = category.name.toLowerCase() != 'lainnya';
    if (!mounted) return;
    final result = await _askCategoryAndBudget(
      context,
      category: category,
      currentLimit: existing?.monthlyLimit,
      currentAccount: existing?.accountId,
      accounts: accounts,
      canDelete: canDelete,
    );
    if (result == null || !mounted) return;

    if (result.delete) {
      if (lainnya.isEmpty) {
        questSnack(
          context,
          'Kategori "Lainnya" belum ada — transaksi butuh tempat pindah.',
          icon: Icons.info_outline_rounded,
        );
        return;
      }
      final sure = await showQuestDialog<bool>(
        context,
        title: 'Hapus Kategori?',
        content: Text(
          'Kategori "${category.name}" akan dihapus dan transaksinya dipindah ke kategori "Lainnya".',
          style: context.qBody(13),
        ),
        actions: [
          QuestButton(
            label: 'Batal',
            tone: QuestTone.secondary,
            onPressed: () => Navigator.pop(context, false),
          ),
          QuestButton(
            label: 'Hapus',
            tone: QuestTone.danger,
            icon: Icons.delete_outline_rounded,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      );
      if (sure != true || !mounted) return;

      await widget.repository.deleteCategory(
        category.id,
        fallbackId: lainnya.first.id,
      );
      if (!mounted) return;
      questSnack(
        context,
        'Kategori "${category.name}" dihapus — transaksi dipindah ke Lainnya.',
        icon: Icons.check_rounded,
      );
      return;
    }

    // Rename jika diubah
    if (result.name.isNotEmpty && result.name != category.name) {
      try {
        await widget.repository.renameCategory(category.id, result.name);
      } catch (_) {
        if (!mounted) return;
        questSnack(
          context,
          'Nama "${result.name}" sudah dipakai — nama tidak diubah.',
          icon: Icons.info_outline_rounded,
        );
      }
    }

    // Update atau hapus alokasi anggaran
    if (result.limit != null && result.limit! > 0) {
      if (existing != null && existing.accountId != result.accountId) {
        await widget.repository.removeBudget(
          category.id,
          accountId: existing.accountId,
        );
      }
      await widget.repository.setBudget(
        category.id,
        result.limit!,
        accountId: result.accountId,
      );
      if (!mounted) return;
      questSnack(
        context,
        'Anggaran ${result.name.isNotEmpty ? result.name : category.name} tersimpan.',
        icon: Icons.check_rounded,
      );
    } else {
      if (existing != null) {
        await widget.repository.removeBudget(
          category.id,
          accountId: existing.accountId,
        );
        if (!mounted) return;
        questSnack(
          context,
          'Batas anggaran dihapus.',
          icon: Icons.check_rounded,
        );
      } else {
        if (!mounted) return;
        questSnack(context, 'Perubahan tersimpan.', icon: Icons.check_rounded);
      }
    }
  }
}
