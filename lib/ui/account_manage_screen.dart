import 'package:flutter/material.dart';

import '../models.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Layar khusus kelola akun (bank/e-wallet/tunai): tambah, ubah nama,
/// hapus. Filter akun hanya memfilter — semua proses data ada di sini.
class AccountManageScreen extends StatelessWidget {
  const AccountManageScreen({super.key, required this.repository});

  final LedgerRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: const QuestHeader(
        title: 'Kelola Akun',
        subtitle: 'Bank, e-wallet, dan tunai',
        showBack: true,
      ),
      body: StreamBuilder<List<Account>>(
        stream: repository.watchAccounts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const QuestSkeleton(rows: 3);
          }
          final accounts = snapshot.data ?? const <Account>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.m,
              Spacing.s,
              Spacing.m,
              Spacing.m,
            ),
            children: [
              if (accounts.isEmpty)
                const QuestEmpty(
                  title: 'Belum ada akun',
                  hint: 'Tambahkan bank, e-wallet, atau dompet tunai.',
                )
              else
                for (final a in accounts) ...[
                  _AccountRow(
                    account: a,
                    onTap: () => _editAccount(context, a),
                  ),
                  const SizedBox(height: Spacing.s),
                ],
              const SizedBox(height: Spacing.l),
              QuestButton(
                label: 'Tambah akun',
                icon: Icons.add_rounded,
                onPressed: () => _addAccount(context),
              ),
            ],
          );
        },
      ),
    );
  }

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
      await repository.addAccount(result, kind);
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

  Future<void> _editAccount(BuildContext context, Account account) async {
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
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.onTap});

  final Account account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: q.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: q.line, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: q.surface2,
                shape: BoxShape.circle,
                border: Border.all(color: q.line, width: 2),
              ),
              child: Icon(_kindIcon(account.kind), color: q.text, size: 20),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.name, style: context.qTitle(15)),
                  Text(
                    _kindLabel(account.kind),
                    style: TextStyle(color: q.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: q.muted),
          ],
        ),
      ),
    );
  }

  IconData _kindIcon(AccountKind kind) => switch (kind) {
        AccountKind.bank => Icons.account_balance_rounded,
        AccountKind.ewallet => Icons.wallet_rounded,
        AccountKind.cash => Icons.payments_rounded,
      };

  String _kindLabel(AccountKind kind) => switch (kind) {
        AccountKind.bank => 'Bank',
        AccountKind.ewallet => 'E-wallet',
        AccountKind.cash => 'Tunai',
      };
}
