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
