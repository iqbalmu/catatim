import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../core/dates_id.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'capture_simulator_sheet.dart';
import 'quest.dart';
import 'transaction_sheet.dart';
import 'unparsed_logs_sheet.dart';

/// Halaman Pengaturan Capture Notifikasi Bank & E-Wallet Offline
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
  int _currentTab = 0; // 0 = Bank & E-Wallet, 1 = Izin & Sistem, 2 = Aturan & Alat
  late final PageController _pageCtrl = PageController(initialPage: _currentTab);
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkListenerStatus();
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

  Future<void> _toggleBank(BankRules bank, bool connected) async {
    await widget.repository.setBankConnected(bank.id, connected);
    if (connected) {
      // Pastikan ada akun padanan di database
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
    } else {
      if (mounted) {
        questSnack(
          context,
          'Capture ${bank.displayName} dinonaktifkan.',
          icon: Icons.link_off_rounded,
        );
      }
    }
    // Allowlist antrean native harus mengikuti koneksi terbaru.
    await widget.pipeline.syncAllowedPackages();
  }

  Future<void> _toggleCustom(
    ({String package, String label}) app,
    bool connected,
  ) async {
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
      builder: (_) => _AppPickerSheet(apps: apps, connected: existing),
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
      if (created > 0) {
        questSnack(
          context,
          'Berhasil membuat $created draf dari notifikasi lampau.',
          icon: Icons.auto_awesome_rounded,
        );
      } else {
        questSnack(
          context,
          'Tidak ada notifikasi baru yang dapat diproses.',
          icon: Icons.info_outline_rounded,
        );
      }
    } catch (_) {
      if (mounted) {
        questSnack(
          context,
          'Gagal memproses ulang notifikasi.',
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
          ? '$count notifikasi aktif ditarik dan diproses menjadi draf.'
          : 'Tidak ada notifikasi baru dari bank terhubung yang sedang tayang.',
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

    final confirmed = await showQuestDialog<bool>(
      context,
      title: 'Tambah Pola Abaikan',
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Notifikasi yang mengandung kata kunci ini akan otomatis dibuang dan tidak diproses menjadi draf.',
                style: context.qBody(13),
              ),
              const SizedBox(height: Spacing.m),
              TextField(
                controller: patternCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Kata Kunci / Frasa',
                  hintText: 'Misal: promo, cashback, pinjaman',
                ),
              ),
              const SizedBox(height: Spacing.s),
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi / Label (opsional)',
                  hintText: 'Misal: Promo Cashback',
                ),
              ),
              const SizedBox(height: Spacing.s),
              DropdownButtonFormField<String?>(
                initialValue: selectedBankId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Berlaku Untuk',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Semua Bank & E-Wallet'),
                  ),
                  for (final b in allBanks)
                    DropdownMenuItem(
                      value: b.id,
                      child: Text(b.displayName),
                    ),
                ],
                onChanged: (val) => setDialogState(() => selectedBankId = val),
              ),
            ],
          );
        },
      ),
      actions: [
        QuestButton(
          label: 'Batal',
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context, false),
        ),
        QuestButton(
          label: 'Simpan',
          icon: Icons.check_rounded,
          onPressed: () {
            if (patternCtrl.text.trim().isNotEmpty) {
              Navigator.pop(context, true);
            }
          },
        ),
      ],
    );

    if (confirmed == true && patternCtrl.text.trim().isNotEmpty) {
      final pattern = patternCtrl.text.trim();
      final label = labelCtrl.text.trim().isNotEmpty
          ? labelCtrl.text.trim()
          : 'Pola: "$pattern"';
      await widget.repository.addIgnoredPattern(
        pattern: pattern,
        label: label,
        bankId: selectedBankId,
      );
      await widget.pipeline.refreshRules();
      if (mounted) {
        questSnack(
          context,
          'Pola "$pattern" berhasil ditambahkan ke daftar abaikan.',
          icon: Icons.check_circle_outline_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return Scaffold(
      backgroundColor: q.bg,
      appBar: QuestHeader(
        textScale: MediaQuery.textScalerOf(context).scale(1.0),
        title: 'Capture Notifikasi',
        subtitle: 'Pengaturan otomatisasi transaksi bank offline',
        showBack: true,
      ),
      body: StreamBuilder<Set<String>>(
        stream: widget.repository.watchConnectedBanks(),
        builder: (context, connSnap) {
          final connected = connSnap.data ?? const <String>{};

          return Column(
            children: [
              // ── Sub-Tabs Segmented Bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.m,
                  Spacing.xs,
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
                    (value: 0, label: 'Bank & E-Wallet', icon: null),
                    (value: 1, label: 'Izin & Sistem', icon: null),
                    (value: 2, label: 'Aturan & Alat', icon: null),
                  ],
                ),
              ),

              // ── PageView Konten Tab ──
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  onPageChanged: (page) => setState(() => _currentTab = page),
                  children: [
                    _buildBankTab(connected, q),
                    _buildPermissionTab(connected, q),
                    _buildRulesAndDiagnosticsTab(connected, q),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 0: BANK & E-WALLET
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildBankTab(Set<String> connected, QuestPalette q) {
    final allBanks = widget.ruleSet.banks;
    final filtered = _searchQuery.isEmpty
        ? allBanks
        : allBanks
            .where((b) =>
                b.displayName.toLowerCase().contains(_searchQuery) ||
                b.id.toLowerCase().contains(_searchQuery))
            .toList();

    final connectedList =
        filtered.where((b) => connected.contains(b.id)).toList();
    final availableList =
        filtered.where((b) => !connected.contains(b.id)).toList();

    return ListView(
      key: const PageStorageKey('capture_tab_banks'),
      padding: const EdgeInsets.fromLTRB(
        Spacing.m,
        Spacing.xs,
        Spacing.m,
        Spacing.xl,
      ),
      children: [
        // Search Bar
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

        // 1. Bank Terhubung (Aktif)
        if (connectedList.isNotEmpty) ...[
          QuestSectionHeader(
            title: 'Terhubung (${connectedList.length})',
          ),
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

        // 2. Bank Tersedia (Belum Terhubung)
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

        // Jika pencarian kosong
        if (connectedList.isEmpty && availableList.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
            child: QuestEmpty(
              title: 'Bank tidak ditemukan',
              hint:
                  'Gunakan kata kunci lain atau daftarkan lewat Mode Belajar di bawah.',
            ),
          ),
        ],

        // 3. Mode Belajar (App Lain dari HP)
        const QuestSectionHeader(title: 'App Lain — Mode Belajar'),
        QuestCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bank/e-wallet yang belum ada di katalog? Hubungkan app-nya: '
                'semua notifikasinya akan jadi draf yang bisa kamu tinjau & catat.',
                style: context.qSmall(12).copyWith(color: q.muted),
              ),
              const SizedBox(height: Spacing.s),
              StreamBuilder<List<({String package, String label})>>(
                stream: widget.repository.watchCustomBanks(),
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

  Widget _bankTile(BankRules bank, bool isConnected, QuestPalette q) {
    final kind = _accountKindForBank(bank);
    final IconData icon = kind == AccountKind.ewallet
        ? Icons.phone_android_rounded
        : Icons.account_balance_rounded;

    return QuestListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isConnected
              ? q.primary.withValues(alpha: 0.12)
              : q.surface2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isConnected ? q.primary : q.muted,
          size: 19,
        ),
      ),
      title: Text(bank.displayName, style: context.qTitle(14.5)),
      subtitle: Text(
        isConnected ? 'Aktif dicatat otomatis' : 'Tidak aktif',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: isConnected ? q.good : q.muted,
        ),
      ),
      trailing: QuestSwitch(
        value: isConnected,
        label: 'Capture ${bank.displayName}',
        onChanged: (val) => _toggleBank(bank, val),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 1: IZIN & SISTEM
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildPermissionTab(Set<String> connected, QuestPalette q) {
    return ListView(
      key: const PageStorageKey('capture_tab_permissions'),
      padding: const EdgeInsets.fromLTRB(
        Spacing.m,
        Spacing.xs,
        Spacing.m,
        Spacing.xl,
      ),
      children: [
        // 1. Indikator Kesehatan Penangkap (Lampu Sehat)
        const QuestSectionHeader(title: 'Kesehatan Penangkap (Lampu Sehat)'),
        _buildLampuSehatCard(connected, q),
        const SizedBox(height: Spacing.m),

        // 2. Status Izin Notifikasi Sistem
        const QuestSectionHeader(title: 'Izin Akses Notifikasi'),
        QuestCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _listenerEnabled
                          ? q.incomingTint
                          : q.outgoingTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _listenerEnabled
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_rounded,
                      color: _listenerEnabled ? q.good : q.bad,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: Spacing.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _listenerEnabled
                              ? 'Akses Notifikasi Aktif'
                              : 'Akses Notifikasi Belum Aktif',
                          style: context.qTitle(15).copyWith(
                                color: _listenerEnabled ? q.good : q.bad,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _listenerEnabled
                              ? 'Bukuduit diizinkan membaca notifikasi masuk secara lokal di perangkat.'
                              : 'Android membutuhkan izin akses notifikasi agar Bukuduit dapat mendeteksi transaksi secara otomatis.',
                          style: context.qSmall(12).copyWith(color: q.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.m),
              if (!_listenerEnabled) ...[
                QuestButton(
                  label: 'Buka Pengaturan Izin Android',
                  icon: Icons.settings_rounded,
                  onPressed: widget.pipeline.channel.openListenerSettings,
                ),
              ] else ...[
                TextButton.icon(
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                    foregroundColor: q.muted,
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text(
                    'Cek ulang di Pengaturan Sistem',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: widget.pipeline.channel.openListenerSettings,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.m),

        // 2. Ketahanan Latar Belakang (Baterai)
        const QuestSectionHeader(title: 'Ketahanan Latar Belakang'),
        QuestCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: q.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.battery_saver_rounded,
                      color: q.text,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: Spacing.s),
                  Expanded(
                    child: Text(
                      'Optimasi Baterai HP',
                      style: context.qTitle(14.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                'Setel optimasi baterai ke "Tidak Dibatasi" (Unrestricted) agar sistem Android tidak mematikan service capture secara agresif saat layar mati.',
                style: context.qSmall(12).copyWith(color: q.muted),
              ),
              const SizedBox(height: Spacing.s),
              QuestButton(
                label: 'Buka Pengaturan Baterai Android',
                icon: Icons.open_in_new_rounded,
                tone: QuestTone.secondary,
                onPressed: widget.pipeline.channel.openBatterySettings,
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.m),

        // 3. Panduan Khusus per Merk HP (Vendor Tips)
        const QuestSectionHeader(title: 'Panduan Khusus Vendor HP'),
        _buildVendorGuideCard(q),
        const SizedBox(height: Spacing.m),

        // 4. Jaminan Privasi
        Container(
          padding: const EdgeInsets.all(Spacing.m),
          decoration: BoxDecoration(
            color: q.surface2.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: q.line),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: q.primary,
                size: 20,
              ),
              const SizedBox(width: Spacing.s),
              Expanded(
                child: Text(
                  '100% Offline & Privat. Bukuduit memproses teks notifikasi murni di perangkat HP tanpa koneksi internet dan tanpa analitik.',
                  style: context.qSmall(11.5).copyWith(color: q.muted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLampuSehatCard(Set<String> connected, QuestPalette q) {
    return StreamBuilder<CaptureLog?>(
      stream: widget.repository.watchLatestCaptureLog(),
      builder: (context, snapshot) {
        final latestLog = snapshot.data;
        final now = DateTime.now();
        final hasConnected = connected.isNotEmpty;
        final daysSinceCapture = latestLog != null
            ? now.difference(latestLog.postedAt).inDays
            : null;
        final bool isStale = hasConnected &&
            ((daysSinceCapture != null && daysSinceCapture >= 7) ||
                (latestLog == null &&
                    _lastHeartbeat != null &&
                    now.difference(_lastHeartbeat!).inDays >= 7));

        final Color statusColor;
        final String statusBadge;
        final String statusTitle;
        final String statusDesc;
        final IconData statusIcon;

        if (!_listenerEnabled) {
          statusColor = q.bad;
          statusBadge = 'TIDAK AKTIF';
          statusTitle = 'Layanan Terhenti';
          statusDesc =
              'Akses notifikasi di sistem Android belum diaktifkan sehingga Bukuduit tidak dapat menangkap mutasi.';
          statusIcon = Icons.error_outline_rounded;
        } else if (isStale) {
          statusColor = q.warn;
          statusBadge = 'PERIKSA';
          statusTitle = 'Perlu Pemeriksaan';
          statusDesc =
              'Bank terhubung aktif tetapi 0 notifikasi masuk selama ${daysSinceCapture ?? '>7'} hari. Kemungkinan service tertidur oleh optimasi baterai HP.';
          statusIcon = Icons.warning_amber_rounded;
        } else if (_lastHeartbeat == null && latestLog == null) {
          statusColor = q.primary;
          statusBadge = 'MENUNGGU';
          statusTitle = 'Siap & Menunggu';
          statusDesc =
              'Service aktif di latar belakang dan siap menerima notifikasi transaksi pertama masuk.';
          statusIcon = Icons.hourglass_empty_rounded;
        } else {
          statusColor = q.good;
          statusBadge = 'OPTIMAL';
          statusTitle = 'Kondisi Optimal';
          statusDesc =
              'Sistem penangkap aktif normal dan siap mendeteksi transaksi secara realtime.';
          statusIcon = Icons.check_circle_outline_rounded;
        }

        return QuestCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: Spacing.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              statusTitle,
                              style: context.qTitle(15).copyWith(
                                    color: statusColor,
                                  ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                statusBadge,
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          statusDesc,
                          style: context.qSmall(12).copyWith(color: q.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.m),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.m,
                  vertical: Spacing.s,
                ),
                decoration: BoxDecoration(
                  color: q.surface2.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  border: Border.all(color: q.line.withValues(alpha: 0.6)),
                ),
                child: Column(
                  children: [
                    _buildHealthMetricRow(
                      q: q,
                      label: 'Detak Listener',
                      value: _lastHeartbeat != null
                          ? idTimeAgo(_lastHeartbeat!, now)
                          : 'Belum tercatat',
                      icon: Icons.favorite_rounded,
                      iconColor: _lastHeartbeat != null ? q.good : q.muted,
                    ),
                    Divider(height: Spacing.m, color: q.line.withValues(alpha: 0.4)),
                    _buildHealthMetricRow(
                      q: q,
                      label: 'Notif Bank Terakhir',
                      value: latestLog != null
                          ? '${latestLog.packageName.split('.').last} • ${idTimeAgo(latestLog.postedAt, now)}'
                          : 'Belum ada',
                      icon: Icons.receipt_long_rounded,
                      iconColor: latestLog != null ? q.primary : q.muted,
                    ),
                    Divider(height: Spacing.m, color: q.line.withValues(alpha: 0.4)),
                    _buildHealthMetricRow(
                      q: q,
                      label: 'Bank Terpantau',
                      value: hasConnected
                          ? '${connected.length} bank aktif'
                          : 'Belum ada bank terhubung',
                      icon: Icons.account_balance_rounded,
                      iconColor: hasConnected ? q.good : q.warn,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHealthMetricRow({
    required QuestPalette q,
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: Spacing.xs),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: q.muted,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: q.text,
          ),
        ),
      ],
    );
  }

  Widget _buildVendorGuideCard(QuestPalette q) {
    return QuestCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const PageStorageKey('vendor_guide_expansion_tile'),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: q.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.phone_android_rounded, color: q.primary, size: 20),
          ),
          title: Text('Panduan Khusus per Merk HP', style: context.qTitle(14.5)),
          subtitle: Text(
            'Xiaomi, Samsung, OPPO, Realme, & Vivo',
            style: context.qSmall(11.5).copyWith(color: q.muted),
          ),
          childrenPadding:
              const EdgeInsets.fromLTRB(Spacing.m, 0, Spacing.m, Spacing.m),
          children: [
            Divider(height: 1, thickness: 1, color: q.line),
            const SizedBox(height: Spacing.s),
            _vendorItem(
              brand: 'Xiaomi / POCO / Redmi (MIUI / HyperOS)',
              steps: [
                'Buka Info Aplikasi Bukuduit → aktifkan "Mulai Otomatis" (Autostart).',
                'Di Penghemat Baterai → pilih "Tidak Ada Pembatasan".',
                'Buka Recent Apps → tekan & tahan kartu Bukuduit → tap ikon "Gembok".',
              ],
              q: q,
            ),
            const SizedBox(height: Spacing.m),
            _vendorItem(
              brand: 'Samsung (One UI)',
              steps: [
                'Buka Pengaturan HP → Aplikasi → Bukuduit → Baterai.',
                'Pilih opsi "Tidak Dibatasi" (Unrestricted).',
                'Pastikan Bukuduit tidak ada di daftar "Aplikasi yang Dinonaktifkan" (Sleeping Apps).',
              ],
              q: q,
            ),
            const SizedBox(height: Spacing.m),
            _vendorItem(
              brand: 'OPPO & Realme (ColorOS / Realme UI)',
              steps: [
                'Buka Info Aplikasi Bukuduit → Penggunaan Baterai → izinkan "Aktivitas di Latar Belakang" & "Mulai Otomatis".',
                'Buka Recent Apps → tap titik tiga di kartu Bukuduit → pilih "Kunci" (Lock).',
              ],
              q: q,
            ),
            const SizedBox(height: Spacing.m),
            _vendorItem(
              brand: 'Vivo & iQOO (Funtouch OS / OriginOS)',
              steps: [
                'Buka Pengaturan HP → Baterai → Konsumsi Daya Latar Belakang Tinggi → izinkan Bukuduit.',
                'Di Pengaturan Aplikasi / Izin → aktifkan "Mulai Otomatis".',
              ],
              q: q,
            ),
          ],
        ),
      ),
    );
  }

  Widget _vendorItem({
    required String brand,
    required List<String> steps,
    required QuestPalette q,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          brand,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: q.primaryText,
          ),
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}. ',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: q.muted,
                  ),
                ),
                Expanded(
                  child: Text(
                    steps[i],
                    style: context.qSmall(11.5).copyWith(height: 1.3),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 2: ATURAN & ALAT
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildRulesAndDiagnosticsTab(Set<String> connected, QuestPalette q) {
    return ListView(
      key: const PageStorageKey('capture_tab_rules'),
      padding: const EdgeInsets.fromLTRB(
        Spacing.m,
        Spacing.xs,
        Spacing.m,
        Spacing.xl,
      ),
      children: [
        // 1. Alat Diagnostik & Pemulihan
        const QuestSectionHeader(title: 'Alat Diagnostik & Pemulihan'),
        QuestCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              QuestListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: q.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.refresh_rounded, color: q.primary, size: 20),
                ),
                title: Text('Pindai Ulang Notifikasi Lampau',
                    style: context.qTitle(14.5)),
                subtitle: Text(
                  'Coba proses ulang notifikasi yang belum terbaca',
                  style: context.qSmall(11.5),
                ),
                onTap: () => _reparseLogs(connected),
              ),
              Divider(height: 1, thickness: 1, color: q.line),
              QuestListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: q.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.download_rounded, color: q.primary, size: 20),
                ),
                title: Text('Tarik Notifikasi yang Masih Tayang',
                    style: context.qTitle(14.5)),
                subtitle: Text(
                  'Tarik notifikasi bank yang ada di bar status saat ini',
                  style: context.qSmall(11.5),
                ),
                onTap: _pullActiveNotifications,
              ),
              Divider(height: 1, thickness: 1, color: q.line),
              QuestListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: q.surface2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.mark_email_unread_rounded,
                      color: q.text, size: 20),
                ),
                title: Text('Buka Log Notifikasi Belum Terbaca',
                    style: context.qTitle(14.5)),
                subtitle: Text(
                  'Lihat notifikasi mentah yang gagal terbaca untuk dilatih',
                  style: context.qSmall(11.5),
                ),
                onTap: () => UnparsedLogsSheet.show(
                  context,
                  repository: widget.repository,
                  pipeline: widget.pipeline,
                  ruleSet: widget.ruleSet,
                ),
              ),
              Divider(height: 1, thickness: 1, color: q.line),
              QuestListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: q.surface2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.science_rounded,
                      color: q.violet, size: 20),
                ),
                title: Text('Simulator & Validasi Notifikasi',
                    style: context.qTitle(14.5)),
                subtitle: Text(
                  'Uji coba parsing format notifikasi bank tanpa transaksi nyata',
                  style: context.qSmall(11.5),
                ),
                onTap: () => CaptureSimulatorSheet.show(
                  context,
                  repository: widget.repository,
                  pipeline: widget.pipeline,
                  ruleSet: widget.ruleSet,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.m),

        // 2. Pola Notifikasi yang Diabaikan (Blacklist)
        Row(
          children: [
            const Expanded(
              child: QuestSectionHeader(title: 'Pola Notifikasi yang Diabaikan'),
            ),
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
        Text(
          'Notifikasi yang mengandung kata kunci di bawah akan otomatis dibuang dan tidak menjadi draf.',
          style: context.qSmall(12).copyWith(color: q.muted),
        ),
        const SizedBox(height: Spacing.xs),
        StreamBuilder<List<IgnoredPattern>>(
          stream: widget.repository.watchIgnoredPatterns(),
          builder: (_, snap) {
            final ignoredList = snap.data ?? const <IgnoredPattern>[];
            if (ignoredList.isEmpty) {
              return QuestCard(
                child: Row(
                  children: [
                    Icon(Icons.filter_alt_off_rounded,
                        color: q.muted, size: 20),
                    const SizedBox(width: Spacing.s),
                    Expanded(
                      child: Text(
                        'Belum ada pola abaikan. Tap "Tambah" untuk memblokir kata kunci promo/spam.',
                        style: context.qSmall(12).copyWith(color: q.muted),
                      ),
                    ),
                  ],
                ),
              );
            }

            return QuestCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < ignoredList.length; i++) ...[
                    QuestListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: q.surface2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.block_rounded,
                          color: q.bad,
                          size: 19,
                        ),
                      ),
                      title: Text(
                        ignoredList[i].label,
                        style: context.qTitle(14),
                      ),
                      subtitle: Text(
                        'Pola: "${ignoredList[i].pattern}"'
                        '${ignoredList[i].bankId != null ? ' · Bank: ${ignoredList[i].bankId}' : ''}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: q.muted,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: q.bad,
                          size: 20,
                        ),
                        tooltip: 'Hapus Pola Abaikan',
                        onPressed: () async {
                          final confirmed = await showQuestDialog<bool>(
                            context,
                            title: 'Hapus Pola Abaikan?',
                            content: Text(
                              'Pola "${ignoredList[i].label}" akan dihapus. Notifikasi yang mengandung kata kunci ini akan diproses kembali.',
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
                            await widget.repository
                                .deleteIgnoredPattern(ignoredList[i].id);
                            await widget.pipeline.refreshRules();
                            if (!mounted) return;
                            questSnack(context, 'Pola abaikan dihapus.');
                          }
                        },
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

        // 3. Aturan & Template Kustom
        const QuestSectionHeader(title: 'Aturan & Template Kustom'),
        Text(
          'Template yang kamu buat dari penyesuaian draf/log. Pola ini diprioritaskan saat memproses notifikasi bank.',
          style: context.qSmall(12).copyWith(color: q.muted),
        ),
        const SizedBox(height: Spacing.xs),
        StreamBuilder<List<CustomTemplate>>(
          stream: widget.repository.watchCustomTemplates(),
          builder: (_, snap) {
            final customTemplates = snap.data ?? const <CustomTemplate>[];
            if (customTemplates.isEmpty) {
              return QuestCard(
                child: Text(
                  'Belum ada template kustom. Template otomatis terbentuk ketika kamu menyesuaikan pembacaan notifikasi mentah.',
                  style: context.qSmall(12).copyWith(color: q.muted),
                ),
              );
            }

            return QuestCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < customTemplates.length; i++) ...[
                    QuestListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: q.surface2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: q.primary,
                          size: 19,
                        ),
                      ),
                      title: Text(
                        customTemplates[i].template.name,
                        style: context.qTitle(14),
                      ),
                      subtitle: Text(
                        '${widget.ruleSet.bank(customTemplates[i].bankId)?.displayName ?? customTemplates[i].bankId} · '
                        '${customTemplates[i].template.direction == Direction.incoming ? 'Masuk' : 'Keluar'} · '
                        'Kata kunci: ${[...customTemplates[i].template.matchAll, ...customTemplates[i].template.matchAny].join(', ')}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: q.muted,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: q.bad,
                          size: 20,
                        ),
                        tooltip: 'Hapus Template',
                        onPressed: () async {
                          final confirmed = await showQuestDialog<bool>(
                            context,
                            title: 'Hapus Template Aturan?',
                            content: Text(
                              'Aturan "${customTemplates[i].template.name}" akan dihapus.',
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
                            await widget.repository
                                .deleteCustomTemplate(customTemplates[i].id);
                            await widget.pipeline.refreshRules();
                            if (!mounted) return;
                            questSnack(context, 'Template aturan dihapus.');
                          }
                        },
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

        // 4. Duplikat yang Diabaikan (Dedup)
        StreamBuilder<List<CaptureLog>>(
          stream: widget.repository.watchIgnoredDuplicates(),
          builder: (context, dupSnap) {
            final dups = dupSnap.data ?? const <CaptureLog>[];
            if (dups.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const QuestSectionHeader(title: 'Duplikat yang Diabaikan'),
                Text(
                  'Notifikasi ini dianggap duplikat (bank, nominal, & arah sama dalam 2 menit) sehingga tidak menjadi draf ganda. Geser ke kiri untuk menghapus.',
                  style: context.qSmall(12).copyWith(color: q.muted),
                ),
                const SizedBox(height: Spacing.xs),
                QuestCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < dups.length; i++) ...[
                        Dismissible(
                          key: ValueKey('ignored-dup-${dups[i].id}'),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) =>
                              widget.repository.deleteCaptureLog(dups[i].id),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: Spacing.m),
                            decoration: BoxDecoration(
                              color: q.bad.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                            ),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: q.bad,
                            ),
                          ),
                          child: QuestListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: q.surface2,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.copy_rounded,
                                color: q.muted,
                                size: 19,
                              ),
                            ),
                            title: Text(
                              dups[i].body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.qTitle(14),
                            ),
                            subtitle: Text(
                              '${idDateTime(dups[i].postedAt)} · ${dups[i].packageName}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: q.muted,
                              ),
                            ),
                            onTap: () => TransactionSheet.show(
                              context,
                              widget.repository,
                            ),
                          ),
                        ),
                        if (i < dups.length - 1)
                          Divider(height: 1, thickness: 1, color: q.line),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Sheet pilih app terpasang untuk Mode Belajar: pencarian + daftar,
/// app yang sudah terhubung ditandai.
class _AppPickerSheet extends StatefulWidget {
  const _AppPickerSheet({required this.apps, required this.connected});

  final List<({String package, String label})> apps;
  final List<({String package, String label})> connected;

  @override
  State<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final lower = _query.toLowerCase();
    final filtered = widget.apps
        .where(
          (a) =>
              a.label.toLowerCase().contains(lower) ||
              a.package.toLowerCase().contains(lower),
        )
        .toList();
    final connectedPkgs = widget.connected.map((c) => c.package).toSet();
    final bottomInset = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset.bottom),
      child: Container(
        height: (MediaQuery.sizeOf(context).height * 0.75 - bottomInset.bottom)
            .clamp(180.0, double.infinity),
        decoration: BoxDecoration(
          color: q.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
      child: Column(
        children: [
          const QuestGrabber(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.m,
              0,
              Spacing.m,
              Spacing.s,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hubungkan App', style: context.qTitle(15)),
                const SizedBox(height: Spacing.xs),
                Text(
                  'Pilih app bank/e-wallet — notifikasinya akan jadi draf '
                  'yang kamu putuskan.',
                  style: context.qSmall(12).copyWith(color: q.muted),
                ),
                const SizedBox(height: Spacing.s),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Cari nama app…',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada app yang cocok.',
                      style: context.qSmall(12).copyWith(color: q.muted),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final app = filtered[i];
                      final isOn = connectedPkgs.contains(app.package);
                      return QuestListTile(
                        onTap: () => Navigator.pop(context, app),
                        leading: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isOn ? q.incomingTint : q.surface2,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            app.label.characters.first.toUpperCase(),
                            style: TextStyle(
                              color: isOn ? q.good : q.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(app.label, style: context.qTitle(13.5)),
                        subtitle: Text(
                          app.package,
                          style: context.qSmall(10).copyWith(color: q.muted),
                        ),
                        trailing: isOn
                            ? Icon(Icons.link_rounded, size: 18, color: q.good)
                            : const Icon(Icons.chevron_right_rounded, size: 22),
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }
}
