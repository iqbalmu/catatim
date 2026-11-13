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
    final hasCenter = centerAction != null;
    final half = destinations.length ~/ 2;
    final hasBottomInset = MediaQuery.paddingOf(context).bottom > 0;

    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(
          Spacing.m,
          0,
          Spacing.m,
          hasBottomInset ? Spacing.xs : Spacing.s,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: context.q.surface,
                borderRadius: BorderRadius.circular(AppRadius.nav),
                border: Border.all(color: context.q.line, width: 1),
                boxShadow: context.q.elevatedShadow,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++) ...[
                    if (hasCenter && i == half) const SizedBox(width: 74),
                    _navCell(context, i, destinations[i]),
                  ],
                ],
              ),
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
        child: Semantics(
          selected: selected,
          button: true,
          label: badges.contains(i)
              ? '${dest.label}, ada item perlu perhatian'
              : dest.label,
          child: QuestPress(
            onTap: () => onChanged(i),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
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
                          color: selected ? context.q.primaryText : context.q.muted,
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
                      color: selected ? context.q.primaryText : context.q.muted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    child: Text(dest.label),
                  ),
                ],
              ),
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
              colors: [context.q.primarySolid, context.q.primaryGradientEnd],
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: const [
              BoxShadow(
                color: Color(0x401F5A53),
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
              color: context.q.onPrimary,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}
