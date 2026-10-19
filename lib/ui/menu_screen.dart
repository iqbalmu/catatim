import 'package:flutter/material.dart';

import '../capture/pipeline.dart';
import '../rules/rule_set.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'backup_screen.dart';
import 'bank_accounts_screen.dart';
import 'capture_settings_screen.dart';
import 'quest.dart';

/// Layar Menu: catat otomatis (pengaturan baca notifikasi bank), bank &
/// akun, plus backup.
class MenuScreen extends StatelessWidget {
  const MenuScreen({
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
      appBar: const QuestHeader(
        title: 'Menu',
        subtitle: 'Akun & data',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.m,
        ),
        children: [
          QuestCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MenuRow(
                  icon: Icons.notifications_active_rounded,
                  title: 'Catat otomatis',
                  subtitle: 'Notifikasi bank jadi catatan otomatis',
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
                Divider(
                  height: 1,
                  thickness: 2,
                  color: context.q.line.withValues(alpha: 0.35),
                ),
                _MenuRow(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Bank & akun',
                  subtitle: 'Tambah akun & atur saldo',
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
                ),
                Divider(
                  height: 1,
                  thickness: 2,
                  color: context.q.line.withValues(alpha: 0.35),
                ),
                _MenuRow(
                  icon: Icons.backup_outlined,
                  title: 'Backup & pulihkan',
                  subtitle: 'Simpan salinan datamu — aman di HP ini',
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
    );
  }
}

/// Baris menu: ikon bulat + judul + subjudul + panah.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QuestPress(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.m),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.q.honey.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: context.q.text),
            ),
            const SizedBox(width: Spacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.qTitle(15)),
                  Text(subtitle, style: context.qSmall()),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.q.muted),
          ],
        ),
      ),
    );
  }
}
