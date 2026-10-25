import 'package:flutter/material.dart';

import '../capture/pipeline.dart';
import '../game/progress.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'add_account_sheet.dart';
import 'backup_screen.dart';
import 'bank_accounts_screen.dart';
import 'gamification_sheet.dart';
import 'notif_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
    required this.progress,
  });
  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;
  final ProgressService progress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: AppBar(
        backgroundColor: context.q.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Pengaturan',
          style: context.qTitle(20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.xl,
        ),
        children: [
          // Grup 1: Rekening & Notifikasi Bank
          _SectionHeader(title: 'REKENING & OTOMATISASI'),
          const SizedBox(height: Spacing.xs),
          Container(
            decoration: BoxDecoration(
              color: context.q.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: context.q.line),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                StreamBuilder<List<Account>>(
                  stream: repository.watchAccounts(),
                  builder: (context, snapshot) {
                    final accounts = snapshot.data ?? const [];
                    return _SettingsRow(
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: context.q.primary,
                      iconBg: SeedColors.primaryLight,
                      title: 'Kelola Akun & Bank',
                      subtitle: '${accounts.length} akun terdaftar',
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
                _divider(context),
                _SettingsRow(
                  icon: Icons.add_circle_outline_rounded,
                  iconColor: context.q.good,
                  iconBg: SeedColors.incomingTint,
                  title: 'Tambah Akun Baru',
                  subtitle: 'Bank, e-wallet, atau dompet tunai',
                  onTap: () => AddAccountSheet.show(
                    context,
                    repository: repository,
                    pipeline: pipeline,
                    ruleSet: ruleSet,
                  ),
                ),
                _divider(context),
                StreamBuilder<List<Draft>>(
                  stream: repository.watchDrafts(),
                  builder: (context, snapshot) {
                    final drafts = snapshot.data ?? const [];
                    return _SettingsRow(
                      icon: Icons.notifications_none_rounded,
                      iconColor: SeedColors.honey,
                      iconBg: SeedColors.honey50,
                      title: 'Log & Draf Notifikasi',
                      subtitle: drafts.isNotEmpty
                          ? '${drafts.length} draf transaksi belum dikonfirmasi'
                          : 'Riwayat tangkapan notifikasi bank',
                      trailing: drafts.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.q.bad,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                '${drafts.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotificationScreen(
                            repository: repository,
                            pipeline: pipeline,
                            ruleSet: ruleSet,
                            progress: progress,
                            onOpenRencana: () => Navigator.pop(context),
                            onOpenBon: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),

          // Grup 2: Gamifikasi & Karakter
          _SectionHeader(title: 'GAMIFIKASI & MOTIVASI'),
          const SizedBox(height: Spacing.xs),
          Container(
            decoration: BoxDecoration(
              color: context.q.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: context.q.line),
              boxShadow: AppShadows.card,
            ),
            child: _SettingsRow(
              icon: Icons.emoji_events_rounded,
              iconColor: SeedColors.honey,
              iconBg: SeedColors.honey50,
              title: 'Pochy & Gamifikasi Disiplin',
              subtitle: 'Pantau streak, level keuangan, dan lencana hemat',
              onTap: () => GamificationSheet.show(context, progress),
            ),
          ),
          const SizedBox(height: Spacing.m),

          // Grup 3: Keamanan & Data
          _SectionHeader(title: 'KEAMANAN & DATA'),
          const SizedBox(height: Spacing.xs),
          Container(
            decoration: BoxDecoration(
              color: context.q.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: context.q.line),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.shield_outlined,
                  iconColor: context.q.primary,
                  iconBg: SeedColors.primaryLight,
                  title: 'Backup & Pulihkan Database',
                  subtitle: 'Salinan terenkripsi PIN, simpan aman di perangkat',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BackupScreen(repository: repository),
                    ),
                  ),
                ),
                _divider(context),
                _SettingsRow(
                  icon: Icons.cloud_off_rounded,
                  iconColor: context.q.muted,
                  iconBg: context.q.surface2,
                  title: 'Penyimpanan 100% Offline',
                  subtitle: 'Data keuangan tidak pernah dikirim ke internet',
                  trailing: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),

          // Grup 4: Info Aplikasi
          _SectionHeader(title: 'TENTANG BUKUDUIT'),
          const SizedBox(height: Spacing.xs),
          Container(
            padding: const EdgeInsets.all(Spacing.m),
            decoration: BoxDecoration(
              color: context.q.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: context.q.line),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [context.q.primary, context.q.violet],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: Spacing.s),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'bukuduit',
                          style: context.qTitle(17),
                        ),
                        Text(
                          'Versi 1.0.0 • Offline Personal Finance',
                          style: context.qSmall(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.s),
                Text(
                  'Pencatat keuangan pribadi offline dengan capture notifikasi bank otomatis. Didesain cepat, jelas, dan tanpa pelacak iklan.',
                  style: context.qBody(13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.q.line,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: context.q.muted,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.m,
          vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadius.tile),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: context.q.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.qSmall(12),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: context.q.muted.withValues(alpha: 0.5),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
