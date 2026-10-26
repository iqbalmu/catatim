import 'package:flutter/material.dart';

import '../core/money.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';

/// Komponen visual khas Bukuduit Quest: kartu papan-peraga, tombol chunky,
/// chip game, header custom, nav custom. Satu-satunya tempat gaya visual
/// didefinisikan agar tidak ada default Material yang bocor.

/// Pembungkus tekan dengan umpan-balik skala khas game.
class QuestPress extends StatefulWidget {
  const QuestPress({
    super.key,
    required this.onTap,
    required this.child,
    this.scale = QuestMotion.pressScale,
    this.onLongPress,
  });

  final VoidCallback? onTap;
  final Widget child;
  final double scale;
  final VoidCallback? onLongPress;

  @override
  State<QuestPress> createState() => _QuestPressState();
}

class _QuestPressState extends State<QuestPress> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: Semantics(
        container: true,
        button: widget.onTap != null,
        child: GestureDetector(
          // Opaque: seluruh area parent termasuk padding kosong ikut
          // bisa ditap — bukan hanya piksel teks/ikon yang tergambar.
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedScale(
            scale: _down ? widget.scale : 1,
            duration: QuestMotion.fast,
            // Spring kenyal (ADR-010) — konsisten bob maskot.
            curve: QuestMotion.spring,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

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
enum QuestTone { primary, secondary, danger, ghost }

/// Tombol chunky khas game: isi penuh + border tinta + offset shadow yang
/// "tenggelam" saat ditekan.
class QuestButton extends StatelessWidget {
  const QuestButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = QuestTone.primary,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final QuestTone tone;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final Color fill;
    final Color fg;
    final BoxBorder? border;
    final List<BoxShadow>? shadow;
    final Gradient? gradient;

    switch (tone) {
      case QuestTone.primary:
        fill = Colors.transparent;
        fg = Colors.white;
        border = null;
        gradient = LinearGradient(colors: [q.primary, q.primaryDeep]);
        shadow = [
          BoxShadow(
            color: q.primary.withValues(alpha: 0.28),
            offset: const Offset(0, 4),
            blurRadius: 14,
          ),
        ];
      case QuestTone.secondary:
        fill = q.surface;
        fg = q.text;
        border = Border.all(color: q.line);
        gradient = null;
        shadow = AppShadows.card;
      case QuestTone.danger:
        fill = q.bad;
        fg = Colors.white;
        border = null;
        gradient = null;
        shadow = [
          BoxShadow(
            color: q.bad.withValues(alpha: 0.25),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ];
      case QuestTone.ghost:
        fill = Colors.transparent;
        fg = q.text;
        border = null;
        gradient = null;
        shadow = null;
    }
    final button = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: gradient == null ? fill : null,
        gradient: gradient,
        border: border,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: shadow,
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: Spacing.xs),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.1,
                  color: fg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    // Tanpa Opacity saat enabled: saveLayer + blur shadow besar di Impeller
    // bisa membilas isi layer hingga tombol tampak pucat.
    final wrapped =
        onPressed == null ? Opacity(opacity: 0.45, child: button) : button;
    return QuestPress(onTap: onPressed, child: wrapped);
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? q.primary : q.surface2,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: selected ? Colors.white : q.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// Kontrol segmen custom: baris chip dalam bingkai dengan thumb indikator
/// yang bergeser secara halus (smooth sliding) mengikuti tab aktif.
class QuestSegmented<T> extends StatelessWidget {
  const QuestSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<({T value, String label, IconData? icon})> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = options.indexWhere((o) => o.value == selected);
    final count = options.length;
    final alignX = count > 1 && selectedIndex >= 0
        ? -1.0 + (selectedIndex * (2.0 / (count - 1)))
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.q.surface2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Sliding indicator thumb
          if (count > 0 && selectedIndex >= 0)
            Positioned.fill(
              child: AnimatedAlign(
                alignment: Alignment(alignX, 0),
                duration: QuestMotion.medium,
                curve: QuestMotion.easeOut,
                child: FractionallySizedBox(
                  widthFactor: 1.0 / count,
                  heightFactor: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.q.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppShadows.card,
                    ),
                  ),
                ),
              ),
            ),
          // Option labels on top
          Row(
            children: [
              for (var i = 0; i < options.length; i++)
                Expanded(
                  child: QuestPress(
                    onTap: () => onChanged(options[i].value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (options[i].icon != null) ...[
                            Icon(
                              options[i].icon,
                              size: 16,
                              color: i == selectedIndex
                                  ? context.q.primary
                                  : context.q.muted,
                            ),
                            const SizedBox(width: Spacing.xs),
                          ],
                          Flexible(
                            child: AnimatedDefaultTextStyle(
                              duration: QuestMotion.fast,
                              curve: QuestMotion.easeOut,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 12.5,
                                fontWeight: i == selectedIndex
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: i == selectedIndex
                                    ? context.q.text
                                    : context.q.muted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              child: Text(options[i].label),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Header layar custom pengganti AppBar default.
class QuestHeader extends StatelessWidget implements PreferredSizeWidget {
  const QuestHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.leading,
    this.actions = const [],
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final Widget? leading;
  final List<Widget> actions;

  /// Judul kecil tanpa tanggal — dipakai di Beranda yang puncaknya
  /// dipakai panggung Duit, jadi bagian atas harus lapang.
  final bool compact;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showBack) ...[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.q.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.q.line),
                  boxShadow: AppShadows.card,
                ),
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.arrow_back_rounded, color: context.q.text, size: 20),
                  tooltip: 'Kembali',
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
              const SizedBox(width: Spacing.s),
            ],
            if (leading != null) ...[
              leading!,
              const SizedBox(width: Spacing.s),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: compact
                        ? context.qSmall(13).copyWith(
                            color: context.q.muted,
                            fontWeight: FontWeight.w800,
                          )
                        : context.qTitle(20),
                  ),
                  if (!compact && subtitle != null)
                    Text(subtitle!, style: context.qSmall(12)),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Tombol ikon lingkaran berbingkai, pengganti IconButton polos.
class QuestIconButton extends StatelessWidget {
  const QuestIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final button = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: q.surface,
        shape: BoxShape.circle,
        border: Border.all(color: q.line),
        boxShadow: AppShadows.card,
      ),
      child: Icon(icon, color: q.text, size: 20),
    );
    return Tooltip(
      message: tooltip ?? '',
      child: QuestPress(
        onTap: onPressed,
        child: Badge(
          isLabelVisible: badge,
          backgroundColor: q.bad,
          smallSize: 12,
          child: button,
        ),
      ),
    );
  }
}

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
                Badge(
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
          child: Icon(
            action.icon ?? Icons.add_rounded,
            color: Colors.white,
            size: 30,
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

/// Baris item daftar seragam: leading avatar/icon + title + subtitle + trailing + onTap.
class QuestListTile extends StatelessWidget {
  const QuestListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.padding = Insets.tile,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: Spacing.m),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                if (subtitle != null) ...[
                  const SizedBox(height: Spacing.xxs),
                  subtitle!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Spacing.s),
            trailing!,
          ] else if (onTap != null) ...[
            const SizedBox(width: Spacing.s),
            Icon(Icons.chevron_right_rounded, color: q.muted, size: 20),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return QuestPress(onTap: onTap, child: row);
  }
}

/// Judul seksi: eyebrow caps + garis.
class QuestSectionHeader extends StatelessWidget {
  const QuestSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.m, bottom: Spacing.s),
      child: Row(
        children: [
          Expanded(child: Text(title.toUpperCase(), style: context.qEyebrow())),
          ?trailing,
        ],
      ),
    );
  }
}

/// Nominal dengan tanda +/− dan warna arah, tabular.
class QuestAmount extends StatelessWidget {
  const QuestAmount({
    super.key,
    required this.amount,
    required this.incoming,
    this.size = 16,
  });

  final int amount;
  final bool incoming;
  final double size;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '${incoming ? '+' : '−'}${Money.format(amount)}',
        style: context.qAmount(size, incoming: incoming),
      ),
    );
  }
}

