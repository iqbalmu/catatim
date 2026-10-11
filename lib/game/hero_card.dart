import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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

/// Zona putih kompak: Duit 52 + sisa aman + pill streak.
class _HeroCompact extends StatelessWidget {
  const _HeroCompact({required this.progress});

  final ProgressSummary? progress;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final p = progress;
    final pace = p?.dailyPace;
    final safe = pace?.safeToSpend;
    final over = safe != null && safe < 0;

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
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('SISA AMAN',
                            style: context
                                .qEyebrow()
                                .copyWith(color: q.honeyInk)),
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
                  _SquareFill(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child:
                          RepaintBoundary(child: Mascot(mood: p.mood, size: 96)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Kotak persegi yang mengisi tinggi layout, tapi melaporkan tinggi
/// intrinsik nol — agar tinggi baris hanya ditentukan oleh teks, bukan
/// oleh maskot. (AspectRatio melaporkan intrinsik dari child-nya sehingga
/// IntrinsicHeight mengukur baris dari maskot, bukan dari teks.)
class _SquareFill extends SingleChildRenderObjectWidget {
  const _SquareFill({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSquareFill();
}

class _RenderSquareFill extends RenderProxyBox {
  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  void performLayout() {
    if (constraints.hasBoundedHeight) {
      final h = constraints.maxHeight;
      child!.layout(BoxConstraints.tight(Size(h, h)), parentUsesSize: true);
      size = Size(h, h);
    } else {
      super.performLayout();
    }
  }
}

