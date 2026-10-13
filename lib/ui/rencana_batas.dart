import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/budget.dart';
import '../core/money.dart';
import '../models.dart';
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
    title: 'Jenis anggaran baru',
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
      'Jenis anggaran "${category.name}" ditambahkan.',
      icon: Icons.check_rounded,
    );
  } catch (_) {
    if (!context.mounted) return;
    questSnack(
      context,
      'Nama "${result.name}" sudah dipakai.',
      icon: Icons.info_outline_rounded,
    );
  }
}

/// Segmen Batas layar Rencana (eks BudgetScreen): batas
/// harian/mingguan/bulanan, jenis anggaran yang bisa dikelola user +
/// alokasi dana (opsional di-scope per akun), dan progres masuk/keluar
/// bulan ini vs bulan lalu.
///
/// Pemakaian alokasi memakai pasangan belanja-murni (transfer
/// dikecualikan) — transfer biasa tidak menggerogoti alokasi Jenis.
class RencanaBatas extends StatefulWidget {
  const RencanaBatas({super.key, required this.repository});

  final LedgerRepository repository;

  @override
  State<RencanaBatas> createState() => _RencanaBatasState();
}

class _RencanaBatasState extends State<RencanaBatas> {
  int? _dailyLimit;
  int? _weeklyLimit;
  int? _monthlyTotal;

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
    final lastMonthStart = DateTime(now.year, now.month - 1);
    final lastMonthEnd = lastMonthStart.add(monthEnd.difference(monthStart));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.m,
        Spacing.s,
        Spacing.m,
        Spacing.l,
      ),
      children: [
        Text('Batas pengeluaran', style: context.qEyebrow()),
        const SizedBox(height: Spacing.s),
        _LimitRow(
          label: 'Batas harian',
          hint: 'Maks keluar per hari',
          value: _dailyLimit,
          onEdit: () => _editLimit(
            title: 'Batas harian',
            current: _dailyLimit,
            save: (v) async {
              await _saveLimit(kKeyDailyLimit, v);
              setState(() => _dailyLimit = v);
            },
          ),
        ),
        _LimitRow(
          label: 'Batas mingguan',
          hint: 'Maks keluar per minggu',
          value: _weeklyLimit,
          onEdit: () => _editLimit(
            title: 'Batas mingguan',
            current: _weeklyLimit,
            save: (v) async {
              await _saveLimit(kKeyWeeklyLimit, v);
              setState(() => _weeklyLimit = v);
            },
          ),
        ),
        _LimitRow(
          label: 'Total bulanan',
          hint: 'Maks keluar sebulan',
          value: _monthlyTotal,
          onEdit: () => _editLimit(
            title: 'Total bulanan',
            current: _monthlyTotal,
            save: (v) async {
              await _saveLimit(kKeyMonthlyTotal, v);
              setState(() => _monthlyTotal = v);
            },
          ),
        ),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: context.q.honey),
                  const SizedBox(width: 2),
                  Text(
                    'Tambah',
                    style: TextStyle(
                      color: context.q.honey,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.s),
        StreamBuilder<List<Category>>(
          stream: widget.repository.watchCategories(),
          builder: (context, catSnap) {
            return StreamBuilder<List<Budget>>(
              stream: widget.repository.watchBudgets(),
              builder: (context, budgetSnap) {
                return StreamBuilder<List<Account>>(
                  stream: widget.repository.watchAccounts(),
                  builder: (context, accSnap) {
                    return StreamBuilder<
                      Map<({int? category, int? account}), int>
                    >(
                      // Pemicu reaktif: watch semua keluar; datanya
                      // belanja-murni supaya transfer tidak menggerogoti
                      // alokasi Jenis.
                      stream: widget.repository
                          .watchOutPairsBetween(monthStart, monthEnd)
                          .asyncMap(
                            (_) => widget.repository.outSpendPairsBetween(
                              monthStart,
                              monthEnd,
                            ),
                          ),
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
                        return Column(
                          children: [
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
                            const SizedBox(height: Spacing.s),
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
        Text('Progres bulan ini', style: context.qEyebrow()),
        const SizedBox(height: Spacing.s),
        StreamBuilder<int>(
          stream: widget.repository.watchSumBetween(
            monthStart,
            monthEnd,
            Direction.incoming,
          ),
          builder: (context, snap) => StreamBuilder<int>(
            stream: widget.repository.watchSumBetween(
              monthStart,
              monthEnd,
              Direction.outgoing,
            ),
            builder: (context, outSnap) => StreamBuilder<int>(
              stream: widget.repository.watchSumBetween(
                lastMonthStart,
                lastMonthEnd,
                Direction.incoming,
              ),
              builder: (context, lastInSnap) => StreamBuilder<int>(
                stream: widget.repository.watchSumBetween(
                  lastMonthStart,
                  lastMonthEnd,
                  Direction.outgoing,
                ),
                builder: (context, lastOutSnap) {
                  final monthIn = snap.data ?? 0;
                  final monthOut = outSnap.data ?? 0;
                  final lastIn = lastInSnap.data ?? 0;
                  final lastOut = lastOutSnap.data ?? 0;
                  return Row(
                    children: [
                      Expanded(
                        child: _ProgressCard(
                          label: 'Masuk',
                          amount: monthIn,
                          previous: lastIn,
                          incoming: true,
                        ),
                      ),
                      const SizedBox(width: Spacing.s),
                      Expanded(
                        child: _ProgressCard(
                          label: 'Keluar',
                          amount: monthOut,
                          previous: lastOut,
                          incoming: false,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
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
    if (value == null && current == null) return;
    if (!mounted) return;
    await save(value);
    if (!mounted) return;
    questSnack(
      context,
      value == null ? '$title dihapus.' : '$title disimpan.',
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
          ? 'Alokasi ${category.name} dihapus.'
          : 'Alokasi ${category.name} disimpan.',
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
            'Butuh kategori "Lainnya" sebagai penampung.',
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
          'Nama diubah menjadi "${result.newName}".',
          icon: Icons.check_rounded,
        );
      }
    } catch (_) {
      if (!mounted) return;
      questSnack(
        context,
        'Nama "${result.newName}" sudah dipakai.',
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

/// Dialog input nominal rupiah. Kosong → null (hapus).
Future<int?> _askAmount(
  BuildContext context, {
  required String title,
  required int? current,
}) {
  final ctrl = TextEditingController(text: current == null ? '' : '$current');
  const cancelled = -1;
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
        hintText: 'Kosongkan untuk hapus',
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
          ctrl.text.trim().isEmpty ? null : Money.parseGroup(ctrl.text),
        ),
      ),
    ],
  ).then((value) => value == cancelled ? current : value);
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

class _LimitRow extends StatelessWidget {
  const _LimitRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.onEdit,
  });

  final String label;
  final String hint;
  final int? value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestPress(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: Spacing.s),
        decoration: BoxDecoration(
          color: q.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: q.shadow,
              offset: const Offset(0, 6),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.qTitle(14)),
                  Text(hint, style: TextStyle(color: q.muted, fontSize: 11)),
                ],
              ),
            ),
            Text(
              value == null ? 'Tidak diatur' : Money.format(value!),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: value == null ? q.muted : q.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: Spacing.s),
            Icon(Icons.edit_rounded, size: 18, color: q.muted),
          ],
        ),
      ),
    );
  }
}

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
    final line = LimitLine(label: name, used: used, limit: limit);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      margin: const EdgeInsets.only(bottom: Spacing.s),
      decoration: BoxDecoration(
        color: line.level == BudgetLevel.over
            ? q.bad.withValues(alpha: 0.12)
            : q.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: q.shadow,
            offset: const Offset(0, 6),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: QuestPress(
                  onTap: onManage,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          scopeLabel == null ? name : '$name · $scopeLabel',
                          style: context.qTitle(14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.tune_rounded, size: 15, color: q.muted),
                    ],
                  ),
                ),
              ),
              Text(
                limit == null
                    ? 'Belum dialokasikan · terpakai ${Money.format(used)}'
                    : '${Money.format(used)} / ${Money.format(limit!)}'
                          ' (${line.usedPercent}%)',
                style: TextStyle(
                  fontSize: 12,
                  color: line.level == BudgetLevel.over ? q.bad : q.muted,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: Spacing.s),
              QuestPress(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: q.surface2,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.edit_rounded, size: 16, color: q.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.s),
          QuestBar(
            value: line.fraction,
            height: 10,
            color: switch (line.level) {
              BudgetLevel.over => q.bad,
              BudgetLevel.warning => q.honey,
              BudgetLevel.ok => q.good,
            },
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.label,
    required this.amount,
    required this.previous,
    required this.incoming,
  });

  final String label;
  final int amount;
  final int previous;
  final bool incoming;

  /// Masuk naik = membaik; keluar naik = memburuk. Toleransi ±5% = datar.
  TrendDirection _trend() {
    final (current, baseline) = incoming
        ? (amount, previous)
        : (previous, amount);
    if (current <= 0 && baseline <= 0) return TrendDirection.flat;
    if (baseline <= 0) {
      return incoming ? TrendDirection.better : TrendDirection.worse;
    }
    if (current >= baseline * 1.05) {
      return incoming ? TrendDirection.better : TrendDirection.worse;
    }
    if (current <= baseline * 0.95) {
      return incoming ? TrendDirection.worse : TrendDirection.better;
    }
    return TrendDirection.flat;
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final trend = _trend();
    final good = trend == TrendDirection.better;
    final color = trend == TrendDirection.flat
        ? q.muted
        : good
        ? q.good
        : q.bad;
    final icon = switch (trend) {
      TrendDirection.better => Icons.trending_up_rounded,
      TrendDirection.worse => Icons.trending_down_rounded,
      TrendDirection.flat => Icons.trending_flat_rounded,
    };
    return QuestCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.qEyebrow()),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(Money.format(amount), style: context.qDisplay(22)),
          ),
          const SizedBox(height: Spacing.s),
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'bulan lalu: ${Money.format(previous)}',
                  style: TextStyle(fontSize: 11, color: q.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
