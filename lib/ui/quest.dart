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
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedScale(
            scale: _down ? widget.scale : 1,
            duration: QuestMotion.fast,
            curve: QuestMotion.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Kartu lembut: permukaan putih + bayangan halo, tanpa border.
class QuestCard extends StatelessWidget {
  const QuestCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.m),
    this.onTap,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.q.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: context.q.shadow,
            offset: const Offset(0, 6),
            blurRadius: 18,
          ),
        ],
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
    switch (tone) {
      case QuestTone.primary:
        fill = Colors.transparent; // gradient di decoration.
        fg = Colors.white;
      case QuestTone.secondary:
        fill = q.surface2;
        fg = q.text;
      case QuestTone.danger:
        fill = q.bad;
        fg = Colors.white;
      case QuestTone.ghost:
        fill = Colors.transparent;
        fg = q.text;
    }
    final button = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: tone == QuestTone.primary ? null : fill,
        gradient: tone == QuestTone.primary
            ? const LinearGradient(
                colors: [Color(0xFFFFC94D), Color(0xFFFFA726)],
              )
            : null,
        borderRadius: BorderRadius.circular(999),
        boxShadow: tone == QuestTone.primary
            ? const [
                BoxShadow(
                  color: Color(0x73FFA726),
                  offset: Offset(0, 8),
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: Spacing.s),
          ],
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 0.2,
              color: fg,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? q.honey : q.surface2,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x59FFB33E),
                      offset: Offset(0, 6),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: selected ? q.honeyInk : q.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Kontrol segmen custom (pengganti SegmentedButton): baris chip dalam bingkai.
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.q.surface2,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: _SegmentCell<T>(
                option: o,
                selected: o.value == selected,
                onTap: () => onChanged(o.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentCell<T> extends StatelessWidget {
  const _SegmentCell({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ({T value, String label, IconData? icon}) option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: QuestMotion.fast,
        curve: QuestMotion.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? q.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (option.icon != null) ...[
              Icon(
                option.icon,
                size: 18,
                color: selected ? q.honeyInk : q.muted,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                option.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? q.honeyInk : q.muted,
                ),
              ),
            ),
          ],
        ),
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
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.s,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showBack) ...[
              QuestIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Kembali',
                onPressed: () => Navigator.maybePop(context),
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
                  Text(title, style: context.qTitle(24)),
                  if (subtitle != null)
                    Text(subtitle!, style: context.qSmall()),
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: q.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: q.shadow, offset: const Offset(0, 4), blurRadius: 12),
        ],
      ),
      child: Icon(icon, color: q.text, size: 22),
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
  final ({String tooltip, VoidCallback onTap})? centerAction;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(Spacing.m, 0, Spacing.m, Spacing.m),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: q.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: q.shadow,
              offset: const Offset(0, 10),
              blurRadius: 26,
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++) ...[
              if (centerAction != null && i == destinations.length ~/ 2)
                _centerButton(context),
              _navCell(context, i, destinations[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _navCell(BuildContext context, int i, QuestDestination dest) {
    final q = context.q;
    final selected = i == index;
    return Expanded(
      child: QuestPress(
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: QuestMotion.fast,
          curve: QuestMotion.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? q.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badges.contains(i),
                backgroundColor: q.bad,
                smallSize: 10,
                child: Icon(
                  dest.icon,
                  size: 22,
                  color: selected ? q.text : q.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dest.label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  color: selected ? q.text : q.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tombol + bundar di tengah nav — ikon saja, label jadi tooltip.
  Widget _centerButton(BuildContext context) {
    final action = centerAction!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: action.tooltip,
        child: QuestPress(
          onTap: action.onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFC94D), Color(0xFFFFA726)],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x73FFA726),
                  offset: Offset(0, 6),
                  blurRadius: 14,
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

/// Pil aksi melayang — dipakai tiap tab sebagai
/// `Scaffold.floatingActionButton` (dengan `Padding` bawah agar melayang di
/// atas navbar floating, bukan tertutup).
class QuestFab extends StatelessWidget {
  const QuestFab({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QuestPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFC94D), Color(0xFFFFA726)],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x73FFA726),
              offset: Offset(0, 8),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
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
    return Text(
      '${incoming ? '+' : '−'} ${Money.format(amount)}',
      style: context.qAmount(size, incoming: incoming),
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
        borderRadius: BorderRadius.circular(999),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
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
                color: color ?? q.honey,
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
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? q.honey : q.surface2,
            borderRadius: BorderRadius.circular(999),
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
        width: 48,
        height: 6,
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        decoration: BoxDecoration(
          color: context.q.muted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
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
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const QuestGrabber(),
        Flexible(child: builder(context)),
      ],
    ),
  );
}

Future<T?> showQuestDialog<T>(
  BuildContext context, {
  required String title,
  required Widget content,
  required List<Widget> actions,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(Spacing.l),
      backgroundColor: Colors.transparent,
      child: QuestCard(
        radius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: context.qTitle(19)),
            const SizedBox(height: Spacing.s),
            content,
            const SizedBox(height: Spacing.m),
            Wrap(spacing: Spacing.s, runSpacing: Spacing.s, children: actions),
          ],
        ),
      ),
    ),
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

/// Skeleton loading berbentuk tile berbingkai — dipakai semua stream
/// pertama agar layar tidak berkedip kosong.
class QuestSkeleton extends StatelessWidget {
  const QuestSkeleton({super.key, this.rows = 3, this.height = 70});

  final int rows;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++)
          Container(
            height: height,
            margin: const EdgeInsets.only(bottom: Spacing.s),
            decoration: BoxDecoration(
              color: context.q.surface2,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
      ],
    );
  }
}
