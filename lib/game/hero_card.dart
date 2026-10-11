import 'package:flutter/material.dart';

import '../core/money.dart';
import '../game/mascot.dart';
import '../game/progress.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';

/// Hero beranda kompak gaya dashboard: Duit + sisa aman + streak.
class GameHeroCard extends StatelessWidget {
  const GameHeroCard({super.key, required this.service});

  final ProgressService service;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) => _HeroCompact(progress: service.latest),
    );
  }
}

/// Zona madu: teks kiri + Duit kanan dengan tinggi yang SAMA PERSIS.
///
/// Tinggi teks (angka FittedBox menyusut ikut panjang nominal) hanya bisa
/// diketahui setelah layout — jadi diukur sekali per frame via GlobalKey,
/// lalu box maskot disamakan. Yang diukur adalah hasil render nyata, bukan
/// teori intrinsik.
class _HeroCompact extends StatefulWidget {
  const _HeroCompact({required this.progress});

  final ProgressSummary? progress;

  @override
  State<_HeroCompact> createState() => _HeroCompactState();
}

class _HeroCompactState extends State<_HeroCompact> {
  final _textKey = GlobalKey();
  double? _textH;

  void _syncHeight() {
    if (!mounted) return;
    final box = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final h = box.size.height;
    if (_textH == null || (h - _textH!).abs() > 0.5) {
      setState(() => _textH = h);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final p = widget.progress;
    final pace = p?.dailyPace;
    final safe = pace?.safeToSpend;
    final over = safe != null && safe < 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncHeight());
    final petH = _textH ?? 84.0;

    return Container(
      padding: const EdgeInsets.all(Spacing.l),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SeedColors.honeyBright, SeedColors.honey],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: p == null || pace == null
          ? const SizedBox(height: 96)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    key: _textKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('SISA AMAN',
                          style:
                              context.qEyebrow().copyWith(color: q.honeyInk)),
                      const SizedBox(height: 2),
                      if (safe == null)
                        Text(
                          'Tanpa batas',
                          style: context.qTitle(18).copyWith(color: q.muted),
                        )
                      else
                        FittedBox(
                          child: Text(
                            Money.format(safe),
                            style: context.qDisplay(34)
                                .copyWith(color: over ? q.bad : q.text),
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        'tgl ${pace.dayOfMonth} · '
                        'ideal ${pace.idealUsedPercent}%',
                        style: context.qSmall().copyWith(color: q.honeyInk),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.s),
                SizedBox(
                  width: petH,
                  height: petH,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child:
                        RepaintBoundary(child: Mascot(mood: p.mood, size: 96)),
                  ),
                ),
              ],
            ),
    );
  }
}
