part of '../quest.dart';

Future<T?> showQuestSheet<T>(
  BuildContext context,
  Widget Function(BuildContext context) builder,
) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: const AnimationStyle(
      duration: QuestMotion.sheet,
      reverseDuration: QuestMotion.medium,
      curve: QuestMotion.drawer,
      reverseCurve: QuestMotion.easeOut,
    ),
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: context.q.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        boxShadow: context.q.elevatedShadow,
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
    sheetAnimationStyle: const AnimationStyle(
      duration: QuestMotion.sheet,
      reverseDuration: QuestMotion.medium,
      curve: QuestMotion.drawer,
      reverseCurve: QuestMotion.easeOut,
    ),
    builder: (context) {
      final q = context.q;
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: q.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
            boxShadow: q.elevatedShadow,
          ),
          child: SafeArea(
            top: false,
            bottom: bottomInset == 0,
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
                Divider(
                  height: 1,
                  thickness: 1,
                  color: q.line.withValues(alpha: 0.5),
                ),
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
                                for (
                                  var i = 0;
                                  i < actions.length - 1;
                                  i++
                                ) ...[
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
