import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
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
          return StreamBuilder<Map<int, int>>(
            stream: repository.watchAccountBalances(),
            builder: (context, balanceSnap) {
              final balances = balanceSnap.data ?? const <int, int>{};
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
                        balance: balances[a.id] ?? a.openingBalance,
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
          );
        },
      ),
    );
  }

  Future<void> _addAccount(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final openingCtrl = TextEditingController();
    var kind = AccountKind.bank;
    final result = await showQuestDialog<(String, AccountKind, int)>(
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
            const SizedBox(height: Spacing.m),
            TextField(
              controller: openingCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Saldo awal (opsional)',
                hintText: 'Contoh: 250000',
              ),
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
          onPressed: () {
            final opening = int.tryParse(
              openingCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
            );
            Navigator.pop(
              context,
              (nameCtrl.text, kind, opening ?? 0),
            );
          },
        ),
      ],
    );
    if (result == null || result.$1.trim().isEmpty) return;
    try {
      final acc =
          await repository.addAccount(result.$1, result.$2);
      if (result.$3 != 0) {
        await repository.setOpeningBalance(acc.id, result.$3);
      }
    } catch (_) {
      if (context.mounted) {
        questSnack(
          context,
          'Akun "${result.$1}" sudah ada.',
          icon: Icons.info_outline_rounded,
        );
      }
    }
  }

  Future<void> _editAccount(BuildContext context, Account account) async {
    final nameCtrl = TextEditingController(text: account.name);
    final openingCtrl = TextEditingController(
      text: '${account.openingBalance}',
    );
    final action = await showQuestDialog<(String, int)>(
      context,
      title: 'Kelola akun',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama akun'),
          ),
          const SizedBox(height: Spacing.m),
          TextField(
            controller: openingCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Saldo awal',
              helperText: 'Saldo berjalan = awal + masuk − keluar',
            ),
          ),
        ],
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
          onPressed: () {
            final opening = int.tryParse(
              openingCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
            );
            Navigator.pop(
              context,
              (nameCtrl.text, opening ?? account.openingBalance),
            );
          },
        ),
      ],
    );
    if (action == null) return;
    try {
      if (action.$1 == 'delete') {
        await repository.deleteAccount(account.id);
      } else {
        final (newName, opening) = action;
        if (newName.trim().isNotEmpty && newName.trim() != account.name) {
          await repository.updateAccount(account.id, newName);
        }
        if (opening != account.openingBalance) {
          await repository.setOpeningBalance(account.id, opening);
        }
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
  const _AccountRow({
    required this.account,
    required this.balance,
    required this.onTap,
  });

  final Account account;
  final int balance;
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
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: q.surface2,
                shape: BoxShape.circle,
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
            Text(
              Money.format(balance),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: balance < 0 ? q.bad : q.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
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
