import 'package:flutter/material.dart';

import '../capture/pipeline.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'bank_accounts_screen.dart';
import 'quest.dart';

/// Teks persetujuan akses — syarat kebijakan User Data Google Play,
/// ditampilkan sebelum mengarahkan user ke pengaturan sistem.
const String connectDisclosureText =
    'Bukuduit membaca notifikasi transaksi dari bank dan e-wallet yang '
    'kamu hubungkan, lalu menawarkannya sebagai draf catatan. Tidak ada '
    'yang tersimpan sebelum kamu menekan Catat.\n\n'
    'Semua data tersimpan terenkripsi di HP ini dan tidak pernah dikirim '
    'ke server mana pun. Kamu bebas memutuskan hubungannya kapan saja.';

/// Layar Catat otomatis: tempat memantau & mengatur baca notifikasi —
/// status bekerja, saklar per bank, dan bantuan (baca ulang, baterai).
/// Menambah bank/e-wallet baru dilakukan dari layar Bank & Akun. Tanpa
/// istilah teknis: tanpa "parse", "capture", "template", "package".
class CaptureSettingsScreen extends StatefulWidget {
  const CaptureSettingsScreen({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;

  @override
  State<CaptureSettingsScreen> createState() => _CaptureSettingsScreenState();
}

class _CaptureSettingsScreenState extends State<CaptureSettingsScreen>
    with WidgetsBindingObserver {
  bool _listenerOn = false;
  bool _listenerKnown = false;

  /// Bank yang menunggu izin nyala — koneksi dilanjutkan otomatis saat
  /// user kembali dari Pengaturan sistem dengan izin sudah aktif.
  BankRules? _pendingConnect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kembali dari Pengaturan sistem → cek izin, lanjutkan koneksi bila
    // menunggu.
    if (state == AppLifecycleState.resumed) _refreshListener();
  }

  Future<void> _refreshListener() async {
    final on = await widget.pipeline.channel.isListenerEnabled();
    final pending = _pendingConnect;
    if (!mounted) return;
    if (on && pending != null) {
      setState(() {
        _listenerOn = true;
        _listenerKnown = true;
        _pendingConnect = null;
      });
      await _completeConnect(pending);
      return;
    }
    setState(() {
      _listenerOn = on;
      _listenerKnown = true;
      if (!on) _pendingConnect = null;
    });
  }

  /// Bank katalog yang bisa dihubungkan (fallback generik dikecualikan).
  List<BankRules> get _connectable =>
      widget.ruleSet.banks.where((b) => b.id != 'unknown').toList();

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

  /// Tombol Mulai/Nyalakan di kartu status: pastikan izin aktif dulu.
  Future<void> _enablePermission() async {
    final understood = await _confirmDisclosure('Izinkan baca notifikasi?');
    if (!understood || !mounted) return;
    await widget.pipeline.channel.openListenerSettings();
    // User kembali dari Pengaturan → status dicek saat resumed.
  }

  void _openBankAccounts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BankAccountsScreen(
          repository: widget.repository,
          pipeline: widget.pipeline,
          ruleSet: widget.ruleSet,
        ),
      ),
    );
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

  /// Saklar bank dinyalakan kembali: bila izin belum aktif, simpan
  /// sebagai pending agar koneksi menyusul begitu izin nyala — tap
  /// tidak hangus.
  Future<void> _connect(BankRules bank) async {
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

  Future<void> _disconnect(BankRules bank) async {
    await widget.repository.setBankConnected(bank.id, false);
    if (mounted) {
      questSnack(
        context,
        'Oke, ${bank.displayName} tidak dibaca lagi.',
        icon: Icons.link_off_rounded,
      );
    }
  }

  Future<void> _reparse(Set<String> connected) async {
    final created = await widget.repository.reparseUnparsed(
      widget.pipeline.engine,
      connectedBankIds: connected,
    );
    if (!mounted) return;
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
    final q = context.q;
    return Scaffold(
      backgroundColor: q.bg,
      appBar: const QuestHeader(
        title: 'Catat otomatis',
        subtitle: 'Biar notifikasi bank tercatat sendiri',
        showBack: true,
      ),
      body: StreamBuilder<Set<String>>(
        stream: widget.repository.watchConnectedBanks(),
        builder: (context, connSnap) {
          final connected = connSnap.data ?? const <String>{};
          return StreamBuilder<List<CaptureLog>>(
            stream: widget.repository.watchCaptureLog(),
            builder: (context, logSnap) {
              final unread = (logSnap.data ?? const <CaptureLog>[])
                  .where((l) => !l.parsed)
                  .length;
              final connectedBanks = _connectable
                  .where((b) => connected.contains(b.id))
                  .toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.m,
                  Spacing.s,
                  Spacing.m,
                  Spacing.m,
                ),
                children: [
                  if (!_listenerKnown)
                    const QuestSkeleton(rows: 1)
                  else
                    _StatusCard(
                      listenerOn: _listenerOn,
                      connectedCount: connectedBanks.length,
                      onEnable: _enablePermission,
                      onAddBank: _openBankAccounts,
                    ),
                  const SizedBox(height: Spacing.m),
                  const QuestSectionHeader(title: 'Bank terhubung'),
                  if (connectedBanks.isEmpty)
                    const QuestEmpty(
                      title: 'Belum ada bank terhubung',
                      hint: 'Tambahkan akun bank atau e-walletmu dari '
                          'layar Bank & Akun.',
                    )
                  else
                    for (final b in connectedBanks) ...[
                      _ConnectedBankTile(
                        bank: b,
                        onToggle: (on) =>
                            on ? _connect(b) : _disconnect(b),
                      ),
                      const SizedBox(height: Spacing.s),
                    ],
                  const SizedBox(height: Spacing.m),
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
                                'Isinya belum dikenali — coba baca ulang, ya',
                            onTap: () => _reparse(connected),
                          ),
                        _CareRow(
                          icon: Icons.battery_saver_rounded,
                          color: q.text,
                          title: 'Cek pengaturan baterai',
                          subtitle:
                              'Kalau HP-mu sering menutup aplikasi di '
                              'belakang',
                          onTap: widget.pipeline.channel.openBatterySettings,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Kartu status tunggal: selalu tampil, isi menyesuaikan kondisi —
/// jawaban atas "apakah catat otomatis sedang bekerja?".
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.listenerOn,
    required this.connectedCount,
    required this.onEnable,
    required this.onAddBank,
  });

  final bool listenerOn;
  final int connectedCount;
  final VoidCallback onEnable;
  final VoidCallback onAddBank;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final IconData icon;
    final Color color;
    final String title;
    final String body;
    final String? button;
    final VoidCallback? onButton;
    final IconData buttonIcon;
    if (!listenerOn && connectedCount > 0) {
      icon = Icons.notifications_off_rounded;
      color = q.bad;
      title = 'Notifikasi belum terbaca';
      body = 'Izin baca notifikasi sedang mati. Nyalakan lagi supaya '
          'drafnya bisa masuk.';
      button = 'Nyalakan';
      onButton = onEnable;
      buttonIcon = Icons.settings_rounded;
    } else if (!listenerOn) {
      icon = Icons.notifications_none_rounded;
      color = q.muted;
      title = 'Catat otomatis belum aktif';
      body = 'Izinkan Bukuduit membaca notifikasi, lalu hubungkan '
          'bankmu.';
      button = 'Mulai';
      onButton = onEnable;
      buttonIcon = Icons.settings_rounded;
    } else if (connectedCount == 0) {
      icon = Icons.notifications_active_rounded;
      color = q.good;
      title = 'Siap mendengarkan';
      body = 'Tinggal tambahkan bank atau e-walletmu.';
      button = 'Tambah akun';
      onButton = onAddBank;
      buttonIcon = Icons.add_rounded;
    } else {
      icon = Icons.graphic_eq_rounded;
      color = q.good;
      title = 'Mendengarkan $connectedCount bank';
      body = 'Setiap transaksi yang terbaca otomatis jadi draf di layar '
          'Notifikasi.';
      button = null;
      onButton = null;
      buttonIcon = Icons.add_rounded;
    }
    return QuestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: Spacing.s),
              Expanded(
                child: Text(
                  title,
                  style: context.qTitle(15).copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(body, style: context.qBody(13)),
          if (button != null) ...[
            const SizedBox(height: Spacing.s),
            QuestButton(
              label: button,
              icon: buttonIcon,
              tone: QuestTone.secondary,
              onPressed: onButton,
            ),
          ],
        ],
      ),
    );
  }
}

/// Baris bank aktif: avatar inisial + nama + saklar matikan langsung.
class _ConnectedBankTile extends StatelessWidget {
  const _ConnectedBankTile({
    required this.bank,
    required this.onToggle,
  });

  final BankRules bank;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final initial = bank.displayName.isEmpty
        ? '?'
        : bank.displayName.characters.first.toUpperCase();
    return Container(
      padding: Insets.tile,
      decoration: BoxDecoration(
        color: q.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        boxShadow: [
          BoxShadow(color: q.shadow, offset: const Offset(0, 6), blurRadius: 18),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: q.honey, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                color: q.honeyInk,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: Spacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bank.displayName, style: context.qTitle(15)),
                Text(
                  'Notifikasinya jadi draf otomatis',
                  style: TextStyle(color: q.good, fontSize: 12),
                ),
              ],
            ),
          ),
          QuestSwitch(
            value: true,
            label: 'Baca notifikasi ${bank.displayName}',
            onChanged: onToggle,
          ),
        ],
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
