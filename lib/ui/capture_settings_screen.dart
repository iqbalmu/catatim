import 'dart:async';

import 'package:flutter/material.dart';

import '../capture/pipeline.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

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
                    if (!_listenerEnabled) ...[
                      const SizedBox(height: Spacing.m),
                      QuestButton(
                        label: 'Buka Pengaturan Izin Android',
                        icon: Icons.settings_rounded,
                        onPressed: widget.pipeline.channel.openListenerSettings,
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
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        onPressed: widget.pipeline.channel.openListenerSettings,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Spacing.m),

              // ── 2. Bank & E-Wallet yang Dicatat Otomatis ──
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
                    for (var i = 0; i < widget.ruleSet.banks.length; i++) ...[
                      Builder(
                        builder: (context) {
                          final bank = widget.ruleSet.banks[i];
                          final isConnected = connected.contains(bank.id);
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
                        },
                      ),
                      if (i < widget.ruleSet.banks.length - 1)
                        Divider(height: 1, thickness: 1, color: q.line),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Spacing.m),

              // ── 3. Ketahanan Latar Belakang (Baterai) ──
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
                      onPressed: widget.pipeline.channel.openBatterySettings,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.m),

              // ── 4. Diagnostik / Baca Ulang ──
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
                      label: 'Pindai Ulang Notifikasi',
                      icon: Icons.refresh_rounded,
                      tone: QuestTone.secondary,
                      onPressed: () => _reparseLogs(connected),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.m),

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
                    Icon(Icons.lock_outline_rounded, color: q.primary, size: 20),
                    const SizedBox(width: Spacing.s),
                    Expanded(
                      child: Text(
                        '100% Offline & Privat. Bukuduit memproses teks notifikasi murni di perangkat HP tanpa internet dan tanpa analitik.',
                        style: context.qSmall(11.5).copyWith(color: q.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
