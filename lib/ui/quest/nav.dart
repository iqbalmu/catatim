part of '../quest.dart';

/// Satu destinasi bottom nav.

class QuestDestination {
  const QuestDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Bottom nav custom chunky dengan destinasi dinamis.

class QuestBottomNav extends StatelessWidget {
  const QuestBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.destinations,
    this.badges = const <int>{},
    this.centerAction,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<QuestDestination> destinations;

  /// Indeks destinasi yang menampilkan titik badge (mis. Bon tua >30 hari).
  final Set<int> badges;

  /// Tombol + di tengah nav, dinamis per tab (label + aksi ikut konteks).
  /// Null = tanpa tombol tengah.
  final ({String tooltip, VoidCallback onTap, IconData? icon})? centerAction;

  @override
  Widget build(BuildContext context) {
    final count = destinations.length;
    final hasCenter = centerAction != null;
    final half = count ~/ 2;
    final activeIndex = index.clamp(0, count > 0 ? count - 1 : 0);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(Spacing.m, 0, Spacing.m, Spacing.m),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final gap = hasCenter ? 74.0 : 0.0;
                final innerWidth = constraints.maxWidth - 8.0;
                final itemWidth = count > 0 ? (innerWidth - gap) / count : 0.0;
                final targetLeft = (activeIndex < half || !hasCenter)
                    ? (activeIndex * itemWidth)
                    : (activeIndex * itemWidth) + gap;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.q.surface,
                    borderRadius: BorderRadius.circular(AppRadius.nav),
                    border: Border.all(color: context.q.line, width: 1),
                    boxShadow: AppShadows.elevated,
                  ),
                  child: Stack(
                    children: [
                      // Sliding indicator pill
                      if (count > 0)
                        AnimatedPositioned(
                          duration: QuestMotion.medium,
                          curve: QuestMotion.easeOut,
                          left: targetLeft,
                          top: 0,
                          bottom: 0,
                          width: itemWidth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Container(
                              decoration: BoxDecoration(
                                color: SeedColors.primaryLight,
                                borderRadius: BorderRadius.circular(AppRadius.tile),
                              ),
                            ),
                          ),
                        ),
                      // Destination items on top
                      Row(
                        children: [
                          for (var i = 0; i < destinations.length; i++) ...[
                            if (hasCenter && i == half)
                              const SizedBox(width: 74),
                            _navCell(context, i, destinations[i]),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            if (centerAction != null)
              Positioned(
                top: -18,
                left: 0,
                right: 0,
                child: Center(child: _centerButton(context)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _navCell(BuildContext context, int i, QuestDestination dest) {
    final selected = i == index;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: QuestPress(
          onTap: () => onChanged(i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSlide(
                  duration: QuestMotion.medium,
                  curve: QuestMotion.spring,
                  offset: selected ? const Offset(0, -0.08) : Offset.zero,
                  child: AnimatedScale(
                    duration: QuestMotion.medium,
                    curve: QuestMotion.spring,
                    scale: selected ? 1.1 : 1.0,
                    child: Badge(
                      isLabelVisible: badges.contains(i),
                      backgroundColor: context.q.bad,
                      smallSize: 8,
                      child: Icon(
                        dest.icon,
                        size: 21,
                        color: selected
                            ? context.q.primary
                            : context.q.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: QuestMotion.fast,
                  curve: QuestMotion.easeOut,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 10.5,
                    color: selected
                        ? context.q.primary
                        : context.q.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: Text(dest.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tombol + bundar di tengah nav — menonjol 20px ke atas navbar
  Widget _centerButton(BuildContext context) {
    final action = centerAction!;
    return Tooltip(
      message: action.tooltip,
      child: QuestPress(
        onTap: action.onTap,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [context.q.primary, context.q.primaryDeep],
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: const [
              BoxShadow(
                color: Color(0x408B5CF6),
                offset: Offset(0, 6),
                blurRadius: 16,
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: QuestMotion.medium,
            switchInCurve: QuestMotion.spring,
            switchOutCurve: QuestMotion.easeOut,
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              action.icon ?? Icons.add_rounded,
              key: ValueKey(action.icon ?? Icons.add_rounded),
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}
