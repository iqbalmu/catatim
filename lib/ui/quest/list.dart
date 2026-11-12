part of '../quest.dart';

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
          if (leading != null) ...[leading!, const SizedBox(width: Spacing.m)],
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
      child: QuestMoney(
        amount: amount,
        tone: incoming ? MoneyTone.incoming : MoneyTone.outgoing,
        alignment: Alignment.centerRight,
        style: context.qAmount(size, incoming: incoming),
      ),
    );
  }
}

/// Bar progres berbingkai; tumbuh mulus dari 0 ke nilai akhir saat tampil
/// maupun saat nilai berubah, selaras dengan [QuestProgressBar].

class QuestBar extends StatelessWidget {
  const QuestBar({
    super.key,
    required this.value,
    this.height = 12,
    this.color,
    this.replayKey,
  });

  final double value;
  final double height;
  final Color? color;
  final Object? replayKey;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestProgressBar(
      value: value,
      minHeight: height,
      color: color ?? q.primary,
      backgroundColor: q.surface2,
      replayKey: replayKey,
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
