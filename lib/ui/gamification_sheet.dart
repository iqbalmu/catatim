import 'package:flutter/material.dart';

import '../core/dates_id.dart';
import '../game/mascot.dart';
import '../game/progress.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';

class GamificationSheet extends StatelessWidget {
  const GamificationSheet({
    super.key,
    required this.progress,
  });

  final ProgressService progress;

  static Future<void> show(BuildContext context, ProgressService progress) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GamificationSheet(progress: progress),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = progress.latest;
    final stats = summary?.saverStats;
    final mood = summary?.mood ?? MascotMood.idle;
    final streakDays = summary?.streakDays ?? 0;
    final isPaused = summary?.streakPaused ?? false;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: BoxDecoration(
        color: context.q.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: Column(
        children: [
          // Drag handle & Header
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.s, Spacing.m, Spacing.xs),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.q.muted.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.s),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: SeedColors.honey50,
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: SeedColors.honey,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: Spacing.s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pochy, Sahabat Hematmu',
                            style: context.qTitle(16),
                          ),
                          Text(
                            'Nemenin kamu ngatur uang tiap hari',
                            style: context.qSmall(),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: context.q.muted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // Scrollable Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(Spacing.m),
              children: [
                // 1. Panggung Maskot & Mood
                MascotStage(
                  mood: mood,
                  size: 150,
                  glow: SeedColors.honeyBright.withValues(alpha: 0.4),
                  glowStrength: 0.7,
                ),
                const SizedBox(height: Spacing.s),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.m,
                    vertical: Spacing.s,
                  ),
                  decoration: BoxDecoration(
                    color: SeedColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    summary?.moodLine ?? 'Pochy memantau keuanganmu',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.q.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: Spacing.m),

                // 2. Disiplin Streak Card
                Container(
                  padding: const EdgeInsets.all(Spacing.m),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [SeedColors.honey50, SeedColors.honey100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: SeedColors.honeyBright),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.tile),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x15F59E0B),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.local_fire_department_rounded,
                          color: context.q.warn,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: Spacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPaused ? 'Belum Mulai' : '$streakDays Hari Berturut-turut',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                color: SeedColors.honeyText,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isPaused
                                  ? 'Atur batas harian dulu yuk, biar hitungannya jalan lagi.'
                                  : 'Pengeluaran harianmu terjaga rapi dalam batas aman.',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: SeedColors.honeyInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.m),

                // 3. Level & XP Saver Card
                if (stats != null) ...[
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.q.primary,
                                        borderRadius: BorderRadius.circular(AppRadius.pill),
                                      ),
                                      child: Text(
                                        'Level ${stats.level}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: Spacing.xs),
                                    Text(
                                      stats.title,
                                      style: context.qTitle(15),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              '${stats.currentXp} dari ${stats.nextLevelXp} poin',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: context.q.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.s),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: stats.progress.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: context.q.surface2,
                            valueColor: AlwaysStoppedAnimation<Color>(context.q.primary),
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                        Text(
                          'Catat pengeluaran & jaga batas harianmu — poinnya jalan sendiri.',
                          style: context.qSmall(11.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.m),

                  // 4. Lencana Disiplin Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lencanamu',
                        style: context.qTitle(15),
                      ),
                      Text(
                        '${stats.badges.where((b) => b.unlocked).length} dari ${stats.badges.length} Terbuka',
                        style: context.qSmall(12),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.s),
                  ...stats.badges.map((badge) => _BadgeTile(badge: badge)),
                  const SizedBox(height: Spacing.m),
                ],

                // 5. Jejak Disiplin Bulan Ini
                if (summary?.disciplineMonth != null && summary!.disciplineMonth.isNotEmpty) ...[
                  Text(
                    'Bulan Ini (${idMonthsShort[DateTime.now().month - 1]})',
                    style: context.qTitle(15),
                  ),
                  const SizedBox(height: Spacing.s),
                  Container(
                    padding: const EdgeInsets.all(Spacing.m),
                    decoration: BoxDecoration(
                      color: context.q.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: context.q.line),
                      boxShadow: AppShadows.card,
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: summary.disciplineMonth.map((d) {
                        Color dotColor;
                        if (d.future) {
                          dotColor = context.q.surface2;
                        } else if (d.within) {
                          dotColor = context.q.good;
                        } else {
                          dotColor = context.q.bad;
                        }
                        return Tooltip(
                          message: 'Tgl ${d.day.day}: ${d.future ? "Belum lewat" : d.within ? "Aman" : "Lewat batas"}',
                          child: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: dotColor.withValues(alpha: d.future ? 0.5 : 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: dotColor.withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${d.day.day}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: d.future ? context.q.muted : dotColor,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: Spacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final SaverBadge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.m, vertical: Spacing.s),
      decoration: BoxDecoration(
        color: context.q.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(
          color: badge.unlocked ? const Color(0xFFFDE68A) : context.q.line,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: badge.unlocked
                  ? const Color(0xFFFEF3C7)
                  : context.q.surface2,
              borderRadius: BorderRadius.circular(AppRadius.cell),
            ),
            child: Icon(
              badge.icon,
              color: badge.unlocked ? const Color(0xFFD97706) : context.q.muted,
              size: 22,
            ),
          ),
          const SizedBox(width: Spacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: badge.unlocked ? context.q.text : context.q.muted,
                  ),
                ),
                Text(
                  badge.description,
                  style: context.qSmall(11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badge.unlocked
                  ? SeedColors.incomingTint
                  : context.q.surface2,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              badge.unlocked ? 'Terbuka' : 'Terkunci',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: badge.unlocked ? context.q.good : context.q.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
