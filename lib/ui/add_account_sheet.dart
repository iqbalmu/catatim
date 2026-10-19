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

/// Sheet satu pintu untuk menambah akun: bank, e-wallet, atau tunai.
///
/// Alur bank/e-wallet bertahap dalam satu sheet: pilih → paham dulu apa
/// yang terjadi → panduan izin bernomor (bila izin belum aktif) → berita
/// sukses + isi saldo awal di tempat. Akun tunai cukup nama + saldo
/// awal. Satu-satunya keluar dari sheet adalah Pengaturan sistem untuk
/// izin notifikasi — itu memang hanya bisa diberikan di sana.
class AddAccountSheet extends StatefulWidget {
  const AddAccountSheet({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;

  /// Buka sheet tambah akun.
  static Future<void> show(
    BuildContext context, {
    required LedgerRepository repository,
    required CapturePipeline pipeline,
    required RuleSet ruleSet,
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
        child: AddAccountSheet(
          repository: repository,
          pipeline: pipeline,
          ruleSet: ruleSet,
        ),
      ),
    );
  }

  @override
  State<AddAccountSheet> createState() => _AddAccountSheetState();
}

/// Tahapan alur tambah akun.
enum _AddStep {
  /// Pilih jenis (Bank/E-wallet/Tunai), lalu pilih bank atau isi form
  /// tunai.
  pick,

  /// Penjelasan singkat sebelum menghubungkan (syarat kebijakan data).
  explain,

  /// Panduan izin bernomor — hanya bila izin belum aktif.
  permission,

  /// Berita sukses + saldo awal opsional.
  success,
}

class _AddAccountSheetState extends State<AddAccountSheet>
    with WidgetsBindingObserver {
  _AddStep _step = _AddStep.pick;
  AccountKind _kind = AccountKind.bank;
  BankRules? _bank;

  bool _listenerOn = false;
  bool _returnedWithoutPermission = false;
  Set<String> _connected = const {};

  /// Akun hasil koneksi — dipakai untuk mengisi saldo awal saat sukses.
  Account? _connectedAccount;

  final _cashNameCtrl = TextEditingController();
  final _cashOpeningCtrl = TextEditingController();
  final _openingCtrl = TextEditingController();
  String? _cashError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cashNameCtrl.dispose();
    _cashOpeningCtrl.dispose();
    _openingCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Balik dari Pengaturan sistem → cek izin, sambung bila sudah aktif.
    if (state == AppLifecycleState.resumed) _refreshState();
  }

  Future<void> _refreshState() async {
    final on = await widget.pipeline.channel.isListenerEnabled();
    final connected = await widget.repository.connectedBankIds();
    if (!mounted) return;
    setState(() {
      _listenerOn = on;
      _connected = connected;
    });
    if (_step == _AddStep.permission) {
      if (on) {
        await _completeConnect();
      } else if (mounted) {
        setState(() => _returnedWithoutPermission = true);
      }
    }
  }

  /// Katalog bank/e-wallet yang cocok jenis terpilih dan belum ada.
  List<BankRules> get _availableBanks => widget.ruleSet.banks
      .where(
        (b) =>
            b.id != 'unknown' &&
            b.accountKind == _kind &&
            !_connected.contains(b.id),
      )
      .toList();

  void _pickBank(BankRules bank) {
    setState(() {
      _bank = bank;
      _step = _AddStep.explain;
    });
  }

  /// Lanjut dari penjelasan: sambung langsung bila izin sudah aktif,
  /// kalau belum arahkan ke panduan izin.
  void _proceedAfterExplain() {
    if (_listenerOn) {
      _completeConnect();
    } else {
      setState(() {
        _returnedWithoutPermission = false;
        _step = _AddStep.permission;
      });
    }
  }

  Future<void> _completeConnect() async {
    final bank = _bank;
    if (bank == null) return;
    await widget.repository.setBankConnected(bank.id, true);
    final account = await widget.repository.ensureBankAccount(
      bankId: bank.id,
      name: bank.displayName,
      kind: bank.accountKind,
    );
    if (!mounted) return;
    setState(() {
      _connectedAccount = account;
      _step = _AddStep.success;
    });
  }

