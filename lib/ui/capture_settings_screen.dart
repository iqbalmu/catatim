import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'capture_settings/capture_settings_sheets.dart';
import 'capture_settings/permission_onboarding_sheet.dart';
import 'quest.dart';

/// Halaman Pengaturan Capture Notifikasi Bank & E-Wallet Offline.
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
  bool _listenerEnabled = false;
  DateTime? _lastHeartbeat;
  int _currentTab = 0; // 0 = Bank & App, 1 = Sistem & Aturan
  late final PageController _pageCtrl = PageController(
    initialPage: _currentTab,
  );
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  late Stream<Set<String>> _connectedBanksStream;
  late Stream<bool> _autoRecordStream;
  late Stream<List<({String package, String label})>> _customBanksStream;
  late Stream<CaptureLog?> _latestCaptureLogStream;
  late Stream<List<IgnoredPattern>> _ignoredPatternsStream;
  late Stream<List<CustomTemplate>> _customTemplatesStream;
  late Stream<List<CaptureLog>> _ignoredDuplicatesStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkListenerStatus();
    _initStreams();
  }

  void _initStreams() {
    final repo = widget.repository;
    _connectedBanksStream = repo.watchConnectedBanks();
    _autoRecordStream = repo.watchAutoRecordEnabled();
    _customBanksStream = repo.watchCustomBanks();
    _latestCaptureLogStream = repo.watchLatestCaptureLog();
    _ignoredPatternsStream = repo.watchIgnoredPatterns();
    _customTemplatesStream = repo.watchCustomTemplates();
    _ignoredDuplicatesStream = repo.watchIgnoredDuplicates();
  }

  @override
  void didUpdateWidget(covariant CaptureSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) _initStreams();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkListenerStatus();
    }
  }

  Future<void> _checkListenerStatus() async {
    final enabled = await widget.pipeline.channel.isListenerEnabled();
    final heartbeat = await widget.pipeline.channel.getLastCaptureHeartbeat();
    if (!mounted) return;
    setState(() {
      _listenerEnabled = enabled;
      _lastHeartbeat = heartbeat;
    });
  }

  Future<bool> _requireListenerPermission({String? bankName}) async {
    final granted = await NotificationPermissionSheet.show(
      context,
      channel: widget.pipeline.channel,
      bankName: bankName,
    );
    await _checkListenerStatus();
    if (granted && mounted && bankName == null) {
      questSnack(
        context,
        'Izin akses notifikasi aktif! Capture siap berjalan.',
        icon: Icons.check_circle_outline_rounded,
      );
    }
    return granted;
  }

  Future<void> _toggleBank(BankRules bank, bool connected) async {
    if (connected && !_listenerEnabled) {
      final granted = await _requireListenerPermission(
        bankName: bank.displayName,
      );
      if (!granted || !mounted) return;
    }
    await widget.repository.setBankConnected(bank.id, connected);
    if (connected) {
      await widget.repository.ensureBankAccount(
        bankId: bank.id,
        name: bank.displayName,
        kind: _accountKindForBank(bank),
      );
      if (mounted) {
        questSnack(
          context,
          'Capture ${bank.displayName} diaktifkan.',
          icon: Icons.check_rounded,
        );
      }
    } else if (mounted) {
      questSnack(
        context,
        'Capture ${bank.displayName} dinonaktifkan.',
        icon: Icons.link_off_rounded,
      );
    }
    // Allowlist antrean native harus mengikuti koneksi terbaru.
    await widget.pipeline.syncAllowedPackages();
  }

  Future<void> _toggleCustom(
    ({String package, String label}) app,
    bool connected,
  ) async {
    if (connected && !_listenerEnabled) {
      final granted = await _requireListenerPermission(bankName: app.label);
      if (!granted || !mounted) return;
    }
    await widget.repository.setCustomBankConnected(
      app.package,
      app.label,
      connected,
    );
    if (mounted) {
      questSnack(
        context,
        connected
            ? 'Notifikasi ${app.label} kini menunggu keputusanmu.'
            : 'Capture ${app.label} diputus.',
        icon: connected ? Icons.check_rounded : Icons.link_off_rounded,
      );
    }
    await widget.pipeline.syncAllowedPackages();
  }

  Future<void> _pickApp() async {
    if (!_listenerEnabled) {
      final granted = await _requireListenerPermission();
      if (!granted || !mounted) return;
    }
    final apps = await widget.pipeline.channel.listLaunchableApps();
    if (!mounted) return;
    if (apps.isEmpty) {
      questSnack(
        context,
        'Daftar app tidak bisa dibaca di perangkat ini.',
        icon: Icons.info_outline_rounded,
      );
      return;
    }
    final existing = await widget.repository.customBanks();
    if (!mounted) return;
    final picked = await showModalBottomSheet<({String package, String label})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppPickerSheet(apps: apps, connected: existing),
    );
    if (!mounted || picked == null) return;
    await _toggleCustom(picked, true);
  }

  AccountKind _accountKindForBank(BankRules bank) {
    final nameLower = bank.displayName.toLowerCase();
    if (nameLower.contains('gopay') ||
        nameLower.contains('ovo') ||
        nameLower.contains('dana') ||
        nameLower.contains('shopeepay')) {
      return AccountKind.ewallet;
    }
    return AccountKind.bank;
  }

  Future<void> _reparseLogs(Set<String> connectedBanks) async {
    try {
      final created = await widget.repository.reparseUnparsed(
        widget.pipeline.engine,
        connectedBankIds: connectedBanks,
      );
      if (!mounted) return;
      questSnack(
        context,
        created > 0
            ? 'Beres! $created draf dibuat dari notifikasi lampau.'
            : 'Belum ada notifikasi baru yang bisa diproses.',
        icon: created > 0
            ? Icons.history_toggle_off_rounded
            : Icons.info_outline_rounded,
      );
    } catch (_) {
      if (mounted) {
        questSnack(
          context,
          'Yah, gagal memproses ulang notifikasinya.',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  Future<void> _pullActiveNotifications() async {
    final count = await widget.pipeline.pullActiveNotifications();
    if (!mounted) return;
    questSnack(
      context,
      count > 0
          ? 'Beres! $count notifikasi aktif jadi draf.'
          : 'Belum ada notifikasi baru dari bank yang terhubung.',
      icon: count > 0
          ? Icons.check_circle_outline_rounded
          : Icons.info_outline_rounded,
    );
  }

  Future<void> _showAddIgnoredPatternDialog() async {
    final patternCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    String? selectedBankId;

    final allBanks = widget.ruleSet.banks;

    final result = await showQuestDialog<(String, String)>(
      context,
      title: 'Tambah Pola Abaikan',
      content: QuestDialogDisposer(
        controllers: [patternCtrl, labelCtrl],
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Notifikasi yang mengandung kata kunci ini langsung dibuang, '
                  'nggak jadi draf.',
                  style: context.qBody(13),
                ),
                const SizedBox(height: Spacing.m),
                const QuestFieldLabel('Kata Kunci / Frasa'),
                const SizedBox(height: Spacing.xs),
                TextField(
                  controller: patternCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Misal: promo, cashback, pinjaman',
                  ),
                ),
                const SizedBox(height: Spacing.m),
                const QuestFieldLabel('Deskripsi / Label (Opsional)'),
                const SizedBox(height: Spacing.xs),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Misal: Promo Cashback',
                  ),
                ),
                const SizedBox(height: Spacing.m),
                QuestSelectField<String?>(
                  value: selectedBankId,
                  labelText: 'Berlaku Untuk',
                  sheetTitle: 'Pilih Bank / E-Wallet',
                  options: [
                    const QuestSelectOption<String?>(
                      value: null,
                      label: 'Semua Bank & E-Wallet',
                      icon: Icons.all_inclusive_rounded,
                    ),
                    for (final b in allBanks)
                      QuestSelectOption<String?>(
                        value: b.id,
                        label: b.displayName,
                        icon: Icons.account_balance_rounded,
                      ),
                  ],
                  onChanged: (val) =>
                      setDialogState(() => selectedBankId = val),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        QuestButton(
          label: 'Batal',
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        QuestButton(
          label: 'Simpan',
          icon: Icons.check_rounded,
          onPressed: () {
            final p = patternCtrl.text.trim();
            if (p.isNotEmpty) {
              Navigator.pop(context, (p, labelCtrl.text.trim()));
            }
          },
        ),
      ],
    );

    if (result != null && result.$1.isNotEmpty) {
      final (pattern, rawLabel) = result;
      final label = rawLabel.isNotEmpty ? rawLabel : 'Pola: "$pattern"';
      await widget.repository.addIgnoredPattern(
        pattern: pattern,
        label: label,
        bankId: selectedBankId,
      );
      await widget.pipeline.refreshRules();
      if (mounted) {
        questSnack(
          context,
          'Beres! Pola "$pattern" masuk daftar abaikan.',
          icon: Icons.check_circle_outline_rounded,
        );
      }
    }
  }

  void _openHealthSheet(Set<String> connected) {
    showSystemHealthSheet(
      context,
      listenerEnabled: _listenerEnabled,
      lastHeartbeat: _lastHeartbeat,
      connected: connected,
      latestCaptureLogStream: _latestCaptureLogStream,
      onOpenListenerSettings: () {
        if (_listenerEnabled) {
          widget.pipeline.channel.openListenerSettings();
        } else {
          Navigator.of(context).pop();
          _requireListenerPermission();
        }
      },
      onOpenBatterySettings: widget.pipeline.channel.openBatterySettings,
    );
  }

  void _openDiagnosticsSheet(Set<String> connected) {
    showDiagnosticsSheet(
      context,
      repository: widget.repository,
      pipeline: widget.pipeline,
      ruleSet: widget.ruleSet,
      connected: connected,
      ignoredDuplicatesStream: _ignoredDuplicatesStream,
      onReparseLogs: _reparseLogs,
      onPullActiveNotifications: _pullActiveNotifications,
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return Scaffold(
      backgroundColor: q.bg,
      appBar: QuestHeader(
        textScale: MediaQuery.textScalerOf(context).scale(1.0),
        title: 'Capture Notifikasi',
        showBack: true,
      ),
      body: StreamBuilder<Set<String>>(
        stream: _connectedBanksStream,
        builder: (context, connSnap) {
          final connected = connSnap.data ?? const <String>{};

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.m,
                  0,
                  Spacing.m,
                  Spacing.s,
                ),
                child: QuestSegmented<int>(
                  selected: _currentTab,
                  onChanged: (tab) {
                    HapticFeedback.selectionClick();
                    setState(() => _currentTab = tab);
                    if (_pageCtrl.hasClients) {
                      _pageCtrl.animateToPage(
                        tab,
                        duration: QuestMotion.medium,
                        curve: QuestMotion.easeOut,
                      );
                    }
                  },
                  options: const [
                    (value: 0, label: 'Bank & App', icon: null),
                    (value: 1, label: 'Sistem & Aturan', icon: null),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  onPageChanged: (page) => setState(() => _currentTab = page),
                  children: [
                    _buildBankAndAppTab(connected, q),
                    _buildSystemAndRulesTab(connected, q),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Tab 0: Bank & App — status pill ringkas + daftar bank & Mode Belajar.
  Widget _buildBankAndAppTab(Set<String> connected, QuestPalette q) {
    final allBanks = widget.ruleSet.banks;
    final filtered = _searchQuery.isEmpty
        ? allBanks
        : allBanks
              .where(
                (b) =>
                    b.displayName.toLowerCase().contains(_searchQuery) ||
                    b.id.toLowerCase().contains(_searchQuery),
              )
              .toList();

    final connectedList = filtered
        .where((b) => connected.contains(b.id))
        .toList();
    final availableList = filtered
        .where((b) => !connected.contains(b.id))
        .toList();

    return ListView(
      key: const PageStorageKey('capture_tab_banks'),
      padding: const EdgeInsets.fromLTRB(
        Spacing.m,
        Spacing.xs,
        Spacing.m,
        Spacing.xl,
      ),
      children: [
        _buildStatusPill(connected, q),
        const SizedBox(height: Spacing.m),

        StreamBuilder<bool>(
          stream: _autoRecordStream,
          initialData: false,
          builder: (context, snap) => QuestCard(
            padding: EdgeInsets.zero,
            child: QuestListTile(
              leading: Icon(Icons.bolt_rounded, color: q.primary),
              title: Text('Catat otomatis', style: context.qTitle(14.5)),
              subtitle: Text(
                'Notifikasi yang terbaca langsung jadi transaksi, tanpa '
                'konfirmasi.',
                style: context.qSmall(11.5).copyWith(color: q.muted),
              ),
              trailing: QuestSwitch(
                value: snap.data ?? false,
                label: 'Catat otomatis',
                onChanged: widget.repository.setAutoRecordEnabled,
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.m),

        TextField(
          controller: _searchCtrl,
          onChanged: (v) =>
              setState(() => _searchQuery = v.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Cari bank atau e-wallet…',
            prefixIcon: Icon(Icons.search_rounded, size: 18, color: q.muted),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: Spacing.s),

        if (connectedList.isNotEmpty) ...[
          QuestSectionHeader(title: 'Terhubung (${connectedList.length})'),
          QuestCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < connectedList.length; i++) ...[
                  _bankTile(connectedList[i], true, q),
                  if (i < connectedList.length - 1)
                    Divider(height: 1, thickness: 1, color: q.line),
                ],
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),
        ],

        if (availableList.isNotEmpty) ...[
          QuestSectionHeader(
            title: connectedList.isNotEmpty
                ? 'Tersedia Lainnya (${availableList.length})'
                : 'Pilih Bank / E-Wallet (${availableList.length})',
          ),
          QuestCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < availableList.length; i++) ...[
                  _bankTile(availableList[i], false, q),
                  if (i < availableList.length - 1)
                    Divider(height: 1, thickness: 1, color: q.line),
                ],
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),
        ],

        if (connectedList.isEmpty && availableList.isEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Spacing.xl),
            child: QuestEmpty(
              title: 'Bank tidak ditemukan',
              hint:
                  'Coba kata kunci lain, atau daftarkan lewat Mode Belajar di bawah.',
            ),
          ),
        ],

        const QuestSectionHeader(title: 'App Lain: Mode Belajar'),
        QuestCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bank/e-wallet yang belum ada di katalog? Hubungkan app-nya: '
                'semua notifikasinya akan jadi draf yang bisa kamu tinjau & catat.',
                style: context.qSmall().copyWith(color: q.muted),
              ),
              const SizedBox(height: Spacing.s),
              StreamBuilder<List<({String package, String label})>>(
                stream: _customBanksStream,
                builder: (context, snap) {
                  final customs = snap.data ?? const [];
                  if (customs.isEmpty) return const SizedBox.shrink();

                  return Column(
                    children: [
                      for (final app in customs) ...[
                        QuestListTile(
                          leading: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: q.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              app.label.characters.first.toUpperCase(),
                              style: TextStyle(
                                color: q.primaryText,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text(app.label, style: context.qTitle(14)),
                          subtitle: Text(
                            app.package,
                            style: context
                                .qSmall(10.5)
                                .copyWith(color: q.muted),
                          ),
                          trailing: QuestSwitch(
                            value: true,
                            label: 'Capture ${app.label}',
                            onChanged: (val) => _toggleCustom(app, val),
                          ),
                        ),
                        Divider(height: 1, thickness: 1, color: q.line),
                      ],
                    ],
                  );
                },
              ),
              QuestButton(
                label: 'Hubungkan App Lain dari HP',
                icon: Icons.add_rounded,
                tone: QuestTone.secondary,
                onPressed: _pickApp,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPill(Set<String> connected, QuestPalette q) {
    final isOk = _listenerEnabled;
    if (isOk) {
      return QuestPress(
        onTap: () => _openHealthSheet(connected),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.m,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: q.incomingTint,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: q.good.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: q.good, size: 18),
              const SizedBox(width: Spacing.s),
              Text(
                'Capture Aktif',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: q.good,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '· Detail izin & kesehatan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.qSmall(11.5).copyWith(color: q.muted),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: q.muted, size: 18),
            ],
          ),
        ),
      );
    }

    final hasConnected = connected.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(Spacing.m),
      decoration: BoxDecoration(
        color: q.outgoingTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: q.bad.withValues(alpha: 0.28)),
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
                  color: q.bad.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.notifications_off_rounded,
                  color: q.bad,
                  size: 19,
                ),
              ),
              const SizedBox(width: Spacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perlu Izin Notifikasi',
                      style: context.qTitle(14.5).copyWith(color: q.bad),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasConnected
                          ? 'Ada ${connected.length} akun terhubung, tapi izin akses notifikasi belum aktif. Nyalakan agar transaksi otomatis tercatat.'
                          : 'Aktifkan izin baca notifikasi atau pilih bank di bawah untuk mulai mencatat transaksi otomatis (100% offline di HP ini).',
                      style: context.qSmall().copyWith(
                        color: q.body,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Expanded(
                child: QuestButton(
                  label: 'Cek Kesehatan',
                  tone: QuestTone.secondary,
                  onPressed: () => _openHealthSheet(connected),
                ),
              ),
              const SizedBox(width: Spacing.s),
              Expanded(
                child: QuestButton(
                  label: 'Aktifkan Izin',
                  icon: Icons.notifications_active_rounded,
                  onPressed: _requireListenerPermission,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bankTile(BankRules bank, bool isConnected, QuestPalette q) {
    final kind = _accountKindForBank(bank);
    final icon = kind == AccountKind.ewallet
        ? Icons.phone_android_rounded
        : Icons.account_balance_rounded;
    final String subtitleText;
    final Color subtitleColor;
    if (!isConnected) {
      subtitleText = _listenerEnabled
          ? 'Ketuk saklar untuk menghubungkan'
          : 'Ketuk saklar untuk panduan izin & hubungkan';
      subtitleColor = q.muted;
    } else if (!_listenerEnabled) {
      subtitleText = 'Menunggu izin notifikasi';
      subtitleColor = q.warn;
    } else {
      subtitleText = 'Aktif dicatat otomatis';
      subtitleColor = q.good;
    }

    return QuestListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isConnected
              ? (_listenerEnabled
                    ? q.primary.withValues(alpha: 0.12)
                    : q.warnTint)
              : q.surface2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isConnected
              ? (_listenerEnabled ? q.primary : q.warn)
              : q.muted,
          size: 19,
        ),
      ),
      title: Text(bank.displayName, style: context.qTitle(14.5)),
      subtitle: Text(
        subtitleText,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: subtitleColor,
        ),
      ),
      trailing: QuestSwitch(
        value: isConnected,
        label: 'Capture ${bank.displayName}',
        onChanged: (val) => _toggleBank(bank, val),
      ),
    );
  }

  // Tab 1: Sistem & Aturan — izin ringkas, pola abaikan, template, & akses diagnostik.
  Widget _buildSystemAndRulesTab(Set<String> connected, QuestPalette q) {
    return ListView(
      key: const PageStorageKey('capture_tab_system_rules'),
      padding: const EdgeInsets.fromLTRB(
        Spacing.m,
        Spacing.xs,
        Spacing.m,
        Spacing.xl,
      ),
      children: [
        const QuestSectionHeader(title: 'Izin & Kesehatan'),
        QuestCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              QuestListTile(
                leading: Icon(
                  _listenerEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  color: _listenerEnabled ? q.good : q.bad,
                ),
                title: Text(
                  'Izin Akses Notifikasi',
                  style: context.qTitle(14.5),
                ),
                subtitle: Text(
                  _listenerEnabled
                      ? 'Aktif · Ketuk untuk cek pengaturan'
                      : 'Belum aktif · Ketuk untuk mengaktifkan',
                  style: context
                      .qSmall(11.5)
                      .copyWith(color: _listenerEnabled ? q.good : q.bad),
                ),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () {
                  if (_listenerEnabled) {
                    widget.pipeline.channel.openListenerSettings();
                  } else {
                    _requireListenerPermission();
                  }
                },
              ),
              Divider(height: 1, thickness: 1, color: q.line),
              QuestListTile(
                leading: Icon(Icons.battery_saver_rounded, color: q.text),
                title: Text('Optimasi Baterai', style: context.qTitle(14.5)),
                subtitle: Text(
                  'Setel ke "Tidak Dibatasi"',
                  style: context.qSmall(11.5).copyWith(color: q.muted),
                ),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: widget.pipeline.channel.openBatterySettings,
              ),
              Divider(height: 1, thickness: 1, color: q.line),
              QuestListTile(
                leading: Icon(Icons.monitor_heart_rounded, color: q.primary),
                title: Text(
                  'Lampu Sehat & Panduan Vendor',
                  style: context.qTitle(14.5),
                ),
                subtitle: Text(
                  'Status aktivitas & tips Xiaomi, Samsung, OPPO, Vivo',
                  style: context.qSmall(11.5).copyWith(color: q.muted),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => _openHealthSheet(connected),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.m),

        Row(
          children: [
            const Expanded(child: QuestSectionHeader(title: 'Pola Diabaikan')),
            QuestPress(
              onTap: _showAddIgnoredPatternDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: q.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 14, color: q.primaryText),
                    const SizedBox(width: 4),
                    Text(
                      'Tambah',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: q.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        StreamBuilder<List<IgnoredPattern>>(
          stream: _ignoredPatternsStream,
          builder: (_, snap) {
            final ignoredList = snap.data ?? const <IgnoredPattern>[];
            if (ignoredList.isEmpty) {
              return QuestCard(
                child: Text(
                  'Belum ada pola abaikan. Tap "Tambah" untuk memblokir kata '
                  'kunci promo atau spam.',
                  style: context.qSmall().copyWith(color: q.muted),
                ),
              );
            }

            return QuestCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < ignoredList.length; i++) ...[
                    QuestListTile(
                      leading: Icon(
                        Icons.block_rounded,
                        color: q.bad,
                        size: 19,
                      ),
                      title: Text(
                        ignoredList[i].label,
                        style: context.qTitle(14),
                      ),
                      subtitle: Text(
                        'Pola: "${ignoredList[i].pattern}"'
                        '${ignoredList[i].bankId != null ? ' · ${ignoredList[i].bankId}' : ''}',
                        style: TextStyle(fontSize: 11.5, color: q.muted),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: q.bad,
                          size: 20,
                        ),
                        tooltip: 'Hapus Pola Abaikan',
                        onPressed: () => _confirmDeleteIgnored(ignoredList[i]),
                      ),
                    ),
                    if (i < ignoredList.length - 1)
                      Divider(height: 1, thickness: 1, color: q.line),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: Spacing.m),

        const QuestSectionHeader(title: 'Template Kustom'),
        StreamBuilder<List<CustomTemplate>>(
          stream: _customTemplatesStream,
          builder: (_, snap) {
            final customTemplates = snap.data ?? const <CustomTemplate>[];
            if (customTemplates.isEmpty) {
              return QuestCard(
                child: Text(
                  'Belum ada template kustom. Template otomatis dibuat saat '
                  'kamu melatih pembacaan notifikasi.',
                  style: context.qSmall().copyWith(color: q.muted),
                ),
              );
            }

            return QuestCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < customTemplates.length; i++) ...[
                    QuestListTile(
                      leading: Icon(
                        Icons.tune_rounded,
                        color: q.primary,
                        size: 19,
                      ),
                      title: Text(
                        customTemplates[i].template.name,
                        style: context.qTitle(14),
                      ),
                      subtitle: Text(
                        '${widget.ruleSet.bank(customTemplates[i].bankId)?.displayName ?? customTemplates[i].bankId} · '
                        '${customTemplates[i].template.direction == Direction.incoming ? 'Masuk' : 'Keluar'}',
                        style: TextStyle(fontSize: 11.5, color: q.muted),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: q.bad,
                          size: 20,
                        ),
                        tooltip: 'Hapus Template',
                        onPressed: () =>
                            _confirmDeleteTemplate(customTemplates[i]),
                      ),
                    ),
                    if (i < customTemplates.length - 1)
                      Divider(height: 1, thickness: 1, color: q.line),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: Spacing.m),

        const QuestSectionHeader(title: 'Diagnostik'),
        QuestCard(
          padding: EdgeInsets.zero,
          child: QuestListTile(
            leading: Icon(Icons.build_circle_outlined, color: q.accent),
            title: Text(
              'Alat Diagnostik & Pemulihan',
              style: context.qTitle(14.5),
            ),
            subtitle: Text(
              'Pindai ulang, tarik notif, log mentah, simulator, duplikat',
              style: context.qSmall(11.5).copyWith(color: q.muted),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => _openDiagnosticsSheet(connected),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteIgnored(IgnoredPattern pattern) async {
    final confirmed = await showQuestDialog<bool>(
      context,
      title: 'Hapus Pola Abaikan?',
      content: Text(
        'Pola "${pattern.label}" dihapus. Notifikasi dengan kata kunci ini '
        'bakal diproses ulang.',
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
    if (confirmed == true) {
      await widget.repository.deleteIgnoredPattern(pattern.id);
      await widget.pipeline.refreshRules();
      if (!mounted) return;
      questSnack(context, 'Pola abaikan dihapus.');
    }
  }

  Future<void> _confirmDeleteTemplate(CustomTemplate customTemplate) async {
    final confirmed = await showQuestDialog<bool>(
      context,
      title: 'Hapus Template Aturan?',
      content: Text(
        'Aturan "${customTemplate.template.name}" bakal dihapus.',
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
    if (confirmed == true) {
      await widget.repository.deleteCustomTemplate(customTemplate.id);
      await widget.pipeline.refreshRules();
      if (!mounted) return;
      questSnack(context, 'Template aturan dihapus.');
    }
  }
}
