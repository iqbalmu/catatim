import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
part 'home_cards/daily_pace_hero.dart';
part 'home_cards/draft_banner.dart';
part 'home_cards/recent_tx.dart';
part 'home_cards/stacked_cards.dart';
part 'home_cards/total_balance.dart';

class HomeTopBar extends StatefulWidget {
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
  State<HomeTopBar> createState() => _HomeTopBarState();
}

class _HomeTopBarState extends State<HomeTopBar> {
  ProgressService get progress => widget.progress;
  LedgerRepository get repository => widget.repository;
  CapturePipeline get pipeline => widget.pipeline;
  RuleSet get ruleSet => widget.ruleSet;
  VoidCallback get onOpenAnggaran => widget.onOpenAnggaran;
  VoidCallback get onOpenBon => widget.onOpenBon;

  late final Stream<List<Draft>> _draftsStream;

  @override
  void initState() {
    super.initState();
    _draftsStream = widget.repository.watchDrafts();
  }

  @override
  void didUpdateWidget(covariant HomeTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _draftsStream = widget.repository.watchDrafts();
    }
  }

  ({String title, String subtitle}) _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) {
      return (
        title: 'Selamat pagi',
        subtitle: 'Awali hari dengan catatan rapi',
      );
    }
    if (hour >= 11 && hour < 15) {
      return (
        title: 'Selamat siang',
        subtitle: 'Sudah catat pengeluaran hari ini?',
      );
    }
    if (hour >= 15 && hour < 18) {
      return (
        title: 'Selamat sore',
        subtitle: 'Yuk rekap belanjaan hari ini',
      );
    }
    return (
      title: 'Selamat malam',
      subtitle: 'Waktunya cek sisa anggaranmu',
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final summary = progress.latest;
    final streakDays = summary?.streakDays ?? 0;
    final greeting = _getGreeting();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.m,
        Spacing.m,
        Spacing.m,
        Spacing.s,
      ),
      child: Row(
        children: [
          // Greeting & Friendly Prompt
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greeting.title,
                  style: context.qTitle(17).copyWith(
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  greeting.subtitle,
                  style: context.qSmall(12).copyWith(
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
            stream: _draftsStream,
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
                        boxShadow: q.cardShadow,
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
                    boxShadow: q.cardShadow,
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
