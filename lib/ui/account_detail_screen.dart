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

/// Halaman detail satu akun: saldo sekarang, pengaturan baca notifikasi
/// otomatis (khusus akun bank/e-wallet terhubung katalog), ubah nama &
/// saldo awal, dan hapus. Satu alur: semua tentang akun ini ada di sini.
class AccountDetailScreen extends StatefulWidget {
  const AccountDetailScreen({
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

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen>
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
    // Kembali dari Pengaturan sistem → cek izin, lanjutkan koneksi bila
    // menunggu.
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

  /// Tombol Nyalakan izin: pastikan izin aktif dulu.
  Future<void> _enablePermission() async {
    final understood = await _confirmDisclosure('Izinkan baca notifikasi?');
    if (!understood || !mounted) return;
    await widget.pipeline.channel.openListenerSettings();
    // Status dicek lagi saat user kembali (resumed).
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

  /// Saklar baca notifikasi akun ini: nyala = hubungkan (tunggu izin
  /// bila belum aktif), mati = putuskan.
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
        questSnack(context, 'Tersimpan.', icon: Icons.check_rounded);
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
          icon: Icons.delete_outline_rounded,
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
      questSnack(context, '${account.name} dihapus, ya.');
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
          // Stream sudah keluar tapi akunnya tidak ada — sudah dihapus.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
        if (account == null) {
          return const Scaffold(body: Center(child: QuestSkeleton(rows: 1)));
        }
        final bank = account.bankId != null
            ? widget.ruleSet.bank(account.bankId!)
            : null;
        return Scaffold(
          backgroundColor: context.q.bg,
          appBar: QuestHeader(
            title: account.name,
            subtitle: account.kind.label,
            showBack: true,
          ),
          body: StreamBuilder<Set<String>>(
            stream: widget.repository.watchConnectedBanks(),
            builder: (context, connSnap) {
              final connected = connSnap.data ?? const <String>{};
              final autoOn = bank != null && connected.contains(bank.id);
              return StreamBuilder<Map<int, int>>(
                stream: widget.repository.watchAccountBalances(),
                builder: (context, balSnap) {
                  final balance =
                      balSnap.data?[account.id] ?? account.openingBalance;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.m,
                      Spacing.s,
                      Spacing.m,
                      Spacing.m,
                    ),
                    children: [
                      _BalanceCard(balance: balance),
                      if (bank != null) ...[
                        const SizedBox(height: Spacing.l),
                        const QuestSectionHeader(title: 'Baca otomatis'),
                        _AutoReadCard(
                          bank: bank,
                          active: autoOn,
                          listenerOn: _listenerOn,
                          onToggle: (on) => _toggleAutoRead(bank, on),
                          onEnablePermission: _enablePermission,
                        ),
                      ],
                      const SizedBox(height: Spacing.l),
                      const QuestSectionHeader(title: 'Pengaturan akun'),
                      QuestCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_loaded) ...[
                              TextField(
                                controller: _nameCtrl,
                                textCapitalization:
                                    TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Nama tampilan',
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
                                  helperText:
                                      'Dari angka ini saldomu dihitung '
                                      'otomatis',
                                ),
                              ),
                              const SizedBox(height: Spacing.m),
                              QuestButton(
                                label: 'Simpan',
                                icon: Icons.check_rounded,
                                onPressed: () => _save(account),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.l),
                      QuestButton(
                        label: 'Hapus akun',
                        icon: Icons.delete_outline_rounded,
                        tone: QuestTone.danger,
                        onPressed: () => _delete(account),
                      ),
                    ],
                  );
                },
              );
            },
          ),
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
          const SizedBox(height: Spacing.xxs),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              Money.format(balance),
              style: context.qDisplay(28).copyWith(
                color: balance < 0 ? q.bad : q.text,
              ),
            ),
          ),
          const SizedBox(height: Spacing.xxs),
          Text(
            'termasuk saldo awal dan semua transaksinya',
            style: context.qSmall().copyWith(color: q.muted),
          ),
        ],
      ),
    );
  }
}

/// Kartu baca otomatis milik akun ini: status + saklar + (bila perlu)
/// tombol menyalakan izin notifikasi.
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
            'draf di lonceng Notifikasi.'
        : permissionBlocked
            ? 'Akun ini sudah terhubung, tapi izinnya mati — draf tidak '
                'bisa masuk.'
            : 'Setiap notifikasi ${bank.displayName} otomatis jadi draf di '
                'lonceng Notifikasi — tinggal pilih Catat atau Buang.';
    return QuestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 26),
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
