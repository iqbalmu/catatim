import 'package:flutter/material.dart';

import '../game/progress.dart';
import '../rules/engine.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'account_manage_screen.dart';
import 'backup_screen.dart';
import 'quest.dart';
import 'rules_screen.dart';

/// Layar Menu: pengganti popup ⋯ — kelola akun, rencana·batas, backup, dan
/// aturan capture sebagai halaman penuh.
class MenuScreen extends StatelessWidget {
  const MenuScreen({
    super.key,
    required this.repository,
    required this.engine,
    required this.progress,
    required this.onOpenRencana,
  });

  final LedgerRepository repository;
  final RuleEngine engine;
  final ProgressService progress;

  /// Alih tab ke Rencana (dipanggil setelah layar ini ditutup).
  final VoidCallback onOpenRencana;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: const QuestHeader(
        title: 'Menu',
        subtitle: 'Akun, batas, backup, aturan',
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
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Kelola akun',
                  subtitle: 'Bank, e-wallet, dan tunai',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AccountManageScreen(repository: repository),
                    ),
                  ),
                ),
                _divider(context),
                _MenuRow(
                  icon: Icons.savings_rounded,
                  title: 'Rencana · Batas',
                  subtitle: 'Batas harian, mingguan, bulanan',
                  onTap: () {
                    Navigator.pop(context);
                    onOpenRencana();
                  },
                ),
                _divider(context),
                _MenuRow(
                  icon: Icons.backup_outlined,
                  title: 'Backup & pulihkan',
                  subtitle: 'Ekspor CSV dan backup terenkripsi',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BackupScreen(repository: repository),
                    ),
                  ),
                ),
                _divider(context),
                _MenuRow(
                  icon: Icons.rule_rounded,
                  title: 'Aturan capture',
                  subtitle: 'Aturanmu dipakai sebelum aturan bawaan',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RulesScreen(
                        repository: repository,
                        engine: engine,
                        progress: progress,
                      ),
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

  Widget _divider(BuildContext context) => Divider(
    height: 1,
    thickness: 2,
    color: context.q.line.withValues(alpha: 0.35),
  );
}

/// Baris menu: ikon bulat + judul + subjudul + panah, meniru _ActionRow
/// di backup_screen.
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
