import 'package:flutter/material.dart';

import '../capture/pipeline.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'account_detail_screen.dart';
import 'add_account_sheet.dart';
import 'capture_settings/permission_onboarding_sheet.dart';
import 'quest.dart';

/// Layar Bank & Akun: daftar semua akunmu. Tap satu akun untuk membuka
/// halaman detailnya — saldo, baca notifikasi otomatis (khusus bank/
/// e-wallet), ubah nama & saldo awal, dan hapus. Akun baru ditambahkan
/// lewat tombol Tambah akun; bantuan (baca ulang, baterai) ada di bawah.
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

class _BankAccountsScreenState extends State<BankAccountsScreen>
    with WidgetsBindingObserver {
  LedgerRepository get repository => widget.repository;
  CapturePipeline get pipeline => widget.pipeline;
  RuleSet get ruleSet => widget.ruleSet;

  bool _listenerEnabled = false;
  late Stream<Set<String>> _connectedBanksStream;
  late Stream<List<Account>> _accountsStream;
  late Stream<Map<int, int>> _balancesStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkListener();
    _connectedBanksStream = widget.repository.watchConnectedBanks();
    _accountsStream = widget.repository.watchAccounts();
    _balancesStream = widget.repository.watchAccountBalances();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkListener();
    }
  }

  Future<void> _checkListener() async {
    final enabled = await widget.pipeline.channel.isListenerEnabled();
    if (!mounted) return;
    setState(() => _listenerEnabled = enabled);
  }

  Future<void> _requestPermission() async {
    final granted = await NotificationPermissionSheet.show(
      context,
      channel: pipeline.channel,
    );
    await _checkListener();
    if (granted && mounted) {
      questSnack(
        context,
        'Izin akses notifikasi aktif! Akun bankmu siap mencatat otomatis.',
        icon: Icons.check_circle_outline_rounded,
      );
    }
  }

  @override
  void didUpdateWidget(covariant BankAccountsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _connectedBanksStream = widget.repository.watchConnectedBanks();
      _accountsStream = widget.repository.watchAccounts();
      _balancesStream = widget.repository.watchAccountBalances();
    }
  }

  Future<void> _openAddSheet(BuildContext context) async {
    await AddAccountSheet.show(
      context,
      repository: repository,
      pipeline: pipeline,
      ruleSet: ruleSet,
    );
    await _checkListener();
  }

  Future<void> _openDetail(BuildContext context, Account account) async {
    await AccountDetailSheet.show(
      context,
      repository: repository,
      pipeline: pipeline,
      ruleSet: ruleSet,
      accountId: account.id,
    );
    await _checkListener();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: QuestHeader(
        textScale: MediaQuery.textScalerOf(context).scale(1.0),
        title: 'Bank & Akun',
        subtitle: 'Akunmu & catat otomatis',
        showBack: true,
      ),
      body: StreamBuilder<Set<String>>(
        stream: _connectedBanksStream,
        builder: (context, connSnap) {
          final connected = connSnap.data ?? const <String>{};
          return StreamBuilder<List<Account>>(
            stream: _accountsStream,
            builder: (context, accSnap) {
              if (accSnap.connectionState == ConnectionState.waiting &&
                  !accSnap.hasData) {
                return const QuestSkeleton();
              }
              final accounts = accSnap.data ?? const <Account>[];
              return StreamBuilder<Map<int, int>>(
                stream: _balancesStream,
                builder: (context, balanceSnap) {
                  final balances = balanceSnap.data ?? const <int, int>{};
                  final hasBlockedConnected =
                      !_listenerEnabled &&
                      accounts.any(
                        (a) => a.bankId != null && connected.contains(a.bankId),
                      );
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.m,
                      0,
                      Spacing.m,
                      Spacing.m,
                    ),
                    children: [
                      if (hasBlockedConnected) ...[
                        const SizedBox(height: Spacing.xs),
                        QuestEnter(
                          child: _PermissionWarningCard(
                            onEnable: _requestPermission,
                          ),
                        ),
                        const SizedBox(height: Spacing.s),
                      ],
                      const QuestEnter(
                        child: QuestSectionHeader(title: 'Akunmu'),
                      ),
                      if (accounts.isEmpty)
                        QuestEnter(
                          index: 1,
                          child: QuestEmpty(
                            title: 'Belum ada akun',
                            hint:
                                'Yuk mulai dengan menambahkan dompet tunai, '
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
                              balance:
                                  balances[accounts[i].id] ??
                                  accounts[i].openingBalance,
                              connected:
                                  accounts[i].bankId != null &&
                                  connected.contains(accounts[i].bankId),
                              listenerEnabled: _listenerEnabled,
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
                            const QuestSectionHeader(
                              title: 'Kalau ada kendala',
                            ),
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

class _PermissionWarningCard extends StatelessWidget {
  const _PermissionWarningCard({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Container(
      padding: const EdgeInsets.all(Spacing.m),
      decoration: BoxDecoration(
        color: q.warnTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: q.warn.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: q.warn.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.notifications_off_rounded,
                  color: q.warn,
                  size: 19,
                ),
              ),
              const SizedBox(width: Spacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Izin baca notifikasi belum aktif',
                      style: context.qTitle(14).copyWith(color: q.warn),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Akun bank sudah terhubung, tapi CatatIM belum bisa membaca notifikasi transaksi sampai izin diaktifkan.',
                      style: context.qSmall().copyWith(
                        color: q.text,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          QuestButton(
            label: 'Nyalakan Izin Notifikasi',
            icon: Icons.notifications_active_rounded,
            onPressed: onEnable,
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.balance,
    required this.connected,
    required this.listenerEnabled,
    required this.onTap,
  });

  final Account account;
  final int balance;
  final bool connected;
  final bool listenerEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final activeCapture = connected && listenerEnabled;
    final waitingPermission = connected && !listenerEnabled;
    return QuestPress(
      onTap: onTap,
      child: Container(
        padding: Insets.tile,
        decoration: BoxDecoration(
          color: q.surface,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(color: q.line),
          boxShadow: q.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: activeCapture
                    ? q.primary.withValues(alpha: 0.12)
                    : waitingPermission
                    ? q.warnTint
                    : q.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                switch (account.kind) {
                  AccountKind.bank => Icons.account_balance_rounded,
                  AccountKind.ewallet => Icons.wallet_rounded,
                  AccountKind.cash => Icons.payments_rounded,
                },
                color: activeCapture
                    ? q.primary
                    : waitingPermission
                    ? q.warn
                    : q.text,
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
                      if (connected || account.bankId != null)
                        Flexible(
                          child: Text(
                            activeCapture
                                ? ' · Terhubung'
                                : waitingPermission
                                ? ' · Menunggu izin notifikasi'
                                : ' · Belum terhubung',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context
                                .qSmall(11.5)
                                .copyWith(
                                  color: activeCapture
                                      ? q.good
                                      : waitingPermission
                                      ? q.warn
                                      : q.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.s),
            QuestMoney(
              amount: balance,
              alignment: Alignment.centerRight,
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
