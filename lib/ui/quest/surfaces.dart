part of '../quest.dart';

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
    this.textScale = 1.0,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final Widget? leading;
  final List<Widget> actions;

  /// Judul kecil tanpa tanggal — dipakai di Beranda yang puncaknya
  /// dipakai panggung Duit, jadi bagian atas harus lapang.
  final bool compact;

  /// Faktor skala teks (`MediaQuery.textScalerOf(context).scale(1.0)`);
  /// tinggi AppBar mengikuti agar judul+subjudul tak overflow pada
  /// font scale besar (temuan device 1,3×: overflow 8px).
  final double textScale;

  @override
  Size get preferredSize =>
      Size.fromHeight(68 * textScale.clamp(1.0, 2.0));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          // Header memiliki jarak appbar → konten (16dp); body mulai dari 0.
          Spacing.m,
        ),
        child: QuestTabEnter(
          index: 0,
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
                    boxShadow: context.q.cardShadow,
                  ),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: context.q.text,
                      size: 20,
                    ),
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
                          ? context
                                .qSmall(13)
                                .copyWith(
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
