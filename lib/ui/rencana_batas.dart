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
  // Controllers milik flow ini, bukan state form: tombol aksi dirender
  // di luar subtree content, jadi tidak bisa membaca lewat
  // findAncestorStateOfType (selalu null → dialog selalu tutup kosong).
  // Dispose diserahkan ke _NewCategoryFormState.dispose() — future sheet
  // selesai saat pop, sebelum animasi keluar tuntas, jadi dispose di sini
  // bikin controller used-after-disposed saat konten masih rebuild.
  final nameCtrl = TextEditingController();
  final limitCtrl = TextEditingController();
  final result = await showQuestDialog<_NewCategory>(
    context,
    title: 'Tambah Kategori Baru',
    content: _NewCategoryForm(nameCtrl: nameCtrl, limitCtrl: limitCtrl),
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
          Navigator.pop(
            context,
            _NewCategory(
              name: nameCtrl.text,
              limit: limitCtrl.text.trim().isEmpty
                  ? null
                  : int.tryParse(
                      limitCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
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
      'Beres! Kategori "${category.name}" nambah.',
      icon: Icons.check_rounded,
    );
  } catch (_) {
    if (!context.mounted) return;
    questSnack(
      context,
      'Nama kategori "${result.name}" sudah dipakai, coba nama lain.',
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
  late Stream<Map<String, String>> _limitsStream;
  late Stream<Map<String, String>> _scopeCatsStream;

  @override
  void initState() {
    super.initState();
    _initLimitStreams();
  }

  void _initLimitStreams() {
    _limitsStream = widget.repository.watchSettings([
      for (final scope in LimitScope.values) scope.limitKey,
    ]);
    _scopeCatsStream = widget.repository.watchSettings([
      for (final scope in LimitScope.values) scope.categoriesKey,
    ]);
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
        // Kategori di-hoist: dipakai kartu batas (label cakupan) dan
        // daftar alokasi sekaligus.
        StreamBuilder<List<Category>>(
          stream: _categories,
          builder: (context, catSnap) {
            final categories = catSnap.data ?? const <Category>[];
            final categoryNames = {for (final c in categories) c.id: c.name};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLimitCards(categoryNames),
                const SizedBox(height: Spacing.m),
                _buildAllocationSection(categories),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Kartu batas global: bulanan (utama) + mingguan & harian (mini).
  /// Setiap batas punya cakupan kategorinya sendiri — angka "terpakai"
  /// hanya menghitung kategori yang dipilih user.
  Widget _buildLimitCards(Map<int, String> categoryNames) {
    return StreamBuilder<Map<String, String>>(
      stream: _scopeCatsStream,
      builder: (context, catsSnap) {
        final scopeCats =
            _scopeCategories(catsSnap.data ?? const {}, categoryNames);
        return StreamBuilder<Map<String, String>>(
          stream: _limitsStream,
          builder: (context, limitsSnap) {
            final limits = limitsSnap.data ?? const <String, String>{};
            final monthlyTotal =
                _intSetting(limits, LimitScope.monthly.limitKey);
            final weeklyLimit = _intSetting(limits, LimitScope.weekly.limitKey);
            final dailyLimit = _intSetting(limits, LimitScope.daily.limitKey);
            return StreamBuilder<({int day, int week, int month})>(
              stream: _usage,
              builder: (context, usageSnap) {
                if (usageSnap.connectionState == ConnectionState.waiting) {
                  return const QuestSkeleton(rows: 1, height: 80);
                }
                final usage = usageSnap.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kartu batas bulanan utama
                    QuestTabEnter(
                      index: 1,
                      child: _BatasBulananCard(
                        used: usage?.month ?? 0,
                        limit: monthlyTotal,
                        scopeNote: limitScopeNote(
                          scopeCats[LimitScope.monthly],
                          categoryNames,
                        ),
                        onTap: () => _editLimit(
                          scope: LimitScope.monthly,
                          current: monthlyTotal,
                          currentCategories: scopeCats[LimitScope.monthly],
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
                              scopeNote: limitScopeNote(
                                scopeCats[LimitScope.weekly],
                                categoryNames,
                              ),
                              onTap: () => _editLimit(
                                scope: LimitScope.weekly,
                                current: weeklyLimit,
                                currentCategories: scopeCats[LimitScope.weekly],
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
                              scopeNote: limitScopeNote(
                                scopeCats[LimitScope.daily],
                                categoryNames,
                              ),
                              onTap: () => _editLimit(
                                scope: LimitScope.daily,
                                current: dailyLimit,
                                currentCategories: scopeCats[LimitScope.daily],
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
  }

  /// Alokasi per kategori (opsional, scoped per akun).
  Widget _buildAllocationSection(List<Category> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestTabEnter(
          index: 4,
          child: Padding(
            padding: const EdgeInsets.only(top: Spacing.s),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Alokasi Anggaran Kategori',
                    style: context.qTitle(15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
        StreamBuilder<List<Budget>>(
          stream: _budgets,
          builder: (context, budgetSnap) {
            return StreamBuilder<List<Account>>(
              stream: _accounts,
              builder: (context, accSnap) {
                return StreamBuilder<Map<({int? category, int? account}), int>>(
                  // Pemicu reaktif: watch semua keluar; datanya
                  // belanja-murni supaya transfer tidak
                  // menggerogoti alokasi Jenis.
                  stream: _outPairs,
                  builder: (context, usedSnap) {
                    // Kategori "Transfer" tidak dialokasikan — dipakai
                    // perpindahan dana antar akun sendiri.
                    final visible = categories
                        .where((c) => c.name != 'Transfer')
                        .toList();
                    final budgets = budgetSnap.data ?? const <Budget>[];
                    final accounts = accSnap.data ?? const <Account>[];
                    final used =
                        usedSnap.data ??
                        const <({int? category, int? account}), int>{};
                    if (visible.isEmpty) {
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
                      for (final c in visible) ...[
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
                    // Grid 2 kolom: nama + bar progres + "pakai/plafon".
                    return Column(
                      children: [
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          mainAxisSpacing: Spacing.s,
                          crossAxisSpacing: Spacing.s,
                          childAspectRatio: 1.9,
                          children: [
                            for (var i = 0; i < cards.length; i++)
                              QuestTabEnter(
                                index: (5 + i).clamp(5, 13),
                                child: cards[i],
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
        ),
      ],
    );
  }

  /// Filter kategori tiap scope batas, dipruning terhadap kategori yang
  /// masih ada (kategori dihapus → dibuang dari filter).
  Map<LimitScope, Set<int>?> _scopeCategories(
    Map<String, String> settings,
    Map<int, String> categoryNames,
  ) {
    final existing = categoryNames.keys.toSet();
    return {
      for (final scope in LimitScope.values)
        scope: pruneLimitCategories(
          parseLimitCategories(settings[scope.categoriesKey]),
          existing,
        ),
    };
  }

  int? _intSetting(Map<String, String> settings, String key) {
    final text = settings[key]?.trim();
    if (text == null || text.isEmpty) return null;
    return int.tryParse(text);
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
  /// batas. Trigger reaktif: watchOutSpendTrigger (emit tiap transaksi
  /// keluar berubah ATAU filter kategori batas berubah); rentang dan
  /// filter dihitung ulang tiap emit.
  ///
  /// Tiap scope batas punya filter kategorinya sendiri — angka yang
  /// ditampilkan dibandingkan dengan plafon yang sama cakupannya.
  Stream<({int day, int week, int month})> _limitsUsage() {
    final now = DateTime.now();
    return widget.repository
        .watchOutSpendTrigger(DateTime(now.year, now.month))
        .asyncMap((_) async {
          final at = DateTime.now();
          final today = DateTime(at.year, at.month, at.day);
          final dayEnd = DateTime(at.year, at.month, at.day + 1);
          final weekStart = today.subtract(Duration(days: at.weekday - 1));
          final monthStart = DateTime(at.year, at.month);
          final monthEnd = DateTime(at.year, at.month + 1);
          final cats = await _storedScopeCategories();
          return (
            day: await widget.repository.sumSpendBetween(
              today,
              dayEnd,
              categories: cats[LimitScope.daily],
            ),
            week: await widget.repository.sumSpendBetween(
              weekStart,
              dayEnd,
              categories: cats[LimitScope.weekly],
            ),
            month: await widget.repository.sumSpendBetween(
              monthStart,
              monthEnd,
              categories: cats[LimitScope.monthly],
            ),
          );
        });
  }

  /// Filter kategori tersimpan per scope batas (belum dipruning — pruning
  /// terhadap kategori yang masih ada dilakukan saat tampilan).
  Future<Map<LimitScope, Set<int>?>> _storedScopeCategories() async {
    final raw = await widget.repository
        .watchSettings([
          for (final scope in LimitScope.values) scope.categoriesKey,
        ])
        .first;
    return {
      for (final scope in LimitScope.values)
        scope: parseLimitCategories(raw[scope.categoriesKey]),
    };
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

  /// Ubah nominal + cakupan kategori satu scope batas.
  Future<void> _editLimit({
    required LimitScope scope,
    required int? current,
    required Set<int>? currentCategories,
  }) async {
    final categories = await widget.repository.watchCategories().first;
    if (!mounted) return;
    final result = await _askLimitWithCategories(
      context,
      scope: scope,
      current: current,
      currentCategories: currentCategories,
      categories: categories,
    );
    if (result == null || !mounted) return;

    final amountChanged = result.amount != current;
    final catsChanged = !_sameCategories(result.categories, currentCategories);
    if (!amountChanged && !catsChanged) return;

    await _saveLimit(scope.limitKey, result.amount);
    await widget.repository.setLimitCategories(
      scope.categoriesKey,
      result.categories,
    );
    // Beranda menampilkan jatah harian dari snapshot yang sama — segarkan
    // supaya angka di sana tidak tertinggal.
    await widget.progress?.refresh();
    if (!mounted) return;

    final names = {for (final c in categories) c.id: c.name};
    final scopeText =
        limitScopeNote(result.categories, names) ?? 'semua kategori';
    final parts = <String>[
      if (amountChanged)
        result.amount == null ? 'batas dihapus' : Money.format(result.amount!),
      if (catsChanged) scopeText,
    ];
    questSnack(
      context,
      parts.isEmpty
          ? '${scope.label} tersimpan!'
          : '${scope.label} tersimpan! — ${parts.join(' · ')}',
      icon: Icons.check_rounded,
    );
  }

  bool _sameCategories(Set<int>? a, Set<int>? b) {
    if (a == null || b == null) return a == b;
    return a.length == b.length && a.containsAll(b);
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
          'Kategori "Lainnya" belum ada. Transaksi butuh tempat pindah.',
          icon: Icons.info_outline_rounded,
        );
        return;
      }
      final sure = await showQuestDialog<bool>(
        context,
        title: 'Hapus Kategori?',
        content: Text(
          'Kategori "${category.name}" bakal dihapus dan transaksinya pindah ke kategori "Lainnya".',
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
        'Kategori "${category.name}" dihapus. Transaksi dipindah ke Lainnya.',
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
          'Nama "${result.name}" sudah dipakai, nama tidak diubah.',
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
        'Beres! Anggaran ${result.name.isNotEmpty ? result.name : category.name} tersimpan.',
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
        questSnack(context, 'Sip, perubahan tersimpan!', icon: Icons.check_rounded);
      }
    }
  }
}