/// Bar progres berbingkai; isi madu default, warna opsional.
class QuestBar extends StatelessWidget {
  const QuestBar({super.key, required this.value, this.height = 12, this.color});

  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: q.surface2,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth * value.clamp(0.0, 1.0);
            if (w <= 1) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: QuestMotion.medium,
                curve: QuestMotion.easeOut,
                width: w,
                height: double.infinity,
                color: color ?? q.primary,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Toggle custom pengganti Switch default.
class QuestSwitch extends StatelessWidget {
  const QuestSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Semantics(
      toggled: value,
      label: label,
      child: QuestPress(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: QuestMotion.fast,
          curve: QuestMotion.easeOut,
          width: 56,
          height: 32,
          padding: const EdgeInsets.all(Spacing.xs),
          decoration: BoxDecoration(
            color: value ? q.primary : q.surface2,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: AnimatedAlign(
            duration: QuestMotion.fast,
            curve: QuestMotion.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0x1F000000), blurRadius: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Status kosong yang ramah + ajakan bertindak.
class QuestEmpty extends StatelessWidget {
  const QuestEmpty({
    super.key,
    required this.title,
    required this.hint,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
      child: Column(
        children: [
          Text(title, style: context.qTitle()),
          const SizedBox(height: Spacing.xs),
          Text(hint, style: context.qSmall(), textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Spacing.m),
            QuestButton(
              label: actionLabel!,
              icon: Icons.add_rounded,
              onPressed: onAction,
              expanded: false,
            ),
          ],
        ],
      ),
    );
  }
}

/// Gagang sheet khas bottom sheet custom.
class QuestGrabber extends StatelessWidget {
  const QuestGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: Spacing.s, bottom: Spacing.xs),
        decoration: BoxDecoration(
          color: context.q.muted.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}

Future<T?> showQuestSheet<T>(
  BuildContext context,
  Widget Function(BuildContext context) builder,
) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: context.q.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        boxShadow: AppShadows.elevated,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: Spacing.s),
          const QuestGrabber(),
          Flexible(child: builder(context)),
        ],
      ),
    ),
  );
}

