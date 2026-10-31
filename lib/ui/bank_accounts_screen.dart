import 'package:flutter/material.dart';

import '../capture/pipeline.dart';
import '../core/money.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'account_detail_screen.dart';
import 'add_account_sheet.dart';
import 'quest.dart';

/// Layar Bank & Akun: daftar semua akunmu. Tap satu akun untuk membuka
/// halaman detailnya — saldo, baca notifikasi otomatis (khusus bank/
/// e-wallet), ubah nama & saldo awal, dan hapus. Akun baru ditambahkan
/// lewat tombol Tambah akun; bantuan (baca ulang, baterai) ada di bawah.
class BankAccountsScreen extends StatelessWidget {
  const BankAccountsScreen({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;

  void _openAddSheet(BuildContext context) {
    AddAccountSheet.show(
      context,
      repository: repository,
      pipeline: pipeline,
      ruleSet: ruleSet,
    );
  }

  void _openDetail(BuildContext context, Account account) {
    AccountDetailSheet.show(
      context,
      repository: repository,
      pipeline: pipeline,
      ruleSet: ruleSet,
      accountId: account.id,
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: const QuestHeader(
        title: 'Bank & Akun',
        subtitle: 'Akunmu & catat otomatis',
        showBack: true,
      ),
      body: StreamBuilder<Set<String>>(
        stream: repository.watchConnectedBanks(),
        builder: (context, connSnap) {
          final connected = connSnap.data ?? const <String>{};
          return StreamBuilder<List<Account>>(
            stream: repository.watchAccounts(),
            builder: (context, accSnap) {
              if (accSnap.connectionState == ConnectionState.waiting) {
                return const QuestSkeleton(rows: 3);
              }
              final accounts = accSnap.data ?? const <Account>[];
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
                      const QuestEnter(
                        index: 0,
                        child: QuestSectionHeader(title: 'Akunmu'),
                      ),
                      if (accounts.isEmpty)
                        QuestEnter(
                          index: 1,
                          child: QuestEmpty(
                            title: 'Belum ada akun',
                            hint: 'Yuk mulai — tambahkan dompet tunai, '
                                'atau hubungkan bank dan e-walletmu.',
                            actionLabel: 'Tambah akun',
                            onAction: () => _openAddSheet(context),
                          ),
                        )
                      else
                        for (var i = 0; i < accounts.length; i++) ...[
                          QuestEnter(
                            index: 1 + i,
                            child: _AccountTile(
                              account: accounts[i],
                              balance: balances[accounts[i].id] ??
                                  accounts[i].openingBalance,
                              connected: accounts[i].bankId != null &&
                                  connected.contains(accounts[i].bankId),
                              onTap: () => _openDetail(context, accounts[i]),
                            ),
                          ),
                          const SizedBox(height: Spacing.s),
                        ],
                      if (accounts.isNotEmpty) ...[
                        const SizedBox(height: Spacing.l),
                        QuestEnter(
                          index: 1 + accounts.length,
                          child: QuestButton(
                            label: 'Tambah akun',
                            icon: Icons.add_rounded,
                            onPressed: () => _openAddSheet(context),
                          ),
                        ),
                      ],
                      const SizedBox(height: Spacing.l),
                      QuestEnter(
                        index: 2 + accounts.length,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                      const QuestSectionHeader(title: 'Kalau ada kendala'),
                      QuestCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _CareRow(
                              icon: Icons.battery_saver_rounded,
                              color: context.q.text,
                              title: 'Cek pengaturan baterai',
                              subtitle:
                                  'Kalau HP-mu sering menutup aplikasi '
                                  'di belakang',
                              onTap: pipeline.channel.openBatterySettings,
                            ),
                          ],
                        ),
                      ),
                          ],
                        ),
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

/// Baris bantuan: ikon bulat + judul + subjudul.
class _CareRow extends StatelessWidget {
  const _CareRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestPress(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.m),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: q.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.qTitle(14)),
                  Text(
                    subtitle,
                    style: context.qSmall().copyWith(color: q.muted),
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
          border: Border.all(color: q.line, width: 1),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: connected
                    ? q.primary.withValues(alpha: 0.12)
                    : q.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                switch (account.kind) {
                  AccountKind.bank => Icons.account_balance_rounded,
                  AccountKind.ewallet => Icons.wallet_rounded,
                  AccountKind.cash => Icons.payments_rounded,
                },
                color: connected ? q.primary : q.text,
                size: 20,
              ),
            ),
            const SizedBox(width: Spacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: context.qTitle(15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Spacing.xxs),
                  Row(
                    children: [
                      Text(
                        account.kind.label,
                        style: context.qSmall(11.5).copyWith(color: q.muted),
                      ),
                      if (connected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: q.good.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            'Terhubung',
                            style: TextStyle(
                              color: q.good,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ] else if (account.bankId != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: q.surface2,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            'Belum terhubung',
                            style: TextStyle(
                              color: q.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.s),
            Text(
              Money.format(balance),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: balance < 0 ? q.bad : q.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: Spacing.xs),
            Icon(Icons.chevron_right_rounded, color: q.muted, size: 20),
          ],
        ),
      ),
    );
  }
}