  Future<void> _openPermissionSettings() async {
    setState(() => _returnedWithoutPermission = false);
    await widget.pipeline.channel.openListenerSettings();
  }

  Future<void> _saveCash() async {
    final name = _cashNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _cashError = 'Beri nama dulu, ya — misalnya Dompet.');
      return;
    }
    try {
      final account = await widget.repository.addAccount(
        name,
        AccountKind.cash,
      );
      final opening = int.tryParse(
        _cashOpeningCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
      );
      if (opening != null && opening > 0) {
        await widget.repository.setOpeningBalance(account.id, opening);
      }
      if (!mounted) return;
      questSnack(context, '$name siap dipakai.', icon: Icons.payments_rounded);
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _cashError = 'Nama "$name" sudah dipakai. Coba nama lain, ya.',
        );
      }
    }
  }

  Future<void> _finishSuccess() async {
    final opening = int.tryParse(
      _openingCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    final account = _connectedAccount;
    if (opening != null && opening > 0 && account != null) {
      await widget.repository.setOpeningBalance(account.id, opening);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _AddStep.pick => _buildPick(),
      _AddStep.explain => _buildExplain(),
      _AddStep.permission => _buildPermission(),
      _AddStep.success => _buildSuccess(),
    };
  }

  Widget _buildPick() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Mau tambah apa?', style: context.qTitle(17)),
        const SizedBox(height: Spacing.m),
        QuestSegmented<AccountKind>(
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
          selected: _kind,
          onChanged: (kind) => setState(() {
            _kind = kind;
            _cashError = null;
          }),
        ),
        const SizedBox(height: Spacing.m),
        if (_kind == AccountKind.cash) ..._buildCashForm() else ..._buildBankList(),
      ],
    );
  }

  List<Widget> _buildBankList() {
    final banks = _availableBanks;
    return [
      Text(
        _kind == AccountKind.bank
            ? 'Pilih bank yang mau dicatat otomatis:'
            : 'Pilih e-wallet yang mau dicatat otomatis:',
        style: context.qBody(13),
      ),
      const SizedBox(height: Spacing.s),
      if (banks.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.m),
          child: Text(
            _kind == AccountKind.bank
                ? 'Semua bank yang didukung sudah kamu hubungkan. Mantap!'
                : 'Semua e-wallet yang didukung sudah kamu hubungkan. '
                  'Mantap!',
            style: context.qSmall(),
            textAlign: TextAlign.center,
          ),
        )
      else
        for (final b in banks) ...[
          _BankRow(bank: b, onTap: () => _pickBank(b)),
          const SizedBox(height: Spacing.s),
        ],
    ];
  }

  List<Widget> _buildCashForm() {
    return [
      TextField(
        controller: _cashNameCtrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Nama akun',
          hintText: 'Misalnya: Dompet',
          errorText: _cashError,
        ),
      ),
      const SizedBox(height: Spacing.m),
      TextField(
        controller: _cashOpeningCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'Saldo awal (opsional)',
          hintText: 'Misalnya: 250000',
        ),
      ),
      const SizedBox(height: Spacing.m),
      Row(
        children: [
          Expanded(
            child: QuestButton(
              label: 'Batal',
              tone: QuestTone.secondary,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: Spacing.s),
          Expanded(
            child: QuestButton(
              label: 'Simpan',
              icon: Icons.check_rounded,
              onPressed: _saveCash,
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildExplain() {
    final bank = _bank!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _BankAvatar(name: bank.displayName, size: 44),
            const SizedBox(width: Spacing.m),
            Expanded(
              child: Text(
                'Hubungkan ${bank.displayName}?',
                style: context.qTitle(17),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.m),
        Text('Yang akan terjadi:', style: context.qBody(13)),
        const SizedBox(height: Spacing.xs),
        _FactRow(
          icon: Icons.notifications_active_rounded,
          text: 'Notifikasi transaksi ${bank.displayName} dibaca Bukuduit',
        ),
        _FactRow(
          icon: Icons.edit_note_rounded,
          text: 'Langsung jadi draf — baru tersimpan saat kamu menekan '
              'Catat',
        ),
        _FactRow(
          icon: Icons.lock_rounded,
          text: 'Datanya hanya ada di HP ini: terenkripsi, tak dikirim ke '
              'mana pun',
        ),
        _FactRow(
          icon: Icons.link_off_rounded,
          text: 'Putuskan hubungannya kapan saja kamu mau',
        ),
        const SizedBox(height: Spacing.m),
        Row(
          children: [
            Expanded(
              child: QuestButton(
                label: 'Kembali',
                icon: Icons.arrow_back_rounded,
                tone: QuestTone.secondary,
                onPressed: () => setState(() => _step = _AddStep.pick),
              ),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: QuestButton(
                label: 'Lanjutkan',
                icon: Icons.check_rounded,
                onPressed: _proceedAfterExplain,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPermission() {
    final bank = _bank!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Satu langkah terakhir', style: context.qTitle(17)),
        const SizedBox(height: Spacing.xs),
        Text(
          'Bukuduit perlu izin membaca notifikasi. Caranya:',
          style: context.qBody(13),
        ),
        const SizedBox(height: Spacing.m),
        _StepRow(number: '1', text: 'Tekan "Buka Pengaturan" di bawah'),
        _StepRow(
          number: '2',
          text: 'Cari Bukuduit, lalu nyalakan akses notifikasinya',
        ),
        _StepRow(
          number: '3',
          text: 'Balik ke sini — ${bank.displayName} tersambung otomatis',
        ),
        if (_returnedWithoutPermission) ...[
          const SizedBox(height: Spacing.s),
          Text(
            'Izinnya belum aktif. Nyalakan dulu, ya, lalu balik lagi ke '
            'sini.',
            style: context.qBody(13).copyWith(color: context.q.bad),
          ),
        ],
        const SizedBox(height: Spacing.m),
        QuestButton(
          label: 'Buka Pengaturan',
          icon: Icons.settings_rounded,
          onPressed: _openPermissionSettings,
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    final q = context.q;
    final bank = _bank!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Spacing.s),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: q.good, shape: BoxShape.circle),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: Spacing.m),
        Text(
          '${bank.displayName} berhasil terhubung!',
          style: context.qTitle(17),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          'Setiap notifikasi transaksinya otomatis jadi draf di layar '
          'Notifikasi — tinggal pilih Catat atau Buang.',
          style: context.qSmall(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.m),
        TextField(
          controller: _openingCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Saldo awal (opsional)',
            helperText: 'Isi supaya saldomu langsung pas',
            hintText: 'Misalnya: 250000',
          ),
        ),
        const SizedBox(height: Spacing.m),
        QuestButton(
          label: 'Selesai',
          icon: Icons.check_rounded,
          onPressed: _finishSuccess,
        ),
      ],
    );
  }
}

/// Baris pilihan bank: avatar inisial + nama + ajakan menghubungkan.
class _BankRow extends StatelessWidget {
  const _BankRow({required this.bank, required this.onTap});

  final BankRules bank;
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
            _BankAvatar(name: bank.displayName),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bank.displayName, style: context.qTitle(15)),
                  Text(
                    'Tap untuk menghubungkan',
                    style: TextStyle(color: q.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline_rounded, color: q.muted),
          ],
        ),
      ),
    );
  }
}

/// Avatar lingkaran madu dengan inisial nama bank.
class _BankAvatar extends StatelessWidget {
  const _BankAvatar({required this.name, this.size = 38});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final initial = name.isEmpty
        ? '?'
        : name.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: q.honey, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: q.honeyInk,
          fontWeight: FontWeight.w800,
          fontSize: size >= 40 ? 17 : 15,
        ),
      ),
    );
  }
}

/// Satu fakta dalam penjelasan: ikon bulat kecil + teks.
class _FactRow extends StatelessWidget {
  const _FactRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: q.surface2,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: q.text),
          ),
          const SizedBox(width: Spacing.s),
          Expanded(child: Text(text, style: context.qBody(13))),
        ],
      ),
    );
  }
}

/// Satu langkah bernomor dalam panduan izin.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: q.honey,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: TextStyle(
                color: q.honeyInk,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: Spacing.s),
          Expanded(child: Text(text, style: context.qBody(13))),
        ],
      ),
    );
  }
}
