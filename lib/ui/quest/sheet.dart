part of '../quest.dart';

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
