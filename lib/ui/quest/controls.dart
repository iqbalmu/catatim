part of '../quest.dart';

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
    final wrapped = onPressed == null
        ? Opacity(opacity: 0.45, child: button)
        : button;
    return QuestPress(onTap: onPressed, child: wrapped);
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
                boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 4)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
