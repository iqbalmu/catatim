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
import 'quest.dart';

/// Teks persetujuan akses — syarat kebijakan User Data Google Play,
/// ditampilkan sebelum mengarahkan user ke pengaturan sistem.
const String connectDisclosureText =
    'Bukuduit membaca notifikasi transaksi dari bank dan e-wallet yang '
    'kamu hubungkan, lalu menawarkannya sebagai draf catatan. Tidak ada '
    'yang tersimpan sebelum kamu menekan Catat.\n\n'
    'Semua data tersimpan terenkripsi di HP ini dan tidak pernah dikirim '
    'ke server mana pun. Kamu bebas memutuskan hubungannya kapan saja.';

/// Drawer detail satu akun: saldo sekarang, pengaturan baca notifikasi
/// otomatis (khusus akun bank/e-wallet terhubung katalog), ubah nama &
/// saldo awal, dan hapus akun.
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

  /// Buka drawer detail akun.
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
          top: Spacing.s,
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
      if (mounted) {
        questSnack(
          context,
          'Oke, notifikasi ${bank.displayName} tidak dibaca lagi.',
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
        'Transaksinya tetap aman — hanya lepas dari akun ini.'
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
            padding: EdgeInsets.all(Spacing.l),
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
                        // ── Header Drawer Akun ──
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: context.q.surface2,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                switch (account.kind) {
                                  AccountKind.bank => Icons.account_balance_rounded,
                                  AccountKind.ewallet => Icons.wallet_rounded,
                                  AccountKind.cash => Icons.payments_rounded,
                                },
                                size: 22,
                                color: context.q.primary,
                              ),
                            ),
                            const SizedBox(width: Spacing.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.name,
                                    style: context.qTitle(18),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: Spacing.xxs),
                                  Text(
                                    account.kind.label,
                                    style: context.qSmall(12).copyWith(
                                      color: context.q.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            QuestIconButton(
                              icon: Icons.close_rounded,
                              tooltip: 'Tutup',
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.m),
                        Divider(height: 1, thickness: 1, color: context.q.line),
                        const SizedBox(height: Spacing.m),

                        // ── Kartu Saldo ──
                        _BalanceCard(balance: balance),

                        // ── Baca Otomatis (jika terhubung bank) ──
                        if (bank != null) ...[
                          const SizedBox(height: Spacing.m),
                          Padding(
                            padding: const EdgeInsets.only(left: Spacing.xs, bottom: Spacing.xs),
                            child: Text('BACA OTOMATIS', style: context.qEyebrow()),
                          ),
                          _AutoReadCard(
                            bank: bank,
                            active: autoOn,
                            listenerOn: _listenerOn,
                            onToggle: (on) => _toggleAutoRead(bank, on),
                            onEnablePermission: _enablePermission,
                          ),
                        ],

                        // ── Pengaturan Akun (Edit Nama & Saldo Awal) ──
                        const SizedBox(height: Spacing.m),
                        Padding(
                          padding: const EdgeInsets.only(left: Spacing.xs, bottom: Spacing.xs),
                          child: Text('PENGATURAN AKUN', style: context.qEyebrow()),
                        ),
                        QuestCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_loaded) ...[
                                TextField(
                                  controller: _nameCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Nama tampilan',
                                    hintText: 'Contoh: Tabungan Utama',
                                  ),
                                ),
                                const SizedBox(height: Spacing.m),
                                TextField(
                                  controller: _openingCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Saldo awal',
                                    helperText: 'Dari angka ini saldomu dihitung otomatis',
                                    prefixText: 'Rp ',
                                  ),
                                ),
                                const SizedBox(height: Spacing.m),
                                QuestButton(
                                  label: 'Simpan perubahan',
                                  icon: Icons.check_rounded,
                                  onPressed: () => _save(account),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // ── Hapus Akun ──
                        const SizedBox(height: Spacing.m),
                        QuestButton(
                          label: 'Hapus akun ini',
                          icon: Icons.delete_outline_rounded,
                          tone: QuestTone.danger,
                          onPressed: () => _delete(account),
                        ),
                        const SizedBox(height: Spacing.s),
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

/// Kartu saldo sekarang: angka besar + penjelasan singkat.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('SALDO SEKARANG', style: context.qEyebrow()),
          const SizedBox(height: Spacing.xs),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              Money.format(balance),
              style: context.qDisplay(26).copyWith(
                color: balance < 0 ? q.bad : q.text,
              ),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Termasuk saldo awal dan semua transaksinya',
            style: context.qSmall().copyWith(color: q.muted),
          ),
        ],
      ),
    );
  }
}

/// Kartu baca otomatis milik akun ini: status + saklar + tombol izin.
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
    final IconData icon = !active
        ? Icons.notifications_none_rounded
        : permissionBlocked
            ? Icons.notifications_off_rounded
            : Icons.check_circle_rounded;
    final Color color = !active
        ? q.muted
        : permissionBlocked
            ? q.bad
            : q.good;
    final String title = !active
        ? 'Belum dihubungkan'
        : permissionBlocked
            ? 'Izin notifikasi mati'
            : 'Notifikasi dibaca';
    final String body = !active
        ? 'Nyalakan supaya notifikasi ${bank.displayName} otomatis jadi '
            'draf di Beranda.'
        : permissionBlocked
            ? 'Akun ini sudah terhubung, tapi izin sistem mati — draf tidak '
            'bisa masuk.'
            : 'Setiap notifikasi ${bank.displayName} otomatis masuk sebagai '
            'draf konfirmasi di Beranda.';
    return QuestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: Spacing.s),
              Expanded(
                child: Text(
                  title,
                  style: context.qTitle(15).copyWith(color: color),
                ),
              ),
              QuestSwitch(
                value: active,
                label: 'Baca notifikasi ${bank.displayName}',
                onChanged: onToggle,
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(body, style: context.qBody(13)),
          if (permissionBlocked) ...[
            const SizedBox(height: Spacing.s),
            QuestButton(
              label: 'Nyalakan izin',
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
