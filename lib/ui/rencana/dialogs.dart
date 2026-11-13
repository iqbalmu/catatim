part of '../rencana_batas.dart';

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

/// Hasil dialog batas global: nominal + cakupan kategori.

class _LimitEditResult {
  const _LimitEditResult({required this.amount, required this.categories});

  /// Nominal batas (rupiah); null = hapus batas ini.
  final int? amount;

  /// Id kategori yang dihitung; null = semua kategori.
  final Set<int>? categories;
}

/// Dialog batas global: nominal + kategori yang dihitung.
///
/// "Semua" dan kategori spesifik saling bebas — memilih satu kategori
/// melepas "Semua", memilih "Semua" mengosongkan pilihan. Pilihan kosong
/// tidak pernah disimpan: mengosongkan semua berarti kembali ke hitungan
/// seluruh kategori.
Future<_LimitEditResult?> _askLimitWithCategories(
  BuildContext context, {
  required LimitScope scope,
  required int? current,
  required Set<int>? currentCategories,
  required List<Category> categories,
}) {
  final ctrl = TextEditingController(text: current == null ? '' : '$current');
  // null = semua kategori; set = kategori spesifik yang dihitung.
  Set<int>? selected =
      currentCategories == null ? null : {...currentCategories};

  void toggle(int id) {
    final next = selected == null ? <int>{} : {...selected!};
    if (!next.remove(id)) next.add(id);
    selected = next.isEmpty ? null : next;
  }

  return showQuestDialog<_LimitEditResult>(
    context,
    title: scope.settingTitle,
    content: StatefulBuilder(
      builder: (context, setDialogState) {
        final q = context.q;
        final names = {for (final c in categories) c.id: c.name};
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const QuestFieldLabel('Nominal (Rupiah)'),
            const SizedBox(height: Spacing.xs),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Kosongkan kalau mau menghapus batas ini',
              ),
            ),
            const SizedBox(height: Spacing.m),
            const QuestFieldLabel('Kategori yang dihitung'),
            const SizedBox(height: Spacing.xs),
            Wrap(
              spacing: Spacing.xs,
              runSpacing: Spacing.xs,
              children: [
                QuestChip(
                  label: 'Semua',
                  selected: selected == null,
                  onTap: () => setDialogState(() => selected = null),
                ),
                for (final c in categories)
                  QuestChip(
                    label: c.name,
                    selected: selected != null && selected!.contains(c.id),
                    onTap: () => setDialogState(() => toggle(c.id)),
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: SeedColors.categoryColor(c.colorIndex),
                        shape: BoxShape.circle,
                        border: Border.all(color: q.line, width: 1.5),
                      ),
                    ),
                  ),
                QuestChip(
                  label: 'Tanpa kategori',
                  selected:
                      selected != null && selected!.contains(kUncategorizedId),
                  onTap: () => setDialogState(() => toggle(kUncategorizedId)),
                ),
              ],
            ),
            const SizedBox(height: Spacing.s),
            Text(
              limitScopeNote(selected, names) ??
                  'Semua kategori dihitung ke batas ini.',
              style: context.qSmall(12).copyWith(color: q.muted),
            ),
          ],
        );
      },
    ),
    actions: [
      QuestButton(
        label: 'Batal',
        tone: QuestTone.secondary,
        onPressed: () => Navigator.pop(context),
      ),
      QuestButton(
        label: 'Simpan',
        icon: Icons.check_rounded,
        onPressed: () {
          final amount = ctrl.text.trim().isEmpty
              ? null
              : int.tryParse(ctrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
          Navigator.pop(
            context,
            _LimitEditResult(amount: amount, categories: selected),
          );
        },
      ),
    ],
  );
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
      builder: (context, setDialogState) {
        final q = context.q;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const QuestFieldLabel('Nama Kategori'),
            const SizedBox(height: Spacing.xs),
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: q.text,
              ),
              decoration: const InputDecoration(
                hintText: 'Contoh: Makanan',
              ),
            ),
            const SizedBox(height: Spacing.m),
            const QuestFieldLabel('Batas Bulanan'),
            const SizedBox(height: Spacing.xs),
            TextField(
              controller: limitCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: q.text,
              ),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: q.text,
                  fontSize: 13.5,
                ),
                hintText: 'Kosongkan jika tanpa batas',
              ),
            ),
            const SizedBox(height: Spacing.m),
            QuestSelectField<int?>(
              value: scope,
              labelText: 'Berlaku di Akun',
              sheetTitle: 'Pilih Akun',
              options: [
                const QuestSelectOption<int?>(
                  value: null,
                  label: 'Semua akun',
                  subtitle: 'Berlaku untuk seluruh rekening & dompet',
                  icon: Icons.all_inclusive_rounded,
                ),
                for (final a in accounts)
                  QuestSelectOption<int?>(
                    value: a.id,
                    label: a.name,
                    subtitle: switch (a.kind) {
                      AccountKind.bank => 'Rekening Bank',
                      AccountKind.ewallet => 'E-Wallet',
                      AccountKind.cash => 'Dompet Tunai',
                    },
                    icon: switch (a.kind) {
                      AccountKind.bank => Icons.account_balance_rounded,
                      AccountKind.ewallet => Icons.phone_android_rounded,
                      AccountKind.cash => Icons.payments_outlined,
                    },
                  ),
              ],
              onChanged: (v) => setDialogState(() => scope = v),
            ),
          ],
        );
      },
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
    final q = context.q;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const QuestFieldLabel('Nama Kategori'),
        const SizedBox(height: Spacing.xs),
        TextField(
          controller: nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: q.text,
          ),
          decoration: const InputDecoration(
            hintText: 'Contoh: Kopi, Langganan, Hobi...',
          ),
        ),
        const SizedBox(height: Spacing.m),
        const QuestFieldLabel('Alokasi Bulanan (Opsional)'),
        const SizedBox(height: Spacing.xs),
        TextField(
          controller: limitCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: q.text,
          ),
          decoration: InputDecoration(
            prefixText: 'Rp ',
            prefixStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: q.text,
              fontSize: 13.5,
            ),
            hintText: 'Kosongkan jika tanpa batas',
          ),
        ),
      ],
    );
  }
}
