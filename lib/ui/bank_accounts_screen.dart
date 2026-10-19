import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../core/money.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'add_account_sheet.dart';
import 'quest.dart';

/// Layar Bank & Akun: satu pintu untuk semua akunmu — tambah akun bank,
/// e-wallet, atau tunai lewat [AddAccountSheet], ubah nama & saldo awal,
/// dan hapus. Status serta saklar baca notifikasi ada di layar Catat
/// otomatis; tanda "Terhubung" di tile hanya pemberi tahu.
class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  Future<void> _openAddSheet() {
    return AddAccountSheet.show(
      context,
      repository: widget.repository,
      pipeline: widget.pipeline,
      ruleSet: widget.ruleSet,
    );
  }

  Future<void> _manageAccount(BuildContext context, Account account) async {
    final nameCtrl = TextEditingController(text: account.name);
    final openingCtrl = TextEditingController(
      text: '${account.openingBalance}',
    );
    final action = await showQuestDialog<String>(
      context,
      title: account.name,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama tampilan'),
          ),
          const SizedBox(height: Spacing.m),
          TextField(
            controller: openingCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Saldo awal',
              helperText: 'Dari angka ini saldomu dihitung otomatis',
            ),
          ),
        ],
      ),
      actions: [
        QuestButton(
          label: 'Hapus akun',
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
            Navigator.pop(context, 'save:${nameCtrl.text}::$opening');
          },
        ),
      ],
    );
    if (action == null || !context.mounted) return;
    try {
      if (action == 'delete') {
        // Menghapus akun bank sekaligus memutus baca notifikasinya.
        if (account.bankId != null) {
          await widget.repository.setBankConnected(account.bankId!, false);
        }
        await widget.repository.deleteAccount(account.id);
      } else if (action.startsWith('save:')) {
        final parts = action.substring(5).split('::');
        final newName = parts[0].trim();
        final opening = int.tryParse(parts.length > 1 ? parts[1] : '');
        if (newName.isNotEmpty && newName != account.name) {
          await widget.repository.updateAccount(account.id, newName);
        }
        if (opening != null && opening != account.openingBalance) {
          await widget.repository.setOpeningBalance(account.id, opening);
        }
      }
    } catch (_) {
      if (context.mounted) {
        questSnack(
          context,
          'Nama itu sudah dipakai akun lain.',
          icon: Icons.info_outline_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: const QuestHeader(
        title: 'Bank & Akun',
        subtitle: 'Tambah akun & atur saldo',
        showBack: true,
      ),
      body: StreamBuilder<Set<String>>(
        stream: widget.repository.watchConnectedBanks(),
        builder: (context, connSnap) {
          final connected = connSnap.data ?? const <String>{};
          return StreamBuilder<List<Account>>(
            stream: widget.repository.watchAccounts(),
            builder: (context, accSnap) {
              if (accSnap.connectionState == ConnectionState.waiting) {
                return const QuestSkeleton(rows: 3);
              }
              final accounts = accSnap.data ?? const <Account>[];
              return StreamBuilder<Map<int, int>>(
                stream: widget.repository.watchAccountBalances(),
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
                      const QuestSectionHeader(title: 'Akunmu'),
                      if (accounts.isEmpty)
                        QuestEmpty(
                          title: 'Belum ada akun',
                          hint: 'Yuk mulai — tambahkan dompet tunai, atau '
                              'hubungkan bank dan e-walletmu.',
                          actionLabel: 'Tambah akun',
                          onAction: _openAddSheet,
                        )
                      else
                        for (final a in accounts) ...[
                          _AccountTile(
                            account: a,
                            balance: balances[a.id] ?? a.openingBalance,
                            connected:
                                a.bankId != null &&
                                connected.contains(a.bankId),
                            onTap: () => _manageAccount(context, a),
                          ),
                          const SizedBox(height: Spacing.s),
                        ],
                      const SizedBox(height: Spacing.l),
                      QuestButton(
                        label: 'Tambah akun',
                        icon: Icons.add_rounded,
                        onPressed: _openAddSheet,
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.balance,
    required this.connected,
    required this.onTap,
  });

  final Account account;
  final int balance;
  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestPress(
      onTap: onTap,
      child: Container(
        padding: Insets.tile,
        decoration: BoxDecoration(
          color: q.surface,
          borderRadius: BorderRadius.circular(AppRadius.tile),
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
                color: connected ? q.good : q.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                connected
                    ? Icons.link_rounded
                    : switch (account.kind) {
                        AccountKind.bank =>
                          Icons.account_balance_rounded,
                        AccountKind.ewallet => Icons.wallet_rounded,
                        AccountKind.cash => Icons.payments_rounded,
                      },
                color: connected ? Colors.white : q.text,
                size: 20,
              ),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.name, style: context.qTitle(15)),
                  Text(
                    connected
                        ? 'Terhubung'
                        : (account.bankId != null
                              ? 'Belum terhubung'
                              : account.kind.label),
                    style: TextStyle(
                      color: connected ? q.good : q.muted,
                      fontSize: 12,
                      fontWeight:
                          connected ? FontWeight.w700 : FontWeight.w400,
                    ),
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
}
