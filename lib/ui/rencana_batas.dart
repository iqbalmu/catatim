import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/budget.dart';
import '../core/dates_id.dart';
import '../core/money.dart';
import '../game/mascot.dart';
import '../game/progress.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Alur tambah jenis anggaran baru (kategori) + alokasi awal opsional.
/// Dipakai tombol "Tambah" segmen Batas dan FAB "＋ Jenis" layar Rencana.
Future<void> showAddJenisFlow(
  BuildContext context,
  LedgerRepository repository,
) async {
  final result = await showQuestDialog<_NewCategory>(
    context,
    title: 'Tambah jenis anggaran',
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
      'Jenis "${category.name}" berhasil ditambahkan.',
      icon: Icons.check_rounded,
    );
  } catch (_) {
    if (!context.mounted) return;
    questSnack(
      context,
      'Nama "${result.name}" sudah dipakai — coba nama lain, ya.',
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
              children: [
                // Kartu batas utama — fokus harian + maskot meter
                // (mockup v2.1). Mingguan/bulanan tetap tersedia di bawah.
                _BatasUtamaCard(
                  used: usage?.day ?? 0,
                  limit: _dailyLimit,
                  progress: widget.progress,
                  onTap: () => _editLimit(
                    title: 'Batas harian',
                    current: _dailyLimit,
                    save: (v) async {
                      await _saveLimit(kKeyDailyLimit, v);
                      setState(() => _dailyLimit = v);
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
                        label: 'Bulanan',
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
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: Spacing.m),
        // Chip progres 7 hari terakhir (mockup v2.1) — menggantikan
        // kartu Disiplin di Beranda; ringkasan disiplin sekali lihat.
        _WeeklyProgressCard(progress: widget.progress),
        const SizedBox(height: Spacing.m),
        Row(
          children: [
            Expanded(
              child: Text(
                'Jenis anggaran & alokasi',
                style: context.qEyebrow(),
              ),
            ),
            QuestPress(
              onTap: _addCategoryFlow,
              child: Text(
                'Tambah',
                style: TextStyle(
                  color: context.q.honey,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
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
                          return const QuestSkeleton(rows: 2);
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
                                onEdit: () => _editAllocation(
                                  c,
                                  existing: b,
                                  accounts: accounts,
                                ),
                                onManage: () => _manageCategory(c),
                              ),
                            // Kategori tanpa alokasi sama sekali.
                            if (!budgets.any((b) => b.categoryId == c.id))
                              _AllocationRow(
                                name: c.name,
                                used: _usedForCategory(used, c.id),
                                limit: null,
                                onEdit: () => _editAllocation(
                                  c,
                                  existing: null,
                                  accounts: accounts,
                                ),
                                onManage: () => _manageCategory(c),
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

  /// Edit alokasi satu kategori: nominal + scope akun.
  Future<void> _editAllocation(
    Category category, {
    required Budget? existing,
    required List<Account> accounts,
  }) async {
    final result = await _askAllocation(
      context,
      title: 'Alokasi ${category.name}',
      currentLimit: existing?.monthlyLimit,
      currentAccount: existing?.accountId,
      accounts: accounts,
    );
    if (result == null || !mounted) return;
    if (result.remove) {
      await widget.repository.removeBudget(
        category.id,
        accountId: existing?.accountId,
      );
    } else {
      await widget.repository.setBudget(
        category.id,
        result.limit ?? 0,
        accountId: result.account,
      );
    }
    if (!mounted) return;
    questSnack(
      context,
      result.remove
          ? 'Alokasi ${category.name} dihapus, ya.'
          : 'Alokasi ${category.name} tersimpan.',
      icon: Icons.check_rounded,
    );
  }

  /// Tambah jenis anggaran baru (kategori) + alokasi awal opsional.
  Future<void> _addCategoryFlow() =>
      showAddJenisFlow(context, widget.repository);

  /// Kelola satu jenis anggaran: ubah nama atau hapus (transaksi pindah
  /// ke "Lainnya").
  Future<void> _manageCategory(Category category) async {
    final lainnya = (await widget.repository.watchCategories().first)
        .where((c) => c.name.toLowerCase() == 'lainnya' && c.id != category.id)
        .toList();
    if (!mounted) return;
    final result = await showQuestDialog<_ManageCategory>(
      context,
      title: 'Kelola "${category.name}"',
      content: _ManageCategoryForm(currentName: category.name),
      actions: [
        QuestButton(
          label: 'Hapus jenis',
          icon: Icons.delete_outline_rounded,
          tone: QuestTone.danger,
          onPressed: () => Navigator.pop(
            context,
            _ManageCategory(remove: true, newName: null),
          ),
        ),
        QuestButton(
          label: 'Simpan',
          icon: Icons.check_rounded,
          onPressed: () {
            final state = _ManageCategoryForm.maybeOf(context);
            Navigator.pop(
              context,
              _ManageCategory(
                remove: false,
                newName: state?.nameCtrl.text.trim(),
              ),
            );
          },
        ),
      ],
    );
    if (result == null || !mounted) return;
    try {
      if (result.remove) {
        if (lainnya.isEmpty) {
          questSnack(
            context,
            'Kategori "Lainnya" belum ada — transaksinya butuh tempat pindah.',
            icon: Icons.info_outline_rounded,
          );
          return;
        }
        await widget.repository.deleteCategory(
          category.id,
          fallbackId: lainnya.first.id,
        );
        if (!mounted) return;
        questSnack(
          context,
          '"${category.name}" dihapus — transaksinya pindah ke Lainnya.',
          icon: Icons.check_rounded,
        );
      } else if (result.newName != null &&
          result.newName!.isNotEmpty &&
          result.newName != category.name) {
        await widget.repository.renameCategory(category.id, result.newName!);
        if (!mounted) return;
        questSnack(
          context,
          'Nama berubah jadi "${result.newName}".',
          icon: Icons.check_rounded,
        );
      }
    } catch (_) {
      if (!mounted) return;
      questSnack(
        context,
        'Nama "${result.newName}" sudah dipakai — coba nama lain, ya.',
        icon: Icons.info_outline_rounded,
      );
    }
  }
}

/// Hasil dialog alokasi.
class _AllocationResult {
  const _AllocationResult({
    required this.remove,
    required this.limit,
    required this.account,
  });

  final bool remove;
  final int? limit;
  final int? account;
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

/// Dialog alokasi: nominal + scope akun (semua atau satu akun).
Future<_AllocationResult?> _askAllocation(
  BuildContext context, {
  required String title,
  required int? currentLimit,
  required int? currentAccount,
  required List<Account> accounts,
}) {
  final limitCtrl = TextEditingController(
    text: currentLimit == null ? '' : '$currentLimit',
  );
  int? scope = currentAccount;
  return showQuestDialog<_AllocationResult>(
    context,
    title: title,
    content: StatefulBuilder(
      builder: (context, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: limitCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Alokasi bulanan (rupiah)',
            ),
          ),
          const SizedBox(height: Spacing.m),
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
                DropdownMenuItem<int?>(value: a.id, child: Text(a.name)),
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
      if (currentLimit != null)
        QuestButton(
          label: 'Hapus alokasi',
          tone: QuestTone.danger,
          onPressed: () => Navigator.pop(
            context,
            _AllocationResult(remove: true, limit: null, account: null),
          ),
        ),
      QuestButton(
        label: 'Simpan',
        icon: Icons.check_rounded,
        onPressed: () => Navigator.pop(
          context,
          _AllocationResult(
            remove: false,
            limit: limitCtrl.text.trim().isEmpty
                ? 0
                : Money.parseGroup(limitCtrl.text),
            account: scope,
          ),
        ),
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
            labelText: 'Nama jenis anggaran',
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

class _ManageCategory {
  const _ManageCategory({required this.remove, required this.newName});
  final bool remove;
  final String? newName;
}

class _ManageCategoryForm extends StatefulWidget {
  const _ManageCategoryForm({required this.currentName});

  static _ManageCategoryFormState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<_ManageCategoryFormState>();

  final String currentName;

  @override
  State<_ManageCategoryForm> createState() => _ManageCategoryFormState();
}

class _ManageCategoryFormState extends State<_ManageCategoryForm> {
  late final nameCtrl = TextEditingController(text: widget.currentName);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: nameCtrl,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(labelText: 'Nama jenis anggaran'),
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
          boxShadow: [
            BoxShadow(
              color: q.shadow,
              offset: const Offset(0, 6),
              blurRadius: 18,
            ),
          ],
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
            Text(
              line == null ? 'Belum diatur' : _ringkasRp(used),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: line == null ? q.muted : (over ? q.bad : q.text),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: Spacing.xs),
            if (line != null) ...[
              QuestBar(
                value: line.fraction,
                height: 5,
                color: switch (line.level) {
                  BudgetLevel.over => q.bad,
                  BudgetLevel.warning => q.honey,
                  BudgetLevel.ok => q.good,
                },
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                over ? 'over · plafon ${_ringkasRp(limit!)}' : '/ ${_ringkasRp(limit!)}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: over ? FontWeight.w700 : FontWeight.w400,
                  color: over ? q.bad : q.muted,
                ),
              ),
            ] else
              Text(
                'tap untuk atur',
                style: TextStyle(fontSize: 9, color: q.muted),
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
    required this.onEdit,
    required this.onManage,
    this.scopeLabel,
  });

  final String name;
  final String? scopeLabel;
  final int used;
  final int? limit;
  final VoidCallback onEdit;
  final VoidCallback onManage;

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
        boxShadow: [
          BoxShadow(
            color: q.shadow,
            offset: const Offset(0, 6),
            blurRadius: 18,
          ),
        ],
      ),
      child: QuestPress(
        onTap: onEdit,
        child: Container(
          // Transparan tapi opaque untuk hit-test: seluruh permukaan kartu
          // bisa ditap, bukan hanya teks/barnya.
          color: Colors.transparent,
          padding: Insets.tile,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Tap nama = kelola jenis; sisanya = edit alokasi.
              Row(
                children: [
                  Expanded(
                    child: QuestPress(
                      onTap: onManage,
                      child: Text(
                        scopeLabel == null ? name : '$name · $scopeLabel',
                        style: context.qTitle(13).copyWith(
                          color: line == null ? q.muted : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.xs),
                  Icon(Icons.edit_rounded, size: 14, color: q.muted),
                ],
              ),
              Text(
                line == null
                    ? 'belum dialokasikan'
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
                        BudgetLevel.warning => q.honey,
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
class _BatasUtamaCard extends StatelessWidget {
  const _BatasUtamaCard({
    required this.used,
    required this.limit,
    required this.onTap,
    this.progress,
  });

  final int used;
  final int? limit;
  final VoidCallback onTap;
  final ProgressService? progress;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final hasLimit = limit != null && limit! > 0;
    final sisa = (limit ?? 0) - used;
    final over = hasLimit && sisa < 0;
    final fraction = hasLimit ? (used / limit!).clamp(0.0, 1.0) : 0.0;
    final mood = progress?.latest?.mood ?? MascotMood.idle;

    // Chip "vs bulan lalu" — dari snapshot fair mid-month.
    String? vsChip;
    var vsGood = false;
    final snap = progress?.latest;
    if (snap != null && snap.snapshot.lastMonthOut > 0) {
      final pct =
          ((snap.monthOut - snap.snapshot.lastMonthOut) * 100 /
                  snap.snapshot.lastMonthOut)
              .round();
      if (pct != 0) {
        vsGood = pct < 0;
        vsChip = '${pct.abs()}% ${vsGood ? 'lebih hemat' : 'lebih boros'}'
            ' · vs bulan lalu';
      }
    }

    return QuestCard(
      onTap: onTap,
      radius: AppRadius.sheet,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Sisa aman hari ini', style: context.qEyebrow(10)),
                    if (hasLimit) ...[
                      const Spacer(),
                      Container(
                        padding: Insets.chip,
                        decoration: BoxDecoration(
                          color: over
                              ? SeedColors.outgoingTint
                              : SeedColors.incomingTint,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          over ? 'OVER' : 'Aman',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: over
                                ? SeedColors.outgoing
                                : SeedColors.incoming,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Spacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    !hasLimit
                        ? 'Tanpa batas'
                        : over
                            ? '−${Money.format(-sisa)}'
                            : Money.format(sisa),
                    style: context.qDisplay(27).copyWith(
                          color: over ? q.bad : null,
                        ),
                  ),
                ),
                const SizedBox(height: Spacing.s),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Stack(
                    children: [
                      Container(height: 10, color: q.line.withValues(alpha: .7)),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fraction,
                        child: Container(
                          height: 10,
                          color: over
                              ? q.bad
                              : const Color(0xFFE8B36B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  !hasLimit
                      ? 'Tap untuk mengatur batas harian'
                      : 'Pakai ${Money.format(used)} dari ${Money.format(limit!)}',
                  style: context.qSmall(11),
                ),
                if (vsChip != null) ...[
                  const SizedBox(height: Spacing.xxs),
                  Container(
                    padding: Insets.chip,
                    decoration: BoxDecoration(
                      color: vsGood
                          ? SeedColors.incomingTint
                          : SeedColors.outgoingTint,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      vsChip,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: vsGood
                            ? SeedColors.incoming
                            : SeedColors.outgoing,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Spacing.m),
          // Maskot = meter (ADR-007): ekspresi mengikuti kondisi nyata.
          // Berdiri di panggung supaya jadi penanda utama kartu, bukan
          // ikon kecil di pinggir.
          RepaintBoundary(
            child: MascotStage(
              mood: over ? MascotMood.worried : mood,
              size: 76,
              glow: SeedColors.honey50,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip progres 7 hari terakhir dari data disiplin bulan berjalan —
/// ringkasan disiplin sekali lihat (mockup v2.1). Tanpa [progress] atau
/// tanpa batas: kartu disembunyikan (jangan mengganggu).
class _WeeklyProgressCard extends StatelessWidget {
  const _WeeklyProgressCard({this.progress});

  final ProgressService? progress;

  @override
  Widget build(BuildContext context) {
    final snap = progress?.latest;
    final rows = snap?.disciplineMonth ?? const <DailyDiscipline>[];
    if (rows.isEmpty) return const SizedBox.shrink();

    final last7 = rows.where((d) => !d.future).toList();
    if (last7.isEmpty) return const SizedBox.shrink();
    if (last7.length > 7) last7.removeRange(0, last7.length - 7);

    return QuestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progres 7 hari terakhir', style: context.qTitle(14)),
          const SizedBox(height: Spacing.s),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final d in last7)
                  Padding(
                    padding: const EdgeInsets.only(right: Spacing.xs),
                    child: Container(
                      padding: Insets.chip,
                      decoration: BoxDecoration(
                        color: d.within
                            ? SeedColors.incomingTint
                            : SeedColors.outgoingTint,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '${idDaysShort[d.day.weekday - 1]} '
                        '${d.within ? 'aman' : 'OVER'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: d.within
                              ? SeedColors.incoming
                              : SeedColors.outgoing,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
