import 'package:flutter/material.dart';

import '../capture/pipeline.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'backup_screen.dart';
import 'bank_accounts_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;

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
          // ── Seksi 1: Rekening & Bank ────────────────────────────
          _SectionHeader(title: 'REKENING & OTOMATISASI'),
          const SizedBox(height: Spacing.xs),
          Container(
            decoration: BoxDecoration(
              color: context.q.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: context.q.line),
              boxShadow: AppShadows.card,
            ),
            child: StreamBuilder<List<Account>>(
              stream: repository.watchAccounts(),
              builder: (context, snapshot) {
                final accounts = snapshot.data ?? const [];
                return _SettingsRow(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: context.q.primary,
                  iconBg: SeedColors.primaryLight,
                  title: 'Kelola Akun & Bank',
                  subtitle: '${accounts.length} akun terdaftar · Tambah, edit, koneksi bank',
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
          ),
          const SizedBox(height: Spacing.m),

          // ── Seksi 2: Keamanan & Data ────────────────────────────
          _SectionHeader(title: 'KEAMANAN & DATA'),
          const SizedBox(height: Spacing.xs),
          Container(
            decoration: BoxDecoration(
              color: context.q.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: context.q.line),
              boxShadow: AppShadows.card,
            ),
            child: _SettingsRow(
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
          ),
          const SizedBox(height: Spacing.m),

          // ── Seksi 3: Info Aplikasi ──────────────────────────────
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
                        Text('bukuduit', style: context.qTitle(17)),
                        Text(
                          'Versi 1.0.0 · Offline Personal Finance',
                          style: context.qSmall(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.s),
                Text(
                  'Pencatat keuangan pribadi offline dengan capture notifikasi bank otomatis.',
                  style: context.qBody(13),
                ),
                const SizedBox(height: Spacing.s),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: SeedColors.incomingTint,
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        color: Color(0xFF059669),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '100% Offline · Data keuangan tersimpan lokal di perangkatmu, tanpa server eksternal atau pelacak.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF065F46),
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
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
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
            if (onTap != null)
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
