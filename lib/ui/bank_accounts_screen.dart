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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountDetailScreen(
          repository: repository,
          pipeline: pipeline,
          ruleSet: ruleSet,
          accountId: account.id,
        ),
      ),
    );
  }

  Future<void> _reparse(BuildContext context, Set<String> connected) async {
    final created = await repository.reparseUnparsed(
      pipeline.engine,
      connectedBankIds: connected,
    );
    if (!context.mounted) return;
    questSnack(
      context,
      created > 0
          ? '$created draf baru menunggumu di Notifikasi.'
          : 'Belum ada notifikasi yang bisa dibaca ulang.',
      icon: created > 0
          ? Icons.mark_as_unread_rounded
          : Icons.info_outline_rounded,
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
                  return StreamBuilder<List<CaptureLog>>(
                    stream: repository.watchCaptureLog(),
                    builder: (context, logSnap) {
                      final unread = (logSnap.data ?? const <CaptureLog>[])
                          .where((l) => !l.parsed)
                          .length;
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
                              hint: 'Yuk mulai — tambahkan dompet tunai, '
                                  'atau hubungkan bank dan e-walletmu.',
                              actionLabel: 'Tambah akun',
                              onAction: () => _openAddSheet(context),
                            )
                          else
                            for (final a in accounts) ...[
                              _AccountTile(
                                account: a,
                                balance: balances[a.id] ?? a.openingBalance,
                                connected: a.bankId != null &&
                                    connected.contains(a.bankId),
                                onTap: () => _openDetail(context, a),
                              ),
                              const SizedBox(height: Spacing.s),
                            ],
                          const SizedBox(height: Spacing.l),
                          QuestButton(
                            label: 'Tambah akun',
                            icon: Icons.add_rounded,
                            onPressed: () => _openAddSheet(context),
                          ),
                          const SizedBox(height: Spacing.l),
                          const QuestSectionHeader(title: 'Kalau ada kendala'),
                          QuestCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                if (unread > 0)
                                  _CareRow(
                                    icon: Icons.mark_as_unread_rounded,
                                    color: SeedColors.honeyDeep,
                                    title: '$unread notifikasi belum terbaca',
                                    subtitle:
                                        'Isinya belum dikenali — coba baca '
                                        'ulang, ya',
                                    onTap: () => _reparse(context, connected),
                                  ),
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
                      );
                    },
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
                        AccountKind.bank => Icons.account_balance_rounded,
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
            const SizedBox(width: Spacing.s),
            Text(
              Money.format(balance),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: balance < 0 ? q.bad : q.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: Spacing.xs),
            Icon(Icons.chevron_right_rounded, color: q.muted),
          ],
        ),
      ),
    );
  }
}
