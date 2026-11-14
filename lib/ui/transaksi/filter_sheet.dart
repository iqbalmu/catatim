part of '../transaksi_screen.dart';

class _TransactionFilterSheet extends StatefulWidget {
  const _TransactionFilterSheet({
    required this.initialDirection,
    required this.initialAccountId,
    required this.accounts,
  });

  final Direction? initialDirection;
  final int? initialAccountId;
  final List<Account> accounts;

  @override
  State<_TransactionFilterSheet> createState() =>
      _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<_TransactionFilterSheet> {
  late Direction? _direction;
  late int? _accountId;

  @override
  void initState() {
    super.initState();
    _direction = widget.initialDirection;
    _accountId = widget.initialAccountId;
  }

  bool get _hasFilter => _direction != null || _accountId != null;

  void _reset() {
    HapticFeedback.selectionClick();
    setState(() {
      _direction = null;
      _accountId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.l,
        Spacing.xs,
        Spacing.l,
        Spacing.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Judul + Reset
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filter Transaksi', style: context.qTitle(18)),
              if (_hasFilter)
                QuestPress(
                  onTap: _reset,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      'Reset',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: q.bad,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.m),

          // Section 1: Arah Transaksi
          Text(
            'Jenis Transaksi',
            style: context.qSmall().copyWith(
              fontWeight: FontWeight.w700,
              color: q.muted,
            ),
          ),
          const SizedBox(height: Spacing.s),
          Row(
            children: [
              Expanded(
                child: _FilterOptionCard(
                  label: 'Semua',
                  icon: Icons.swap_vert_rounded,
                  selected: _direction == null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _direction = null);
                  },
                ),
              ),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: _FilterOptionCard(
                  label: 'Keluar',
                  icon: Icons.arrow_upward_rounded,
                  iconColor: q.bad,
                  selected: _direction == Direction.outgoing,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _direction = Direction.outgoing);
                  },
                ),
              ),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: _FilterOptionCard(
                  label: 'Masuk',
                  icon: Icons.arrow_downward_rounded,
                  iconColor: q.good,
                  selected: _direction == Direction.incoming,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _direction = Direction.incoming);
                  },
                ),
              ),
            ],
          ),

          if (widget.accounts.isNotEmpty) ...[
            const SizedBox(height: Spacing.m),
            // Section 2: Rekening / Akun
            Text(
              'Akun / Rekening',
              style: context.qSmall().copyWith(
                fontWeight: FontWeight.w700,
                color: q.muted,
              ),
            ),
            const SizedBox(height: Spacing.s),
            Wrap(
              spacing: Spacing.xs,
              runSpacing: Spacing.xs,
              children: [
                _FilterOptionChip(
                  label: 'Semua Akun',
                  selected: _accountId == null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _accountId = null);
                  },
                ),
                for (final acc in widget.accounts)
                  _FilterOptionChip(
                    label: acc.name,
                    icon: switch (acc.kind) {
                      AccountKind.bank => Icons.account_balance_rounded,
                      AccountKind.ewallet => Icons.phone_android_rounded,
                      AccountKind.cash => Icons.payments_outlined,
                    },
                    selected: _accountId == acc.id,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _accountId = acc.id);
                    },
                  ),
              ],
            ),
          ],

          const SizedBox(height: Spacing.m),

          // Action Button
          QuestButton(
            label: 'Terapkan Filter',
            onPressed: () {
              Navigator.pop(
                context,
                (direction: _direction, accountId: _accountId),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterOptionCard extends StatelessWidget {
  const _FilterOptionCard({
    required this.label,
    required this.icon,
    this.iconColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color? iconColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    // Pill horizontal — satu bahasa chip dengan filter akun di bawahnya,
    // bukan kartu tinggi ikon-di-atas-label yang mendominasi sheet.
    return QuestPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: QuestMotion.fast,
        curve: QuestMotion.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? q.primary.withValues(alpha: 0.12) : q.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? q.primary : q.line.withValues(alpha: 0.6),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? (iconColor ?? q.primary)
                  : (iconColor?.withValues(alpha: 0.7) ?? q.muted),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? q.primary : q.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterOptionChip extends StatelessWidget {
  const _FilterOptionChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? q.primary.withValues(alpha: 0.12) : q.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? q.primary : q.line.withValues(alpha: 0.6),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? q.primary : q.muted,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? q.primary : q.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
