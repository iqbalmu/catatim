import 'dart:async';

import 'package:flutter/material.dart';

import '../capture/pipeline.dart';
import '../core/dates_id.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkListenerStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    if (!mounted) return;
    setState(() {
      _listenerEnabled = enabled;
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

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return Scaffold(
      backgroundColor: q.bg,
      appBar: const QuestHeader(
        title: 'Capture Notifikasi',
        subtitle: 'Pengaturan otomatisasi transaksi bank offline',
        showBack: true,
      ),
      body: StreamBuilder<Set<String>>(
        stream: widget.repository.watchConnectedBanks(),
        builder: (context, connSnap) {
          final connected = connSnap.data ?? const <String>{};

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.m,
              Spacing.s,
              Spacing.m,
              Spacing.xl,
            ),
            children: [
              // ── 1. Status Izin Notifikasi Sistem ──
              QuestEnter(
                index: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const QuestSectionHeader(title: 'Izin Sistem Android'),
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
                                      ? SeedColors.incomingTint
                                      : SeedColors.outgoingTint,
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
                                      style: context
                                          .qTitle(15)
                                          .copyWith(
                                            color: _listenerEnabled
                                                ? q.good
                                                : q.bad,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _listenerEnabled
                                          ? 'Bukuduit diizinkan membaca notifikasi masuk secara lokal di perangkat.'
                                          : 'Android membutuhkan izin akses notifikasi agar Bukuduit dapat mendeteksi transaksi secara otomatis.',
                                      style: context
                                          .qSmall(12)
                                          .copyWith(color: q.muted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (!_listenerEnabled) ...[
                            const SizedBox(height: Spacing.m),
                            QuestButton(
                              label: 'Buka Pengaturan Izin Android',
                              icon: Icons.settings_rounded,
                              onPressed:
                                  widget.pipeline.channel.openListenerSettings,
                            ),
                          ] else ...[
                            const SizedBox(height: Spacing.s),
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
                              onPressed:
                                  widget.pipeline.channel.openListenerSettings,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.m),

              // ── 2. Bank & E-Wallet yang Dicatat Otomatis ──
              QuestEnter(
                index: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const QuestSectionHeader(title: 'Bank & E-Wallet Didukung'),
                    Text(
                      'Nyalakan bank yang kamu gunakan. Notifikasi dari bank yang aktif akan diproses menjadi draf konfirmasi di Beranda.',
                      style: context.qSmall(12).copyWith(color: q.muted),
                    ),
                    const SizedBox(height: Spacing.xs),

                    QuestCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (
                            var i = 0;
                            i < widget.ruleSet.banks.length;
                            i++
                          ) ...[
                            Builder(
                              builder: (context) {
                                final bank = widget.ruleSet.banks[i];
                                final isConnected = connected.contains(bank.id);
                                final kind = _accountKindForBank(bank);
                                final IconData icon =
                                    kind == AccountKind.ewallet
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
                                  title: Text(
                                    bank.displayName,
                                    style: context.qTitle(14.5),
                                  ),
                                  subtitle: Text(
                                    isConnected
                                        ? 'Aktif dicatat otomatis'
                                        : 'Tidak aktif',
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
                              },
                            ),
                            if (i < widget.ruleSet.banks.length - 1)
                              Divider(height: 1, thickness: 1, color: q.line),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.m),

              // ── Mode Belajar: app apa pun ──
              QuestEnter(
                index: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const QuestSectionHeader(title: 'App Lain — Mode Belajar'),
                    QuestCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bank/e-wallet yang belum didukung? Hubungkan app-nya: '
                            'SEMUA notifikasinya jadi draf yang kamu putuskan — '
                            'nominal & kategori kamu isi sendiri saat konfirmasi.',
                            style: context.qSmall(12).copyWith(color: q.muted),
                          ),
                          const SizedBox(height: Spacing.s),
                          StreamBuilder<List<({String package, String label})>>(
                            stream: widget.repository.watchCustomBanks(),
                            builder: (context, snap) {
                              final customs = snap.data ?? const [];
                              if (customs.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                children: [
                                  for (final app in customs) ...[
                                    QuestListTile(
                                      leading: Container(
                                        width: 38,
                                        height: 38,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: SeedColors.primaryLight,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          app.label.characters.first
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color: q.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        app.label,
                                        style: context.qTitle(14),
                                      ),
                                      subtitle: Text(
                                        app.package,
                                        style: context
                                            .qSmall(10.5)
                                            .copyWith(color: q.muted),
                                      ),
                                      trailing: QuestSwitch(
                                        value: true,
                                        label: 'Capture ${app.label}',
                                        onChanged: (val) =>
                                            _toggleCustom(app, val),
                                      ),
                                    ),
                                    Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: q.line,
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                          QuestButton(
                            label: 'Hubungkan App Lain',
                            icon: Icons.add_rounded,
                            tone: QuestTone.secondary,
                            onPressed: _pickApp,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.m),
              // ── 3. Ketahanan Latar Belakang (Baterai) ──
              QuestEnter(
                index: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                            'Beberapa produsen HP (Xiaomi, Vivo, Oppo, Samsung) mematikan listener notifikasi secara agresif. Setel optimasi baterai ke "Tidak Dibatasi" agar draf transaksi selalu masuk.',
                            style: context.qSmall(12).copyWith(color: q.muted),
                          ),
                          const SizedBox(height: Spacing.s),
                          QuestButton(
                            label: 'Buka Pengaturan Baterai Android',
                            icon: Icons.open_in_new_rounded,
                            tone: QuestTone.secondary,
                            onPressed:
                                widget.pipeline.channel.openBatterySettings,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.m),

              // ── 4. Diagnostik / Baca Ulang ──
              QuestEnter(
                index: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const QuestSectionHeader(title: 'Diagnostik & Pemulihan'),
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
                                  Icons.history_rounded,
                                  color: q.text,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: Spacing.s),
                              Expanded(
                                child: Text(
                                  'Pindai Ulang Notifikasi Lampau',
                                  style: context.qTitle(14.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            'Jika ada notifikasi bank yang masuk saat bank belum terhubung atau saat format baru ditambahkan, jalankan pemindaian ulang untuk mengubahnya menjadi draf.',
                            style: context.qSmall(12).copyWith(color: q.muted),
                          ),
                          const SizedBox(height: Spacing.s),
                          QuestButton(
                            label: 'Pindai Ulang Notifikasi Lampau',
                            icon: Icons.refresh_rounded,
                            tone: QuestTone.secondary,
                            onPressed: () => _reparseLogs(connected),
                          ),
                          const SizedBox(height: Spacing.s),
                          QuestButton(
                            label: 'Tarik Notifikasi yang Masih Tayang',
                            icon: Icons.download_rounded,
                            tone: QuestTone.secondary,
                            onPressed: _pullActiveNotifications,
                          ),
                          const SizedBox(height: Spacing.s),
                          QuestButton(
                            label: 'Buka Notifikasi Belum Terbaca',
                            icon: Icons.mark_email_unread_rounded,
                            tone: QuestTone.secondary,
                            onPressed: () => UnparsedLogsSheet.show(
                              context,
                              repository: widget.repository,
                              pipeline: widget.pipeline,
                              ruleSet: widget.ruleSet,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── 4c. Aturan & Template Kustom ──
              StreamBuilder<List<CustomTemplate>>(
                stream: widget.repository.watchCustomTemplates(),
                builder: (context, snap) {
                  final customTemplates = snap.data ?? const <CustomTemplate>[];
                  if (customTemplates.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const QuestSectionHeader(
                        title: 'Aturan & Template Kustom',
                      ),
                      Text(
                        'Template yang kamu buat dari notifikasi mentah. Pola ini diprioritaskan saat memproses notifikasi bank.',
                        style: context.qSmall(12).copyWith(color: q.muted),
                      ),
                      const SizedBox(height: Spacing.xs),
                      QuestCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (
                              var i = 0;
                              i < customTemplates.length;
                              i++
                            ) ...[
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
                                  tooltip: 'Hapus Aturan',
                                  onPressed: () async {
                                    final confirmed = await showQuestDialog<bool>(
                                      context,
                                      title: 'Hapus Template Aturan?',
                                      content: Text(
                                        'Aturan "${customTemplates[i].template.name}" akan dihapus. Notifikasi selanjutnya tidak akan dicocokkan dengan aturan ini.',
                                        style: context.qBody(13),
                                      ),
                                      actions: [
                                        QuestButton(
                                          label: 'Batal',
                                          tone: QuestTone.secondary,
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                        ),
                                        QuestButton(
                                          label: 'Hapus',
                                          tone: QuestTone.danger,
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                        ),
                                      ],
                                    );
                                    if (confirmed == true) {
                                      await widget.repository
                                          .deleteCustomTemplate(
                                            customTemplates[i].id,
                                          );
                                      await widget.pipeline.refreshRules();
                                      if (context.mounted) {
                                        questSnack(
                                          context,
                                          'Template aturan dihapus',
                                          icon: Icons.delete_outline_rounded,
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                              if (i < customTemplates.length - 1)
                                Divider(height: 1, thickness: 1, color: q.line),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.m),
                    ],
                  );
                },
              ),

              QuestEnter(
                index: 5,
                child:
                    // ── 4b. Duplikat yang diabaikan dedup ──
                    StreamBuilder<List<CaptureLog>>(
                      stream: widget.repository.watchIgnoredDuplicates(),
                      builder: (context, dupSnap) {
                        final dups = dupSnap.data ?? const <CaptureLog>[];
                        if (dups.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const QuestSectionHeader(
                              title: 'Duplikat yang Diabaikan',
                            ),
                            Text(
                              'Notifikasi ini dianggap duplikat — bank, nominal, dan arah sama dalam 2 menit — sehingga tidak menjadi draf. Tap untuk mencatat manual, geser ke kiri untuk menghapus.',
                              style: context
                                  .qSmall(12)
                                  .copyWith(color: q.muted),
                            ),
                            const SizedBox(height: Spacing.xs),
                            QuestCard(
                              padding: EdgeInsets.zero,
                              child: Column(
                                children: [
                                  for (var i = 0; i < dups.length; i++) ...[
                                    Dismissible(
                                      key: ValueKey(
                                        'ignored-dup-${dups[i].id}',
                                      ),
                                      direction: DismissDirection.endToStart,
                                      onDismissed: (_) => widget.repository
                                          .deleteCaptureLog(dups[i].id),
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(
                                          right: Spacing.m,
                                        ),
                                        decoration: BoxDecoration(
                                          color: q.bad.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.card,
                                          ),
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
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
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
                                          '${idDateTime(dups[i].postedAt)} · '
                                          '${dups[i].packageName}',
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
                                      Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: q.line,
                                      ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: Spacing.m),
                          ],
                        );
                      },
                    ),
              ),
              const SizedBox(height: Spacing.m),

              QuestEnter(
                index: 6,
                child:
                    // ── 5. Jaminan Privasi ──
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
                              '100% Offline & Privat. Bukuduit memproses teks notifikasi murni di perangkat HP tanpa internet dan tanpa analitik.',
                              style: context
                                  .qSmall(11.5)
                                  .copyWith(color: q.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
              ),
            ],
          );
        },
      ),
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
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.75,
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
                    isDense: true,
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
                            color: isOn ? SeedColors.incomingTint : q.surface2,
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
    );
  }
}
