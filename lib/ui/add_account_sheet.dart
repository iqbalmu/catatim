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
    this.initialListenerOn = false,
    this.initialConnected = const {},
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;
  final bool initialListenerOn;
  final Set<String> initialConnected;

  /// Buka sheet tambah akun.
  static Future<void> show(
    BuildContext context, {
    required LedgerRepository repository,
    required CapturePipeline pipeline,
    required RuleSet ruleSet,
  }) async {
    // Muat status izin & bank terhubung sebelum sheet dibuka agar tinggi
    // awal sudah final dan animasi slide-up dari bawah berjalan mulus.
    final results = await Future.wait([
      pipeline.channel.isListenerEnabled(),
      repository.connectedBankIds(),
    ]);
    final listenerOn = results[0] as bool;
    final connected = results[1] as Set<String>;
    if (!context.mounted) return;
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
          initialListenerOn: listenerOn,
          initialConnected: connected,
        ),
      ),
    );
  }

  @override
  State<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<AddAccountSheet> {
  AccountKind _kind = AccountKind.bank;

  late final bool _listenerOn = widget.initialListenerOn;
  late final Set<String> _connected = widget.initialConnected;

  /// Katalog bank/e-wallet yang cocok jenis terpilih dan belum ada.
  List<BankRules> get _availableBanks => widget.ruleSet.banks
      .where(
        (b) =>
            b.id != 'unknown' &&
            b.accountKind == _kind &&
            !_connected.contains(b.id),
      )
      .toList();

  Future<void> _pickBank(BankRules bank) async {
    final connected = await _ConnectBankSheet.show(
      context,
      repository: widget.repository,
      pipeline: widget.pipeline,
      bank: bank,
      listenerOn: _listenerOn,
    );
    if (!mounted) return;
    if (connected == true) {
      Navigator.pop(context);
    }
  }

  Future<void> _openManualSheet() async {
    final saved = await _ManualAccountSheet.show(
      context,
      repository: widget.repository,
      kind: _kind,
    );
    if (!mounted) return;
    if (saved == true) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Mau tambah apa?', style: context.qTitle()),
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
            onChanged: (kind) => setState(() => _kind = kind),
          ),
          const SizedBox(height: Spacing.m),
          if (_kind == AccountKind.cash)
            _ManualAccountForm(
              key: const ValueKey(AccountKind.cash),
              repository: widget.repository,
              kind: AccountKind.cash,
              cancelLabel: 'Batal',
              onCancel: () => Navigator.pop(context),
              onSaved: () => Navigator.pop(context),
            )
          else
            ..._buildBankList(),
        ],
      ),
    );
  }

  List<Widget> _buildBankList() {
    final banks = _availableBanks;
    final isBank = _kind == AccountKind.bank;

    if (banks.isEmpty) {
      return [
        Text(
          isBank
              ? 'Semua bank otomatis sudah terhubung. Tambah bank lain secara manual:'
              : 'Semua e-wallet otomatis sudah terhubung. Tambah e-wallet lain secara manual:',
          style: context.qSmall(12.5).copyWith(color: context.q.muted),
        ),
        const SizedBox(height: Spacing.s),
        _ManualAccountForm(
          key: ValueKey(_kind),
          repository: widget.repository,
          kind: _kind,
          cancelLabel: 'Batal',
          onCancel: () => Navigator.pop(context),
          onSaved: () => Navigator.pop(context),
        ),
      ];
    }

    return [
      Text(
        isBank
            ? 'Pilih bank untuk baca notifikasi otomatis:'
            : 'Pilih e-wallet untuk baca notifikasi otomatis:',
        style: context.qBody(13),
      ),
      const SizedBox(height: Spacing.s),
      for (final b in banks) ...[
        _BankRow(bank: b, onTap: () => _pickBank(b)),
        const SizedBox(height: Spacing.xs),
      ],
      const SizedBox(height: Spacing.s),
      QuestButton(
        label: isBank ? 'Bank lain? Catat manual' : 'E-wallet lain? Catat manual',
        icon: Icons.edit_outlined,
        tone: QuestTone.secondary,
        onPressed: _openManualSheet,
      ),
    ];
  }
}

