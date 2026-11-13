part of '../quest.dart';

/// Opsi untuk [QuestSelectField].
class QuestSelectOption<T> {
  const QuestSelectOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.leading,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
}

/// Input field pemilih nilai dengan modal bottom sheet picker khas CatatIM.
///
/// Menggantikan [DropdownButtonFormField] bawaan Material yang kaku dengan
/// pemilih berbasis sheet yang ramah jempol, bersih, beranimasi halus, dan
/// selaras dengan sistem desain Petrol Teal CatatIM.
class QuestSelectField<T> extends StatelessWidget {
  const QuestSelectField({
    super.key,
    required this.labelText,
    required this.value,
    required this.options,
    required this.onChanged,
    this.sheetTitle,
    this.hintText,
    this.prefixIcon,
    this.onAdd,
    this.addLabel,
    this.enabled = true,
    this.showLabel = true,
  });

  final String labelText;
  final T? value;
  final List<QuestSelectOption<T>> options;
  final ValueChanged<T?> onChanged;
  final String? sheetTitle;
  final String? hintText;
  final Widget? prefixIcon;
  final VoidCallback? onAdd;
  final String? addLabel;
  final bool enabled;
  final bool showLabel;

  QuestSelectOption<T>? get _selectedOption {
    for (final opt in options) {
      if (opt.value == value) return opt;
    }
    return null;
  }

  Future<void> _openPicker(BuildContext context) async {
    if (!enabled) return;
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();

    final q = context.q;
    final picked = await showModalBottomSheet<({T value})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AnimationStyle(
        duration: QuestMotion.sheet,
        reverseDuration: QuestMotion.medium,
        curve: QuestMotion.drawer,
        reverseCurve: QuestMotion.easeOut,
      ),
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: q.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
            boxShadow: q.elevatedShadow,
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: Spacing.s),
                  const QuestGrabber(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.m,
                      Spacing.xs,
                      Spacing.s,
                      Spacing.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            sheetTitle ?? labelText,
                            style: sheetContext.qTitle(17),
                          ),
                        ),
                        QuestIconButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Tutup',
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: q.line.withValues(alpha: 0.6)),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.m,
                        Spacing.s,
                        Spacing.m,
                        Spacing.m,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final opt in options) ...[
                            _SelectOptionTile<T>(
                              option: opt,
                              selected: opt.value == value,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.pop(sheetContext, (value: opt.value));
                              },
                            ),
                            const SizedBox(height: 6),
                          ],
                          if (onAdd != null) ...[
                            const SizedBox(height: Spacing.xs),
                            QuestPress(
                              onTap: () {
                                Navigator.pop(sheetContext);
                                onAdd!();
                              },
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: q.surface2,
                                  borderRadius: BorderRadius.circular(AppRadius.tile),
                                  border: Border.all(
                                    color: q.line.withValues(alpha: 0.8),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                      color: q.primaryText,
                                    ),
                                    const SizedBox(width: Spacing.xs),
                                    Text(
                                      addLabel ?? 'Tambah Baru',
                                      style: TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: q.primaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (picked != null) {
      onChanged(picked.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final selected = _selectedOption;

    final fieldWidget = Semantics(
      button: true,
      enabled: enabled,
      label: '$labelText: ${selected?.label ?? hintText ?? 'Belum dipilih'}',
      child: QuestPress(
        onTap: enabled ? () => _openPicker(context) : null,
        child: InputDecorator(
          decoration: InputDecoration(
            prefixIcon: prefixIcon,
            suffixIcon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: enabled ? q.hint : q.muted.withValues(alpha: 0.4),
              size: 20,
            ),
          ),
          isEmpty: selected == null,
          child: Row(
            children: [
              if (prefixIcon == null && selected?.leading != null) ...[
                selected!.leading!,
                const SizedBox(width: 8),
              ] else if (prefixIcon == null && selected?.icon != null) ...[
                Icon(
                  selected!.icon,
                  size: 17,
                  color: enabled ? q.muted : q.muted.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  selected?.label ?? hintText ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: selected != null
                        ? (enabled ? q.text : q.muted)
                        : q.hint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (showLabel && labelText.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestFieldLabel(labelText),
          const SizedBox(height: Spacing.xs),
          fieldWidget,
        ],
      );
    }

    return fieldWidget;
  }
}

class _SelectOptionTile<T> extends StatelessWidget {
  const _SelectOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final QuestSelectOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    final leadingWidget = option.leading ??
        (option.icon != null
            ? Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected ? q.primaryLight : q.surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  option.icon,
                  size: 18,
                  color: selected ? q.primaryText : q.muted,
                ),
              )
            : null);

    return Semantics(
      button: true,
      selected: selected,
      label: '${option.label}${option.subtitle != null ? ', ${option.subtitle}' : ''}',
      child: QuestPress(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? q.primaryLight.withValues(alpha: 0.5) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(
              color: selected ? q.primary.withValues(alpha: 0.35) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              if (leadingWidget != null) ...[
                leadingWidget,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? q.primaryText : q.text,
                      ),
                    ),
                    if (option.subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        option.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.qSmall(12).copyWith(color: q.muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: q.primarySolid,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
