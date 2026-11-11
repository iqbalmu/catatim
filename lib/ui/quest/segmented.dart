part of '../quest.dart';

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
                      boxShadow: context.q.cardShadow,
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
                  child: Semantics(
                    selected: i == selectedIndex,
                    button: true,
                    label: options[i].label,
                    child: QuestPress(
                      onTap: () => onChanged(options[i].value),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
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
                ),
            ],
          ),
        ],
      ),
    );
  }
}
