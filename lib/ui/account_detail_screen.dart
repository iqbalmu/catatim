import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Teks persetujuan akses — syarat kebijakan User Data Google Play,
/// ditampilkan sebelum mengarahkan user ke pengaturan sistem.
const String connectDisclosureText =
    'CatatIn membaca notifikasi transaksi dari bank dan e-wallet yang '
    'kamu hubungkan, lalu menawarkannya sebagai draf catatan. Tidak ada '
    'yang tersimpan sebelum kamu menekan Catat.\n\n'
    'Semua data tersimpan terenkripsi di HP ini dan tidak pernah dikirim '
    'ke server mana pun. Kamu bebas memutuskan hubungannya kapan saja.';

/// Drawer detail akun kompak: saldo ringkas, pengaturan baca notifikasi
/// otomatis (bila terhubung bank), ubah nama & saldo awal, dan hapus akun.
class AccountDetailSheet extends StatefulWidget {
  const AccountDetailSheet({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
    required this.accountId,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;
  final int accountId;

  /// Buka drawer detail akun secara kompak.
  static Future<void> show(
    BuildContext context, {
    required LedgerRepository repository,
    required CapturePipeline pipeline,
    required RuleSet ruleSet,
    required int accountId,
  }) {
    return showQuestSheet<void>(
      context,
      (context) => Padding(
        padding: EdgeInsets.only(
          left: Spacing.m,
          right: Spacing.m,
          top: Spacing.xxs,
          bottom: MediaQuery.viewInsetsOf(context).bottom + Spacing.m,
        ),
        child: AccountDetailSheet(
          repository: repository,
          pipeline: pipeline,
          ruleSet: ruleSet,
          accountId: accountId,
        ),
      ),
    );
  }

  @override
  State<AccountDetailSheet> createState() => _AccountDetailSheetState();
}

/// Alias kompatibilitas jika masih ada import lama.
typedef AccountDetailScreen = AccountDetailSheet;

class _AccountDetailSheetState extends State<AccountDetailSheet>
    with WidgetsBindingObserver {
  final _nameCtrl = TextEditingController();
  final _openingCtrl = TextEditingController();
  bool _loaded = false;
  bool _listenerOn = false;

  /// Bank yang menunggu izin nyala — koneksi dilanjutkan otomatis saat
  /// user kembali dari Pengaturan sistem dengan izin sudah aktif.
  BankRules? _pendingConnect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameCtrl.dispose();
    _openingCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshListener();
  }

  Future<void> _load() async {
    final accounts = await widget.repository.getAccounts();
    final account = accounts.where((a) => a.id == widget.accountId).firstOrNull;
    if (!mounted) return;
    if (account != null) {
      _nameCtrl.text = account.name;
      _openingCtrl.text = '${account.openingBalance}';
      setState(() => _loaded = true);
    }
    _refreshListener();
  }

  Future<void> _refreshListener() async {
    final on = await widget.pipeline.channel.isListenerEnabled();
    final pending = _pendingConnect;
    if (!mounted) return;
    if (on && pending != null) {
      setState(() {
        _listenerOn = true;
        _pendingConnect = null;
      });
      await _completeConnect(pending);
      return;
    }
    setState(() {
      _listenerOn = on;
      if (!on) _pendingConnect = null;
    });
  }

  Future<bool> _confirmDisclosure(String title) async {
    return await showQuestDialog<bool>(
          context,
          title: title,
          content: Text(connectDisclosureText, style: context.qBody(13)),
          actions: [
            QuestButton(
              label: 'Nanti dulu',
              tone: QuestTone.secondary,
              onPressed: () => Navigator.pop(context, false),
            ),
            QuestButton(
              label: 'Mengerti, lanjut',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ) ==
        true;
  }

  Future<void> _enablePermission() async {
    final understood = await _confirmDisclosure('Izinkan baca notifikasi?');
    if (!understood || !mounted) return;
    await widget.pipeline.channel.openListenerSettings();
  }

  Future<void> _completeConnect(BankRules bank) async {
    await widget.repository.setBankConnected(bank.id, true);
    await widget.repository.ensureBankAccount(
      bankId: bank.id,
      name: bank.displayName,
      kind: bank.accountKind,
    );
    await widget.pipeline.syncAllowedPackages();
    if (mounted) {
      questSnack(
        context,
        '${bank.displayName} berhasil terhubung.',
        icon: Icons.link_rounded,
      );
    }
  }

  Future<void> _toggleAutoRead(BankRules bank, bool on) async {
    if (!on) {
      await widget.repository.setBankConnected(bank.id, false);
      await widget.pipeline.syncAllowedPackages();
      if (mounted) {
        questSnack(
          context,
          'Notifikasi ${bank.displayName} dinonaktifkan.',
          icon: Icons.link_off_rounded,
        );
      }
      return;
    }
    if (_listenerOn) {
      await _completeConnect(bank);
      return;
    }
    final understood =
        await _confirmDisclosure('Hubungkan ${bank.displayName}?');
    if (!understood || !mounted) return;
    setState(() => _pendingConnect = bank);
    await widget.pipeline.channel.openListenerSettings();
  }

  Future<void> _save(Account account) async {
    final newName = _nameCtrl.text.trim();
    final opening = int.tryParse(
      _openingCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (newName.isEmpty) return;
    try {
      if (newName != account.name) {
        await widget.repository.updateAccount(account.id, newName);
      }
      if (opening != null && opening != account.openingBalance) {
        await widget.repository.setOpeningBalance(account.id, opening);
      }
      if (mounted) {
        questSnack(context, 'Perubahan berhasil disimpan.', icon: Icons.check_rounded);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        questSnack(
          context,
          'Nama itu sudah dipakai akun lain.',
          icon: Icons.info_outline_rounded,
        );
      }
    }
  }

  Future<void> _delete(Account account) async {
    final sure = await showQuestDialog<bool>(
      context,
      title: 'Hapus akun ini?',
      content: Text(
        'Transaksinya tetap aman, hanya lepas dari akun ini.'
        '${account.bankId != null ? ' Baca notifikasinya juga diputus.' : ''}',
        style: context.qBody(13),
      ),
      actions: [
        QuestButton(
          label: 'Batal',
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context, false),
        ),
        QuestButton(
          label: 'Hapus',
          tone: QuestTone.danger,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (sure != true || !mounted) return;
    if (account.bankId != null) {
      await widget.repository.setBankConnected(account.bankId!, false);
    }
    await widget.repository.deleteAccount(account.id);
    if (mounted) {
      questSnack(context, '${account.name} berhasil dihapus.');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return StreamBuilder<List<Account>>(
      stream: widget.repository.watchAccounts(),
      builder: (context, accSnap) {
        final accounts = accSnap.data;
        final account = accounts
            ?.where((a) => a.id == widget.accountId)
            .firstOrNull;
        if (accounts != null && account == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
        if (account == null) {
          return const Padding(
            padding: EdgeInsets.all(Spacing.m),
            child: Center(child: QuestSkeleton(rows: 2)),
          );
        }
        final bank = account.bankId != null
            ? widget.ruleSet.bank(account.bankId!)
            : null;

        return StreamBuilder<Set<String>>(
          stream: widget.repository.watchConnectedBanks(),
          builder: (context, connSnap) {
            final connected = connSnap.data ?? const <String>{};
            final autoOn = bank != null && connected.contains(bank.id);

            return StreamBuilder<Map<int, int>>(
              stream: widget.repository.watchAccountBalances(),
              builder: (context, balSnap) {
                final balance =
                    balSnap.data?[account.id] ?? account.openingBalance;

                return SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Header Kompak: Icon, Nama, Status, & Aksi ──
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: q.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                switch (account.kind) {
                                  AccountKind.bank => Icons.account_balance_rounded,
                                  AccountKind.ewallet => Icons.wallet_rounded,
                                  AccountKind.cash => Icons.payments_rounded,
                                },
                                size: 20,
                                color: q.primary,
                              ),
                            ),
                            const SizedBox(width: Spacing.s),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.name,
                                    style: context.qTitle(17),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    autoOn
                                        ? '${account.kind.label} · Auto-sync aktif'
                                        : (account.bankId != null
                                            ? '${account.kind.label} · Belum terhubung'
                                            : '${account.kind.label} · Manual'),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: autoOn ? FontWeight.w700 : FontWeight.w500,
                                      color: autoOn ? q.good : q.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            QuestIconButton(
                              icon: Icons.delete_outline_rounded,
                              tooltip: 'Hapus akun',
                              onPressed: () => _delete(account),
                            ),
                            QuestIconButton(
                              icon: Icons.close_rounded,
                              tooltip: 'Tutup',
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.s),
                        Divider(height: 1, thickness: 1, color: q.line),
                        const SizedBox(height: Spacing.s),

                        // ── Strip Saldo Ringkas & Padat ──
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: q.surface2.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: q.line),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Saldo Sekarang',
                                    style: context.qSmall(12).copyWith(
                                      color: q.muted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  QuestMoney(
                                    amount: balance,
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: balance < 0 ? q.bad : q.text,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: q.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                  border: Border.all(color: q.line),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Awal: ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: q.muted,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    QuestMoney(
                                      amount: account.openingBalance,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: q.muted,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Notifikasi Otomatis (Hanya bila akun Bank/E-wallet) ──
                        if (bank != null) ...[
                          const SizedBox(height: Spacing.s),
                          _AutoReadCard(
                            bank: bank,
                            active: autoOn,
                            listenerOn: _listenerOn,
                            onToggle: (on) => _toggleAutoRead(bank, on),
                            onEnablePermission: _enablePermission,
                          ),
                        ],

                        // ── Form Input Langsung & Padat ──
                        if (_loaded) ...[
                          const SizedBox(height: Spacing.m),
                          const QuestFieldLabel('Nama Tampilan'),
                          const SizedBox(height: Spacing.xs),
                          TextField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'Contoh: Tabungan Utama',
                              prefixIcon: Icon(Icons.edit_outlined, size: 18),
                            ),
                          ),
                          const SizedBox(height: Spacing.m),
                          const QuestFieldLabel('Saldo Awal'),
                          const SizedBox(height: Spacing.xs),
                          TextField(
                            controller: _openingCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              prefixText: 'Rp ',
                              prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                            ),
                          ),
                          const SizedBox(height: Spacing.m),
                          QuestButton(
                            label: 'Simpan Perubahan',
                            icon: Icons.check_rounded,
                            onPressed: () => _save(account),
                          ),
                        ],
                        const SizedBox(height: Spacing.xs),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Kartu baca otomatis ringkas untuk akun bank/e-wallet.
class _AutoReadCard extends StatelessWidget {
  const _AutoReadCard({
    required this.bank,
    required this.active,
    required this.listenerOn,
    required this.onToggle,
    required this.onEnablePermission,
  });

  final BankRules bank;
  final bool active;
  final bool listenerOn;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEnablePermission;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final bool permissionBlocked = active && !listenerOn;
    final Color color = !active
        ? q.muted
        : permissionBlocked
            ? q.bad
            : q.good;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: q.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: q.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                !active
                    ? Icons.notifications_none_rounded
                    : permissionBlocked
                        ? Icons.notifications_off_rounded
                        : Icons.notifications_active_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: Spacing.s),
              Expanded(
                child: Text(
                  'Capture notifikasi ${bank.displayName}',
                  style: context.qTitle(13.5),
                ),
              ),
              QuestSwitch(
                value: active,
                label: 'Baca notifikasi ${bank.displayName}',
                onChanged: onToggle,
              ),
            ],
          ),
          if (permissionBlocked) ...[
            const SizedBox(height: Spacing.s),
            QuestButton(
              label: 'Nyalakan Izin Sistem',
              icon: Icons.settings_rounded,
              tone: QuestTone.secondary,
              onPressed: onEnablePermission,
            ),
          ],
        ],
      ),
    );
  }
}
