import 'package:flutter/material.dart';

import '../models.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Baris filter akun horizontal + tombol tambah akun (tahan untuk kelola).
class AccountFilter extends StatelessWidget {
  const AccountFilter({
    super.key,
    required this.repository,
    required this.selectedId,
    required this.onChanged,
  });

  final LedgerRepository repository;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  Future<void> _addAccount(BuildContext context) async {
    final nameCtrl = TextEditingController();
    var kind = AccountKind.bank;
    final result = await showQuestDialog<String>(
      context,
      title: 'Akun baru',
      content: StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama akun',
                hintText: 'Contoh: GoPay',
              ),
            ),
            const SizedBox(height: Spacing.m),
            QuestSegmented<AccountKind>(
              selected: kind,
              onChanged: (k) => setDialogState(() => kind = k),
              options: const [
                (
                  value: AccountKind.bank,
                  label: 'Bank',
                  icon: Icons.account_balance_rounded,
                ),
                (
                  value: AccountKind.ewallet,
                  label: 'E-wallet',
                  icon: Icons.wallet_rounded,
                ),
                (
                  value: AccountKind.cash,
                  label: 'Tunai',
                  icon: Icons.payments_rounded,
                ),
              ],
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
        QuestButton(
          label: 'Tambah',
          icon: Icons.add_rounded,
          onPressed: () => Navigator.pop(context, nameCtrl.text),
        ),
      ],
    );
    if (result == null || result.trim().isEmpty) return;
    try {
      final acc = await repository.addAccount(result, kind);
      onChanged(acc.id);
    } catch (_) {
      if (context.mounted) {
        questSnack(
          context,
          'Akun "$result" sudah ada.',
          icon: Icons.info_outline_rounded,
        );
      }
    }
  }

  Future<void> _manageAccount(BuildContext context, Account account) async {
    final nameCtrl = TextEditingController(text: account.name);
    final action = await showQuestDialog<String>(
      context,
      title: 'Kelola akun',
      content: TextField(
        controller: nameCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Nama akun'),
      ),
      actions: [
        QuestButton(
          label: 'Hapus',
          icon: Icons.delete_outline_rounded,
          tone: QuestTone.danger,
          onPressed: () => Navigator.pop(context, 'delete'),
        ),
        QuestButton(
          label: 'Simpan',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.pop(context, nameCtrl.text),
        ),
      ],
    );
    if (action == null) return;
    try {
      if (action == 'delete') {
        await repository.deleteAccount(account.id);
        onChanged(null);
      } else if (action.trim().isNotEmpty && action.trim() != account.name) {
        await repository.updateAccount(account.id, action);
      }
    } catch (_) {
      if (context.mounted) {
        questSnack(
          context,
          'Nama akun sudah dipakai.',
          icon: Icons.info_outline_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Account>>(
      stream: repository.watchAccounts(),
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? const <Account>[];
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              QuestChip(
                label: 'Semua',
                selected: selectedId == null,
                onTap: () => onChanged(null),
              ),
              for (final a in accounts) ...[
                const SizedBox(width: Spacing.s),
                QuestChip(
                  label: a.name,
                  selected: selectedId == a.id,
                  onTap: () => onChanged(selectedId == a.id ? null : a.id),
                  onLongPress: () => _manageAccount(context, a),
                ),
              ],
              const SizedBox(width: Spacing.s),
              QuestIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Tambah akun',
                onPressed: () => _addAccount(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
