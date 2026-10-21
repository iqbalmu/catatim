import 'package:flutter/material.dart';

import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'mascot.dart';
import 'progress.dart';

/// Panggung Duit: ruang hangat di paling atas Beranda, Duit berdiri di
/// tengah, kalimatnya di bawah karakter.
///
/// Karakter jadi wajah aplikasi; semua komponen lain (kartu uang, arus,
/// insight, transaksi) menyusul rapi di bawahnya — mockup L1.
class DuitStage extends StatelessWidget {
  const DuitStage({super.key, required this.service});

  final ProgressService service;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final summary = service.latest;
        final mood = summary?.mood ?? MascotMood.idle;
        return Container(
          padding: const EdgeInsets.fromLTRB(
            Spacing.m,
            Spacing.s,
            Spacing.m,
            Spacing.l,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sheet),
            // Cahaya hangat yang memudar ke bawah — panggung tanpa kartu.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                SeedColors.honey50.withValues(alpha: 0.95),
                SeedColors.honey50.withValues(alpha: 0),
              ],
            ),
          ),
          child: Column(
            children: [
              RepaintBoundary(
                child: MascotStage(
                  mood: mood,
                  size: 172,
                  glow: SeedColors.honey100,
                  glowStrength: 0.55,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                summary?.moodCaption ??
                    'Duit tidur dulu — belum ada catatan bulan ini',
                textAlign: TextAlign.center,
                style: context.qSmall(12).copyWith(
                  color: context.q.honeyInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
