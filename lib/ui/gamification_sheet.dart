import 'package:flutter/material.dart';

import '../core/dates_id.dart';
import '../game/mascot.dart';
import '../game/progress.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

class GamificationSheet extends StatelessWidget {
  const GamificationSheet({super.key, required this.progress});

  final ProgressService progress;

  static Future<void> show(BuildContext context, ProgressService progress) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: const AnimationStyle(
        duration: QuestMotion.sheet,
        reverseDuration: QuestMotion.medium,
        curve: QuestMotion.drawer,
        reverseCurve: QuestMotion.easeOut,
      ),
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
        // Laci setinggi halaman: ladder bg → surface seperti Beranda,
        // bukan surface di atas surface (kartu hanya jadi outline).
        color: context.q.bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: Column(
        children: [
          const QuestGrabber(),

          // Header: satu baris tenang tanpa divider — konten langsung
          // memberi napas lewat spacing, bukan garis.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.m,
              Spacing.xs,
              Spacing.xs,
              Spacing.s,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pochy, Sahabat Hematmu', style: context.qTitle(16)),
                      Text(
                        'Nemenin kamu ngatur uang tiap hari',
                        style: context.qSmall(),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: context.q.muted),
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Spacing.m,
                Spacing.s,
                Spacing.m,
                Spacing.m,
              ),
              children: [
                // 1. Panggung Maskot & Mood + Streak — digabung satu baris
                // agar seluruh isi sheet muat tanpa scroll: maskot jangkar,
                // mood line pesan utama, streak jadi sub-barisnya.
                QuestEnter(
                  child: Row(
                    children: [
                      MascotStage(mood: mood, size: 88),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary?.moodLine ?? 'Pochy memantau keuanganmu',
                              style: context
                                  .qTitle(14.5)
                                  .copyWith(height: 1.25),
                            ),
                            const SizedBox(height: Spacing.xs),
                            Row(
                              children: [
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 16,
                                  color: context.q.warn,
                                ),
                                const SizedBox(width: Spacing.xs),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      text: isPaused
                                          ? 'Belum mulai'
                                          : '$streakDays hari berturut-turut',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: context.q.text,
                                      ),
                                      children: isPaused
                                          ? const []
                                          : [
                                              TextSpan(
                                                text: ' · batas aman',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: context.q.muted,
                                                ),
                                              ),
                                            ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.sm),

                // 3. Level & XP Saver Card
                if (stats != null) ...[
                  QuestEnter(
                    index: 2,
                    child: QuestCard(
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
                                          color: context.q.primarySolid,
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.pill,
                                          ),
                                        ),
                                        child: Text(
                                          'Level ${stats.level}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: context.q.onPrimary,
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
                              QuestCountUp(
                                value: stats.currentXp,
                                builder: (context, xp) => Text(
                                  '$xp dari ${stats.nextLevelXp} poin',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: context.q.primaryText,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Spacing.s),
                          QuestProgressBar(
                            value: stats.progress.clamp(0.0, 1.0),
                            color: context.q.primary,
                            backgroundColor: context.q.surface2,
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            'Catat & jaga batas harian, poinnya jalan sendiri.',
                            style: context.qSmall(11.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  // 4. Lencana Disiplin Section
                  QuestEnter(
                    index: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Lencanamu', style: context.qTitle(15)),
                        Text(
                          '${stats.badges.where((b) => b.unlocked).length} dari ${stats.badges.length} Terbuka',
                          style: context.qSmall(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.s),
                  // Grid 2 kolom: 4 lencana jadi 2 baris agar muat tanpa scroll.
                  for (var r = 0; r < (stats.badges.length / 2).ceil(); r++)
                    QuestEnter(
                      index: 4 + r,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _BadgeTile(badge: stats.badges[r * 2]),
                          ),
                          const SizedBox(width: Spacing.s),
                          Expanded(
                            child: r * 2 + 1 < stats.badges.length
                                ? _BadgeTile(badge: stats.badges[r * 2 + 1])
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: Spacing.sm),
                ],

                // 5. Jejak Disiplin Bulan Ini
                if (summary?.disciplineMonth != null &&
                    summary!.disciplineMonth.isNotEmpty) ...[
                  QuestEnter(
                    index: stats != null
                        ? 4 + (stats.badges.length / 2).ceil()
                        : 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Bulan Ini (${idMonthsShort[DateTime.now().month - 1]})',
                          style: context.qTitle(15),
                        ),
                        const SizedBox(height: Spacing.s),
                        QuestCard(
                          child: Wrap(
                            spacing: Spacing.xs,
                            runSpacing: Spacing.xs,
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
                                message:
                                    'Tgl ${d.day.day}: ${d.future
                                        ? "Belum lewat"
                                        : d.within
                                        ? "Aman"
                                        : "Lewat batas"}',
                                child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Center(
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: dotColor.withValues(
                                          alpha: d.future ? 0.5 : 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${d.day.day}',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: d.future
                                              ? context.q.muted
                                              : dotColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
    // Sel grid tanpa kotak: status hidup di tint lingkaran ikon
    // (emas = terbuka, abu = terkunci) seperti tile transaksi, bukan
    // outline + pil "Terbuka/Terkunci" di tiap baris.
    return Semantics(
      label: badge.unlocked ? 'Terbuka' : 'Terkunci',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.s),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: badge.unlocked
                    ? SeedColors.honey100
                    : context.q.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                badge.icon,
                color: badge.unlocked ? SeedColors.honeyDeep : context.q.muted,
                size: 18,
              ),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badge.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: badge.unlocked ? context.q.text : context.q.muted,
                    ),
                  ),
                  Text(
                    badge.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.qSmall(10.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
