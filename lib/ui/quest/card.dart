part of '../quest.dart';

enum QuestCardVariant { card, hero, flat }

/// Kartu standar Design System dengan 3 varian peran:
/// - `card`: kartu konten standar (radius 20, hairline border, shadow halus).
/// - `hero`: kartu utama/sorotan (radius 24, padding lebih lega, shadow elevated).
/// - `flat`: kartu ringkas/strip (warna surface2 lembut, hairline border, tanpa shadow).
class QuestCard extends StatelessWidget {
  const QuestCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.radius,
    this.variant = QuestCardVariant.card,
    this.color,
    this.border,
    this.shadow,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double? radius;
  final QuestCardVariant variant;
  final Color? color;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final Color effectiveColor = color ??
        switch (variant) {
          QuestCardVariant.card => q.surface,
          QuestCardVariant.hero => q.surface,
          QuestCardVariant.flat => q.surface2.withValues(alpha: 0.5),
        };

    final double effectiveRadius = radius ??
        switch (variant) {
          QuestCardVariant.card => AppRadius.card,
          QuestCardVariant.hero => AppRadius.sheet,
          QuestCardVariant.flat => AppRadius.tile,
        };

    final EdgeInsetsGeometry effectivePadding = padding ??
        switch (variant) {
          QuestCardVariant.card => const EdgeInsets.all(Spacing.m),
          QuestCardVariant.hero => const EdgeInsets.all(Spacing.m + Spacing.xs),
          QuestCardVariant.flat => const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        };

    final List<BoxShadow>? effectiveShadow = shadow ??
        switch (variant) {
          QuestCardVariant.card => AppShadows.card,
          QuestCardVariant.hero => AppShadows.elevated,
          QuestCardVariant.flat => null,
        };

    final BoxBorder effectiveBorder = border ?? Border.all(color: q.line, width: 1);

    final card = Container(
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: effectiveBorder,
        boxShadow: effectiveShadow,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return QuestPress(onTap: onTap, child: card);
  }
}

/// Chip pilihan ala tombol game.

class QuestChip extends StatelessWidget {
  const QuestChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: QuestPress(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: QuestMotion.fast,
          curve: QuestMotion.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? q.primary : q.surface2,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: AnimatedDefaultTextStyle(
            duration: QuestMotion.fast,
            curve: QuestMotion.easeOut,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: selected ? Colors.white : q.text,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

/// Badge status pil kecil untuk status koneksi, kategori, atau filter.

class QuestStatusBadge extends StatelessWidget {
  const QuestStatusBadge({
    super.key,
    required this.label,
    this.color,
    this.bgColor,
    this.dotColor,
  });

  final String label;
  final Color? color;
  final Color? bgColor;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final effectiveColor = color ?? q.muted;
    final effectiveBg = bgColor ?? q.surface2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loading berbentuk tile berbingkai dengan kilau shimmer
/// menyapu — dipakai semua stream pertama agar layar tidak berkedip
/// kosong. Hanya untuk data yang belum ada; hormati reduced motion.

class QuestSkeleton extends StatefulWidget {
  const QuestSkeleton({super.key, this.rows = 3, this.height = 70});

  final int rows;
  final double height;

  @override
  State<QuestSkeleton> createState() => _QuestSkeletonState();
}

class _QuestSkeletonState extends State<QuestSkeleton>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    Widget box(Widget? sweep) => Container(
      height: widget.height,
      margin: const EdgeInsets.only(bottom: Spacing.s),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: q.surface2,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: sweep,
    );
    // Reduced motion: kotak diam seperti sebelumnya.
    if (MediaQuery.disableAnimationsOf(context)) {
      return Column(
        children: [for (var i = 0; i < widget.rows; i++) box(null)],
      );
    }
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, _) => Column(
        children: [
          for (var i = 0; i < widget.rows; i++)
            box(
              FractionalTranslation(
                // Baris menyusul berurutan, bukan serentak.
                translation: Offset(
                  2 * ((_sweep.value - i * 0.12) % 1.0) - 1,
                  0,
                ),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        q.surface2.withValues(alpha: 0),
                        q.surface.withValues(alpha: 0.85),
                        q.surface2.withValues(alpha: 0),
                      ],
                      stops: const [0.35, 0.5, 0.65],
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