/// Drawer modal tunggal untuk seluruh dialog/konfirmasi/input di aplikasi.
/// Menggantikan dialog mengambang di tengah layar dengan laci geser dari bawah.
Future<T?> showQuestDialog<T>(
  BuildContext context, {
  required String title,
  required Widget content,
  required List<Widget> actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final q = context.q;
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: q.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
            boxShadow: AppShadows.elevated,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Spacing.s),
              const QuestGrabber(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.l,
                  Spacing.s,
                  Spacing.l,
                  Spacing.xs,
                ),
                child: Text(title, style: context.qTitle(18)),
              ),
              Divider(height: 1, thickness: 1, color: q.line),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.l,
                    Spacing.m,
                    Spacing.l,
                    Spacing.s,
                  ),
                  child: content,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.l,
                  Spacing.s,
                  Spacing.l,
                  Spacing.m,
                ),
                child: actions.length <= 2
                    ? Row(
                        children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(width: Spacing.s),
                            Expanded(child: actions[i]),
                          ],
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          actions.last,
                          const SizedBox(height: Spacing.s),
                          Row(
                            children: [
                              for (var i = 0; i < actions.length - 1; i++) ...[
                                if (i > 0) const SizedBox(width: Spacing.s),
                                Expanded(child: actions[i]),
                              ],
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void questSnack(BuildContext context, String message, {IconData? icon}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: context.q.bg, size: 20),
            const SizedBox(width: Spacing.s),
          ],
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
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
