import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../core/budget.dart';
import '../core/money.dart';
import '../game/progress.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'account_detail_screen.dart';
import 'add_account_sheet.dart';
import 'gamification_sheet.dart';
import 'notif_screen.dart';
import 'quest.dart';
import 'settings_screen.dart';
import 'transaction_sheet.dart';
import 'transaction_tile.dart';

/// Header bagian atas Beranda: Brand logo + streak chip netral + lonceng + settings

// Dipecah ke part files (audit I-01).
part 'home_cards/budget_summary.dart';
part 'home_cards/draft_banner.dart';
part 'home_cards/recent_tx.dart';
part 'home_cards/total_balance.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.progress,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
    required this.onOpenAnggaran,
    required this.onOpenBon,
  });

  final ProgressService progress;
  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;
  final VoidCallback onOpenAnggaran;
  final VoidCallback onOpenBon;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final summary = progress.latest;
    final streakDays = summary?.streakDays ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.m,
        Spacing.m,
        Spacing.m,
        Spacing.xs,
      ),
      child: Row(
        children: [
          // Brand Logo & Title
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [q.primary, q.violet],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: q.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: Spacing.s),
                Text(
                  'bukuduit',
                  style: context.qTitle(19).copyWith(letterSpacing: -0.5),
                ),
              ],
            ),
          ),

          // Streak Chip Button (Netral, tidak menyaingi saldo)
          Tooltip(
            message: summary?.streakPaused == true
                ? 'Streak disiplin dijeda (atur batas di Anggaran untuk aktifkan)'
                : '$streakDays hari disiplin hemat',
            child: QuestPress(
              onTap: () => GamificationSheet.show(context, progress),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: q.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: q.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: streakDays > 0 ? q.warn : q.muted,
                      size: 17,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$streakDays h',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: q.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: Spacing.s),

          // Notification Bell Inbox Button
          StreamBuilder<List<Draft>>(
            stream: repository.watchDrafts(),
            builder: (context, snapshot) {
              final draftCount = (snapshot.data ?? const []).length;
              // Label semantik untuk pembaca layar (audit H-01).
              return Tooltip(
                message: 'Notifikasi',
                child: Semantics(
                  label: 'Notifikasi',
                  button: true,
                  child: QuestPress(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NotificationScreen(
                          repository: repository,
                          pipeline: pipeline,
                          progress: progress,
                          ruleSet: ruleSet,
                          onOpenAnggaran: onOpenAnggaran,
                          onOpenBon: onOpenBon,
                        ),
                      ),
                    ),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: q.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: q.line),
                        boxShadow: AppShadows.card,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            color: q.text,
                            size: 19,
                          ),
                          if (draftCount > 0)
                            Positioned(
                              top: 7,
                              right: 7,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: q.bad,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: Spacing.s),

          // Settings Button
          Tooltip(
            message: 'Pengaturan',
            child: Semantics(
              label: 'Pengaturan',
              button: true,
              child: QuestPress(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                      repository: repository,
                      pipeline: pipeline,
                      ruleSet: ruleSet,
                      progress: progress,
                      onOpenAnggaran: onOpenAnggaran,
                      onOpenBon: onOpenBon,
                    ),
                  ),
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: q.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: q.line),
                    boxShadow: AppShadows.card,
                  ),
                  child: Icon(Icons.settings_outlined, color: q.text, size: 19),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