/// Drawer terpisah untuk menambah akun bank/e-wallet manual agar muncul
/// mulus dari bawah seperti drawer lainnya.
class _ManualAccountSheet extends StatelessWidget {
  const _ManualAccountSheet({
    required this.repository,
    required this.kind,
  });

  final LedgerRepository repository;
  final AccountKind kind;

  static Future<bool?> show(
    BuildContext context, {
    required LedgerRepository repository,
    required AccountKind kind,
  }) {
    return showQuestSheet<bool>(
      context,
      (context) => Padding(
        padding: EdgeInsets.only(
          left: Spacing.m,
          right: Spacing.m,
          top: Spacing.s,
          bottom: MediaQuery.viewInsetsOf(context).bottom + Spacing.m,
        ),
        child: _ManualAccountSheet(repository: repository, kind: kind),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBank = kind == AccountKind.bank;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isBank ? 'Tambah Bank Manual' : 'Tambah E-wallet Manual',
            style: context.qTitle(),
          ),
          const SizedBox(height: 2),
          Text(
            'Untuk catatan manual tanpa membaca notifikasi.',
            style: context.qSmall(12.5).copyWith(color: context.q.muted),
          ),
          const SizedBox(height: Spacing.m),
          _ManualAccountForm(
            repository: repository,
            kind: kind,
            cancelLabel: 'Kembali',
            cancelIcon: Icons.arrow_back_rounded,
            onCancel: () => Navigator.pop(context, false),
            onSaved: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }
}

/// Form input akun manual (dipakai inline untuk Tunai dan di [_ManualAccountSheet]).
class _ManualAccountForm extends StatefulWidget {
  const _ManualAccountForm({
    super.key,
    required this.repository,
    required this.kind,
    required this.cancelLabel,
    this.cancelIcon,
    required this.onCancel,
    required this.onSaved,
  });

  final LedgerRepository repository;
  final AccountKind kind;
  final String cancelLabel;
  final IconData? cancelIcon;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  State<_ManualAccountForm> createState() => _ManualAccountFormState();
}

class _ManualAccountFormState extends State<_ManualAccountForm> {
  final _nameCtrl = TextEditingController();
  final _openingCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _openingCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      final hint = switch (widget.kind) {
        AccountKind.bank => 'Beri nama bank, ya. Misalnya BCA.',
        AccountKind.ewallet => 'Beri nama e-wallet, ya. Misalnya GoPay.',
        AccountKind.cash => 'Beri nama dulu, ya. Misalnya Dompet.',
      };
      setState(() => _error = hint);
      return;
    }
    try {
      final account = await widget.repository.addAccount(name, widget.kind);
      final opening = int.tryParse(
        _openingCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
      );
      if (opening != null && opening > 0) {
        await widget.repository.setOpeningBalance(account.id, opening);
      }
      if (!mounted) return;
      questSnack(context, '$name siap dipakai.', icon: Icons.check_rounded);
      widget.onSaved();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Nama "$name" sudah dipakai. Coba nama lain, ya.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final presets = switch (widget.kind) {
      AccountKind.bank => const [
        'CIMB Niaga',
        'BSI',
        'Permata',
        'Jago',
        'SeaBank',
      ],
      AccountKind.ewallet => const ['LinkAja', 'AstraPay', 'iSaku'],
      AccountKind.cash => const <String>[],
    };
    final nameLabel = switch (widget.kind) {
      AccountKind.bank => 'Nama Bank',
      AccountKind.ewallet => 'Nama E-Wallet',
      AccountKind.cash => 'Nama Akun',
    };
    final nameHint = switch (widget.kind) {
      AccountKind.bank => 'Misalnya: CIMB Niaga atau BSI',
      AccountKind.ewallet => 'Misalnya: LinkAja',
      AccountKind.cash => 'Misalnya: Dompet',
    };
    final openingHint = widget.kind == AccountKind.cash
        ? 'Misalnya: 250000'
        : 'Misalnya: 500000';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (presets.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in presets) ...[
                  QuestChip(
                    label: p,
                    selected: _nameCtrl.text == p,
                    onTap: () {
                      setState(() {
                        _nameCtrl.text = p;
                        _error = null;
                      });
                    },
                  ),
                  const SizedBox(width: Spacing.xs),
                ],
              ],
            ),
          ),
          const SizedBox(height: Spacing.s),
        ],
        QuestFieldLabel(nameLabel),
        const SizedBox(height: Spacing.xs),
        TextField(
          controller: _nameCtrl,
          autofocus: widget.kind == AccountKind.cash,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: nameHint,
            errorText: _error,
          ),
        ),
        const SizedBox(height: Spacing.m),
        const QuestFieldLabel('Saldo awal (opsional)'),
        const SizedBox(height: Spacing.xs),
        TextField(
          controller: _openingCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(hintText: openingHint),
        ),
        const SizedBox(height: Spacing.m),
        Row(
          children: [
            Expanded(
              child: QuestButton(
                label: widget.cancelLabel,
                icon: widget.cancelIcon,
                tone: QuestTone.secondary,
                onPressed: widget.onCancel,
              ),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: QuestButton(
                label: 'Simpan',
                icon: Icons.check_rounded,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _ConnectStep { explain, permission, success }

/// Drawer terpisah untuk menghubungkan satu bank/e-wallet otomatis.
///
/// Dibuka lewat [showQuestSheet] saat user men-tap item bank/e-wallet
/// sehingga muncul mulus dari bawah seperti drawer lainnya. Mengembalikan
/// `true` bila akun berhasil terhubung.
class _ConnectBankSheet extends StatefulWidget {
  const _ConnectBankSheet({
    required this.repository,
    required this.pipeline,
    required this.bank,
    required this.initialListenerOn,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final BankRules bank;
  final bool initialListenerOn;

  static Future<bool?> show(
    BuildContext context, {
    required LedgerRepository repository,
    required CapturePipeline pipeline,
    required BankRules bank,
    required bool listenerOn,
  }) {
    return showQuestSheet<bool>(
      context,
      (context) => Padding(
        padding: EdgeInsets.only(
          left: Spacing.m,
          right: Spacing.m,
          top: Spacing.s,
          bottom: MediaQuery.viewInsetsOf(context).bottom + Spacing.m,
        ),
        child: _ConnectBankSheet(
          repository: repository,
          pipeline: pipeline,
          bank: bank,
          initialListenerOn: listenerOn,
        ),
      ),
    );
  }

  @override
  State<_ConnectBankSheet> createState() => _ConnectBankSheetState();
}

class _ConnectBankSheetState extends State<_ConnectBankSheet>
    with WidgetsBindingObserver {
  late _ConnectStep _step = widget.initialListenerOn
      ? _ConnectStep.explain
      : _ConnectStep.permission;
  bool _returnedWithoutPermission = false;
  Account? _connectedAccount;
  final _openingCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _openingCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _step == _ConnectStep.permission) {
      _checkPermissionAndConnect();
    }
  }

  Future<void> _checkPermissionAndConnect() async {
    final on = await widget.pipeline.channel.isListenerEnabled();
    if (!mounted) return;
    if (on) {
      await _completeConnect();
    } else {
      setState(() => _returnedWithoutPermission = true);
    }
  }

  Future<void> _completeConnect() async {
    final bank = widget.bank;
    await widget.repository.setBankConnected(bank.id, true);
    final account = await widget.repository.ensureBankAccount(
      bankId: bank.id,
      name: bank.displayName,
      kind: bank.accountKind,
    );
    await widget.pipeline.syncAllowedPackages();
    if (!mounted) return;
    setState(() {
      _connectedAccount = account;
      _step = _ConnectStep.success;
    });
  }

  Future<void> _openPermissionSettings() async {
    setState(() => _returnedWithoutPermission = false);
    await widget.pipeline.channel.openListenerSettings();
  }

  Future<void> _finishSuccess() async {
    final opening = int.tryParse(
      _openingCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    final account = _connectedAccount;
    if (opening != null && opening > 0 && account != null) {
      await widget.repository.setOpeningBalance(account.id, opening);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (_step) {
      _ConnectStep.explain => _buildExplain(),
      _ConnectStep.permission => _buildPermission(),
      _ConnectStep.success => _buildSuccess(),
    };

    return PopScope(
      canPop: _connectedAccount == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _connectedAccount != null) {
          Navigator.pop(context, true);
        }
      },
      child: SingleChildScrollView(
        child: AnimatedSwitcher(
          duration: QuestMotion.fast,
          switchInCurve: QuestMotion.easeOut,
          switchOutCurve: QuestMotion.easeOut,
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildExplain() {
    final bank = widget.bank;
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
                style: context.qTitle(),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.m),
        _FactRow(
          icon: Icons.edit_note_rounded,
          text:
              'Notifikasi transaksi ${bank.displayName} otomatis jadi draf, baru tersimpan saat kamu menekan Catat.',
        ),
        const _FactRow(
          icon: Icons.lock_rounded,
          text:
              '100% offline & terenkripsi di HP ini, dan bisa diputus kapan saja.',
        ),
        const SizedBox(height: Spacing.m),
        Row(
          children: [
            Expanded(
              child: QuestButton(
                label: 'Kembali',
                icon: Icons.arrow_back_rounded,
                tone: QuestTone.secondary,
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: QuestButton(
                label: 'Hubungkan',
                icon: Icons.check_rounded,
                onPressed: _completeConnect,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPermission() {
    final q = context.q;
    final bank = widget.bank;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _BankAvatar(name: bank.displayName, size: 44),
            const SizedBox(width: Spacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hubungkan ${bank.displayName}',
                    style: context.qTitle(),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Notifikasi transaksi otomatis jadi draf — 100% offline di HP ini.',
                    style: context.qSmall(12.5).copyWith(color: q.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.m),
        if (_returnedWithoutPermission) ...[
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: q.warnTint,
              borderRadius: BorderRadius.circular(AppRadius.tile),
              border: Border.all(color: q.warn.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: q.warn, size: 19),
                const SizedBox(width: Spacing.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Izinnya belum aktif',
                        style: context.qTitle(13).copyWith(color: q.warn),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Yuk cari CatatIM di daftar Akses Notifikasi lalu nyalakan saklarnya, setelah itu kembali ke sini.',
                        style: context.qSmall().copyWith(color: q.text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),
        ],
        Text(
          'Cara mengaktifkan (3 langkah cepat):',
          style: context.qTitle(13.5),
        ),
        const SizedBox(height: Spacing.xs),
        const _StepRow(
          number: '1',
          text: 'Ketuk tombol "Buka Pengaturan" di bawah.',
        ),
        const _StepRow(
          number: '2',
          text:
              'Cari aplikasi CatatIM, lalu nyalakan saklar akses notifikasinya.',
        ),
        _StepRow(
          number: '3',
          text:
              'Kembali ke sini, ${bank.displayName} langsung tersambung otomatis.',
        ),
        const SizedBox(height: Spacing.m),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: QuestButton(
                label: 'Kembali',
                tone: QuestTone.secondary,
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              flex: 3,
              child: QuestButton(
                label: _returnedWithoutPermission
                    ? 'Buka Pengaturan Lagi'
                    : 'Buka Pengaturan',
                icon: Icons.settings_rounded,
                onPressed: _openPermissionSettings,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    final q = context.q;
    final bank = widget.bank;
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
            child: Icon(Icons.check_rounded, color: q.onPrimary, size: 36),
          ),
        ),
        const SizedBox(height: Spacing.m),
        Text(
          '${bank.displayName} nyambung!',
          style: context.qTitle(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          'Setiap notifikasi transaksinya otomatis muncul sebagai draf '
          'konfirmasi di Beranda, tinggal pilih Catat atau Abaikan.',
          style: context.qSmall(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.m),
        const QuestFieldLabel('Saldo awal (opsional)'),
        const SizedBox(height: Spacing.xs),
        TextField(
          controller: _openingCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
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

/// Baris pilihan bank: avatar inisial + nama + chevron.
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
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.s,
        ),
        decoration: BoxDecoration(
          color: q.surface2.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(color: q.line),
        ),
        child: Row(
          children: [
            _BankAvatar(name: bank.displayName, size: 34),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: Text(bank.displayName, style: context.qTitle(15)),
            ),
            Icon(Icons.chevron_right_rounded, color: q.muted, size: 20),
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
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: q.primaryLight, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: q.primaryText,
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
              color: q.primaryLight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: TextStyle(
                color: q.primaryText,
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
