import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/budget.dart';
import '../core/money.dart';
import '../game/progress.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Alur tambah kategori baru + alokasi awal opsional.
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
  int? _dailyLimit;
  int? _weeklyLimit;
  int? _monthlyTotal;

  /// Stream disematkan per bulan (bukan dibuat di build) agar rebuild
  /// biasa tak subscribe ulang (anti-kedip). Dibuat ulang hanya saat
  /// bulan berganti lewat [_ensureStreams].
  DateTime _usageMonth = DateTime(0);
  late Stream<({int day, int week, int month})> _usage;
  late Stream<List<Category>> _categories;
  late Stream<List<Budget>> _budgets;
  late Stream<List<Account>> _accounts;
  late Stream<Map<({int? category, int? account}), int>> _outPairs;

  @override
  void initState() {
    super.initState();
    _loadLimits();
  }

  Future<void> _loadLimits() async {
    final daily = int.tryParse(
      await widget.repository.getSetting(kKeyDailyLimit) ?? '',
    );
    final weekly = int.tryParse(
      await widget.repository.getSetting(kKeyWeeklyLimit) ?? '',
    );
    final monthly = int.tryParse(
      await widget.repository.getSetting(kKeyMonthlyTotal) ?? '',
    );
    if (!mounted) return;
    setState(() {
      _dailyLimit = daily;
      _weeklyLimit = weekly;
      _monthlyTotal = monthly;
    });
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kartu batas bulanan utama
                _BatasBulananCard(
                  used: usage?.month ?? 0,
                  limit: _monthlyTotal,
                  onTap: () => _editLimit(
                    title: 'Total bulanan',
                    current: _monthlyTotal,
                    save: (v) async {
                      await _saveLimit(kKeyMonthlyTotal, v);
                      setState(() => _monthlyTotal = v);
                    },
                  ),
                ),
                const SizedBox(height: Spacing.s),
                Row(
                  children: [
                    Expanded(
                      child: _LimitMiniCard(
                        label: 'Mingguan',
                        used: usage?.week ?? 0,
                        limit: _weeklyLimit,
                        onTap: () => _editLimit(
                          title: 'Batas mingguan',
                          current: _weeklyLimit,
                          save: (v) async {
                            await _saveLimit(kKeyWeeklyLimit, v);
                            setState(() => _weeklyLimit = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.s),
                    Expanded(
                      child: _LimitMiniCard(
                        label: 'Harian',
                        used: usage?.day ?? 0,
                        limit: _dailyLimit,
                        onTap: () => _editLimit(
                          title: 'Batas harian',
                          current: _dailyLimit,
                          save: (v) async {
                            await _saveLimit(kKeyDailyLimit, v);
                            setState(() => _dailyLimit = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: Spacing.m),
        Padding(
          padding: const EdgeInsets.only(top: Spacing.s),
          child: Text(
            'KATEGORI & ALOKASI ANGGARAN',
            style: context.qEyebrow(11),
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
                      // belanja-murni supaya transfer tidak menggerogoti
                      // alokasi Jenis.
                      stream: _outPairs,
                      builder: (context, usedSnap) {
                        final categories = catSnap.data ?? const <Category>[];
                        final budgets = budgetSnap.data ?? const <Budget>[];
                        final accounts = accSnap.data ?? const <Account>[];
                        final used =
                            usedSnap.data ??
                            const <({int? category, int? account}), int>{};
                        if (categories.isEmpty) {
                          return QuestEmpty(
                            title: 'Belum ada kategori',
                            hint: 'Tambah kategori pertama untuk mulai mengalokasikan anggaran.',
                            actionLabel: 'Tambah Kategori',
                            onAction: () => showAddCategoryFlow(context, widget.repository),
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
                            for (final card in cards) ...[
                              card,
                              const SizedBox(height: Spacing.s),
                            ],
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
        questSnack(
          context,
          'Perubahan tersimpan.',
          icon: Icons.check_rounded,
        );
      }
    }
  }
}

/// Hasil dialog alokasi.
class _CategoryBudgetResult {
  const _CategoryBudgetResult({
    required this.name,
    required this.limit,
    required this.accountId,
    required this.delete,
  });

  final String name;
  final int? limit;
  final int? accountId;
  final bool delete;
}

/// Dialog input nominal rupiah. Simpan kosong → null (hapus);
/// Batal/sentuh luar → current (batal, tak ada perubahan).
Future<int?> _askAmount(
  BuildContext context, {
  required String title,
  required int? current,
}) {
  final ctrl = TextEditingController(text: current == null ? '' : '$current');
  const cancelled = -1;
  const deleted = -2;
  return showQuestDialog<int>(
    context,
    title: title,
    content: TextField(
      controller: ctrl,
      autofocus: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
        labelText: 'Nominal (rupiah)',
        hintText: 'Kosongkan kalau mau menghapus batas ini',
      ),
    ),
    actions: [
      QuestButton(
        label: 'Batal',
        tone: QuestTone.secondary,
        onPressed: () => Navigator.pop(context, cancelled),
      ),
      QuestButton(
        label: 'Simpan',
        icon: Icons.check_rounded,
        onPressed: () => Navigator.pop(
          context,
          ctrl.text.trim().isEmpty ? deleted : Money.parseGroup(ctrl.text),
        ),
      ),
    ],
  ).then((value) {
    // Sentuh luar dialog → null: anggap batal, bukan hapus.
    if (value == null || value == cancelled) return current;
    if (value == deleted) return null;
    return value;
  });
}

/// Modal gabungan satu pintu: ubah nama kategori, atur batas bulanan,
/// pilih scope akun, atau hapus kategori.
Future<_CategoryBudgetResult?> _askCategoryAndBudget(
  BuildContext context, {
  required Category category,
  required int? currentLimit,
  required int? currentAccount,
  required List<Account> accounts,
  required bool canDelete,
}) {
  final nameCtrl = TextEditingController(text: category.name);
  final limitCtrl = TextEditingController(
    text: currentLimit != null && currentLimit > 0 ? '$currentLimit' : '',
  );
  int? scope = currentAccount;

  return showQuestDialog<_CategoryBudgetResult>(
    context,
    title: 'Kelola Kategori & Anggaran',
    content: StatefulBuilder(
      builder: (context, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama kategori',
              hintText: 'Contoh: Makanan',
            ),
          ),
          const SizedBox(height: Spacing.s),
          TextField(
            controller: limitCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              prefixText: 'Rp ',
              labelText: 'Batas bulanan',
              hintText: 'Kosongkan jika tanpa batas',
            ),
          ),
          const SizedBox(height: Spacing.s),
          DropdownButtonFormField<int?>(
            initialValue: scope,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Berlaku di akun'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Semua akun'),
              ),
              for (final a in accounts)
                DropdownMenuItem<int?>(
                  value: a.id,
                  child: Text(a.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setDialogState(() => scope = v),
          ),
        ],
      ),
    ),
    actions: [
      QuestButton(
        label: 'Batal',
        tone: QuestTone.secondary,
        onPressed: () => Navigator.pop(context),
      ),
      if (canDelete)
        QuestButton(
          label: 'Hapus',
          tone: QuestTone.danger,
          onPressed: () => Navigator.pop(
            context,
            const _CategoryBudgetResult(
              name: '',
              limit: null,
              accountId: null,
              delete: true,
            ),
          ),
        ),
      QuestButton(
        label: 'Simpan',
        icon: Icons.check_rounded,
        onPressed: () {
          final limitVal = limitCtrl.text.trim().isEmpty
              ? null
              : int.tryParse(limitCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
          Navigator.pop(
            context,
            _CategoryBudgetResult(
              name: nameCtrl.text.trim(),
              limit: limitVal,
              accountId: scope,
              delete: false,
            ),
          );
        },
      ),
    ],
  );
}
class _NewCategory {
  const _NewCategory({required this.name, required this.limit});
  final String name;
  final int? limit;
}

/// Form state holder agar tombol dialog bisa membaca isi TextField.
class _NewCategoryForm extends StatefulWidget {
  static _NewCategoryFormState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<_NewCategoryFormState>();

  @override
  State<_NewCategoryForm> createState() => _NewCategoryFormState();
}

class _NewCategoryFormState extends State<_NewCategoryForm> {
  final nameCtrl = TextEditingController();
  final limitCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nama kategori',
            hintText: 'Contoh: Makanan',
          ),
        ),
        const SizedBox(height: Spacing.m),
        TextField(
          controller: limitCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Alokasi bulanan (opsional)',
            hintText: 'Contoh: 2000000',
          ),
        ),
      ],
    );
  }
}

/// Format ringkas untuk kartu mini: '18rb', '1,4jt' — tanpa 'Rp' agar
/// muat di sepertiga lebar layar.
String _ringkasRp(int v) {
  if (v >= 1000000) {
    final jt = v / 1000000;
    final s = jt == jt.roundToDouble()
        ? jt.round().toString()
        : jt.toStringAsFixed(1).replaceAll('.', ',');
    return '${s}jt';
  }
  if (v >= 1000) return '${(v / 1000).round()}rb';
  return '$v';
}

/// Kartu mini satu batas: terpakai berjalan + bar status + plafon.
/// Tap → dialog edit plafon. Pola visual sama dengan [_AllocationRow]
/// (over = latar merah pudar, warning = madu, ok = hijau).
class _LimitMiniCard extends StatelessWidget {
  const _LimitMiniCard({
    required this.label,
    required this.used,
    required this.limit,
    required this.onTap,
  });

  final String label;
  final int used;
  final int? limit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final line = limit == null
        ? null
        : LimitLine(label: label, used: used, limit: limit!);
    final over = line?.level == BudgetLevel.over;
    return QuestPress(
      onTap: onTap,
      child: Container(
        padding: Insets.tile,
        decoration: BoxDecoration(
          color: over ? q.bad.withValues(alpha: 0.12) : q.surface,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(color: q.line),
          boxShadow: AppShadows.card,
        ),
        child: Container(
          // Transparan tapi opaque untuk hit-test: seluruh permukaan
          // kartu bisa ditap, bukan hanya teks/barnya.
          color: Colors.transparent,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 10, color: q.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                Icon(Icons.edit_rounded, size: 13, color: q.muted),
              ],
            ),
            const SizedBox(height: Spacing.xxs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                line == null ? 'Belum diatur' : _ringkasRp(used),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: line == null ? q.muted : (over ? q.bad : q.text),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: Spacing.xs),
            if (line != null) ...[
              QuestBar(
                value: line.fraction,
                height: 5,
                color: switch (line.level) {
                  BudgetLevel.over => q.bad,
                  BudgetLevel.warning => q.warn,
                  BudgetLevel.ok => q.good,
                },
              ),
              const SizedBox(height: Spacing.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  over ? 'over · plafon ${_ringkasRp(limit!)}' : '/ ${_ringkasRp(limit!)}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: over ? FontWeight.w700 : FontWeight.w500,
                    color: over ? q.bad : q.muted,
                  ),
                ),
              ),
            ] else
              Text(
                'Tap untuk atur',
                style: TextStyle(fontSize: 10.5, color: q.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu satu jenis: nama + ikon kelola di kiri, angka ringkas di
/// kanan, bar tipis di bawah. Tap kartu = edit alokasi; tap nama =
/// kelola jenis. Over = latar merah pudar.
class _AllocationRow extends StatelessWidget {
  const _AllocationRow({
    required this.name,
    required this.used,
    required this.limit,
    required this.onTap,
    this.scopeLabel,
  });

  final String name;
  final String? scopeLabel;
  final int used;
  final int? limit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final line = limit == null
        ? null
        : LimitLine(label: name, used: used, limit: limit!);
    final over = line?.level == BudgetLevel.over;

    return Container(
      decoration: BoxDecoration(
        color: over ? q.bad.withValues(alpha: 0.12) : q.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: q.line),
        boxShadow: AppShadows.card,
      ),
      child: QuestPress(
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          padding: Insets.tile,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      scopeLabel == null ? name : '$name · $scopeLabel',
                      style: context.qTitle(14).copyWith(
                        color: line == null ? q.muted : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Spacing.xs),
                  Icon(Icons.edit_rounded, size: 14, color: q.muted),
                ],
              ),
              Text(
                line == null
                    ? (used > 0 ? 'Terpakai ${_ringkasRp(used)} · belum ada batas' : 'Belum dialokasikan')
                    : '${_ringkasRp(used)} / ${_ringkasRp(limit!)}'
                          ' · ${line.usedPercent}%${over ? ' over' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: over ? FontWeight.w700 : FontWeight.w400,
                  color: over ? q.bad : q.muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              QuestBar(
                value: line?.fraction ?? 0,
                height: 6,
                color: line == null
                    ? q.line
                    : switch (line.level) {
                        BudgetLevel.over => q.bad,
                        BudgetLevel.warning => q.warn,
                        BudgetLevel.ok => q.good,
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu batas utama: fokus harian dengan maskot meter di kanan —
/// "sisa aman hari ini" (mockup v2.1). Tap = edit batas harian.
class _BatasBulananCard extends StatelessWidget {
  const _BatasBulananCard({
    required this.used,
    required this.limit,
    required this.onTap,
  });

  final int used;
  final int? limit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final hasLimit = limit != null && limit! > 0;
    final isOver = hasLimit && used >= limit!;
    final sisa = (limit ?? 0) - used;
    final fraction = hasLimit ? (used / limit!).clamp(0.0, 1.0) : 0.0;

    Color progressColor;
    if (isOver) {
      progressColor = q.bad;
    } else if (fraction >= 0.75) {
      progressColor = q.warn;
    } else {
      progressColor = q.good;
    }

    return QuestCard(
      variant: QuestCardVariant.hero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: SeedColors.primaryLight,
                        borderRadius: BorderRadius.circular(AppRadius.cell),
                      ),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        color: q.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: Spacing.s),
                    Flexible(
                      child: Text(
                        'Batas Total Bulanan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.qTitle(16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasLimit
                      ? (isOver ? SeedColors.outgoingTint : SeedColors.incomingTint)
                      : q.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  hasLimit
                      ? (isOver ? 'Over ${Money.format(used - limit!)}' : 'Sisa ${Money.format(sisa)}')
                      : 'Belum diatur',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: hasLimit
                        ? (isOver ? q.bad : q.good)
                        : q.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.m),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    hasLimit
                        ? '${Money.format(used)} / ${Money.format(limit!)}'
                        : 'Tap untuk mengatur batas bulanan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: hasLimit ? q.text : q.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.s),
              if (hasLimit)
                Text(
                  '${(used * 100 / limit!).round()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: progressColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.s),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: q.surface2,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }
}

