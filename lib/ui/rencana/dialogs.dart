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
    content: Column(
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
      ],
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
