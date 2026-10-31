import 'package:flutter/material.dart';

import '../capture/pipeline.dart';
import '../game/progress.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'backup_screen.dart';
import 'bank_accounts_screen.dart';
import 'capture_settings_screen.dart';
import 'quest.dart';
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
    this.progress,
    this.onOpenAnggaran,
    this.onOpenBon,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;
  final ProgressService? progress;
  final VoidCallback? onOpenAnggaran;
  final VoidCallback? onOpenBon;
  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return Scaffold(
      backgroundColor: q.bg,
      appBar: const QuestHeader(
        title: 'Pengaturan',
        subtitle: 'Konfigurasi & preferensi sistem',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.xl,
        ),
        children: [
          // ── Seksi 1: Data & Rekening ──
          QuestEnter(
            index: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          const QuestSectionHeader(title: 'Data & Rekening'),
          QuestCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                StreamBuilder<List<Account>>(
                  stream: repository.watchAccounts(),
                  builder: (context, snapshot) {
                    final accounts = snapshot.data ?? const [];
                    return QuestListTile(
                      leading: _SettingIcon(
                        icon: Icons.account_balance_wallet_rounded,
                        color: q.primary,
                        bgColor: q.primaryLight,
                      ),
                      title: Text('Kelola Akun & Bank', style: context.qTitle(15)),
                      subtitle: Text(
                        '${accounts.length} akun terdaftar · Tambah & koneksi bank',
                        style: context.qSmall(12),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BankAccountsScreen(
                            repository: repository,
                            pipeline: pipeline,
                            ruleSet: ruleSet,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Divider(height: 1, thickness: 1, color: q.line),
                QuestListTile(
                  leading: _SettingIcon(
                    icon: Icons.shield_outlined,
                    color: q.primary,
                    bgColor: q.primaryLight,
                  ),
                  title: Text('Backup & Pulihkan Data', style: context.qTitle(15)),
                  subtitle: Text(
                    'Salinan database terenkripsi PIN lokal di HP',
                    style: context.qSmall(12),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BackupScreen(repository: repository),
                    ),
                  ),
                ),
              ],
            ),
          ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),

          // ── Seksi 2: Otomatisasi & Capture ──
          QuestEnter(
            index: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          const QuestSectionHeader(title: 'Otomatisasi & Capture'),
          QuestCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                QuestListTile(
                  leading: _SettingIcon(
                    icon: Icons.notifications_active_outlined,
                    color: q.good,
                    bgColor: SeedColors.incomingTint,
                  ),
                  title: Text('Pengaturan Capture Notifikasi', style: context.qTitle(15)),
                  subtitle: Text(
                    'Izin sistem, bank terhubung, & optimasi baterai',
                    style: context.qSmall(12),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CaptureSettingsScreen(
                        repository: repository,
                        pipeline: pipeline,
                        ruleSet: ruleSet,
                      ),
                    ),
                  ),
                ),
                QuestListTile(
                  leading: _SettingIcon(
                    icon: Icons.battery_saver_rounded,
                    color: q.text,
                    bgColor: q.surface2,
                  ),
                  title: Text('Pengaturan Baterai Sistem', style: context.qTitle(15)),
                  subtitle: Text(
                    'Cegah Android menutup listener di latar belakang',
                    style: context.qSmall(12),
                  ),
                  onTap: pipeline.channel.openBatterySettings,
                ),
              ],
            ),
          ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),

          // ── Seksi 3: Tentang Aplikasi ──
          QuestEnter(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          const QuestSectionHeader(title: 'Tentang Bukuduit'),
          QuestCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [q.primary, q.violet],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: Spacing.s),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('bukuduit', style: context.qTitle(16)),
                        Text(
                          'Versi 1.0.0 · Offline Personal Finance',
                          style: context.qSmall(12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.s),
                Text(
                  'Pencatat keuangan pribadi offline dengan capture notifikasi bank lokal di perangkatmu.',
                  style: context.qBody(12.5),
                ),
                const SizedBox(height: Spacing.s),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: SeedColors.incomingTint,
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    border: Border.all(color: q.good.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        color: q.good,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '100% Offline · Data keuangan tersimpan lokal di perangkatmu, tanpa server eksternal atau pelacak.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: q.good,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon({
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  final IconData icon;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
