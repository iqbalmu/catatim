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

  ({String title, String subtitle, IconData icon, List<Color> colors})
      _getGreeting(QuestPalette q) {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) {
      return (
        title: 'Selamat pagi 👋',
        subtitle: 'Awali hari dengan catatan rapi',
        icon: Icons.wb_sunny_rounded,
        colors: [const Color(0xFFF59E0B), q.primary],
      );
    }
    if (hour >= 11 && hour < 15) {
      return (
        title: 'Selamat siang 👋',
        subtitle: 'Sudah catat pengeluaran hari ini?',
        icon: Icons.wb_sunny_rounded,
        colors: [const Color(0xFF38BDF8), q.primary],
      );
    }
    if (hour >= 15 && hour < 18) {
      return (
        title: 'Selamat sore 👋',
        subtitle: 'Yuk rekap belanjaan hari ini',
        icon: Icons.wb_twilight_rounded,
        colors: [const Color(0xFFFB923C), q.violet],
      );
    }
    return (
      title: 'Selamat malam 👋',
      subtitle: 'Waktunya cek sisa anggaranmu',
      icon: Icons.nightlight_round,
      colors: [q.primary, q.violet],
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final summary = progress.latest;
    final streakDays = summary?.streakDays ?? 0;
    final greeting = _getGreeting(q);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.m,
        Spacing.m,
        Spacing.m,
        Spacing.xs,
      ),
      child: Row(
        children: [
          // Greeting & Friendly Prompt
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: greeting.colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: greeting.colors.first.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    greeting.icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: Spacing.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        greeting.title,
                        style: context.qTitle(16).copyWith(
                          letterSpacing: -0.3,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        greeting.subtitle,
                        style: context.qSmall(11.5).copyWith(
                          color: q.muted,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.s),

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

          // Profile & Settings Button
          Tooltip(
            message: 'Profil & Pengaturan',
            child: Semantics(
              label: 'Profil & Pengaturan',
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
                      showBack: true,
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
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: q.text,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
