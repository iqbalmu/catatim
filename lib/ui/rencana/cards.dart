part of '../rencana_batas.dart';

/// Kartu mini satu batas: terpakai berjalan + bar status + plafon.
/// Tap → dialog edit plafon. Pola visual sama dengan [_AllocationRow]
/// (over = latar merah pudar, warning = madu, ok = hijau).

class _LimitMiniCard extends StatelessWidget {
  const _LimitMiniCard({
    required this.label,
    required this.used,
    required this.limit,
    required this.onTap,
  });

  final String label;
  final int used;
  final int? limit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final line = limit == null
        ? null
        : LimitLine(label: label, used: used, limit: limit!);
    final over = line?.level == BudgetLevel.over;
    return QuestPress(
      onTap: onTap,
      child: Container(
        padding: Insets.tile,
        decoration: BoxDecoration(
          color: over ? q.bad.withValues(alpha: 0.12) : q.surface,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(color: q.line),
          boxShadow: q.cardShadow,
        ),
        child: Container(
          // Transparan tapi opaque untuk hit-test: seluruh permukaan
          // kartu bisa ditap, bukan hanya teks/barnya.
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 10, color: q.muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Spacing.xs),
                  Icon(Icons.edit_rounded, size: 13, color: q.muted),
                ],
              ),
              const SizedBox(height: Spacing.xxs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: line == null
                    ? Text(
                        'Belum diatur',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: q.muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      )
                    : QuestCountUp(
                        value: used,
                        builder: (context, currentUsed) => Text(
                          _ringkasRp(currentUsed),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: over ? q.bad : q.text,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: Spacing.xs),
              if (line != null) ...[
                QuestBar(
                  value: line.fraction,
                  height: 5,
                  color: switch (line.level) {
                    BudgetLevel.over => q.bad,
                    BudgetLevel.warning => q.warn,
                    BudgetLevel.ok => q.good,
                  },
                ),
                const SizedBox(height: Spacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    over
                        ? 'lewat ${_ringkasRp(used - limit!)} · batas ${_ringkasRp(limit!)}'
                        : (used > 0
                            ? 'sisa ${_ringkasRp(limit! - used)} · batas ${_ringkasRp(limit!)}'
                            : 'batas ${_ringkasRp(limit!)}'),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: over ? FontWeight.w700 : FontWeight.w500,
                      color: over ? q.bad : q.muted,
                    ),
                  ),
                ),
              ] else
                Text(
                  'Atur batas',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: q.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu satu jenis: nama + ikon kelola di kiri, angka ringkas di
/// kanan, bar tipis di bawah. Tap kartu = edit alokasi; tap nama =
/// kelola jenis. Over = latar merah pudar.

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({
    required this.name,
    required this.used,
    required this.limit,
    required this.onTap,
    this.scopeLabel,
  });

  final String name;
  final String? scopeLabel;
  final int used;
  final int? limit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final line = limit == null
        ? null
        : LimitLine(label: name, used: used, limit: limit!);
    final over = line?.level == BudgetLevel.over;

    return Container(
      decoration: BoxDecoration(
        color: over ? q.bad.withValues(alpha: 0.12) : q.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: q.line),
        boxShadow: q.cardShadow,
      ),
      child: QuestPress(
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          padding: Insets.tile,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      scopeLabel == null ? name : '$name · $scopeLabel',
                      style: context
                          .qTitle(14)
                          .copyWith(color: line == null ? q.muted : null),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Spacing.xs),
                  Icon(Icons.edit_rounded, size: 14, color: q.muted),
                ],
              ),
              if (line == null && used <= 0)
                Text(
                  'Belum ada pengeluaran & batas',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: q.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                QuestCountUp(
                  value: used,
                  builder: (context, currentUsed) {
                    if (line == null) {
                      return Text(
                        'Terpakai ${_ringkasRp(currentUsed)} · belum ada batas',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: q.muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    }
                    final isOver = currentUsed > limit!;
                    final info = isOver
                        ? 'lewat ${_ringkasRp(currentUsed - limit!)}'
                        : 'sisa ${_ringkasRp(limit! - currentUsed)}';
                    return Text(
                      '${_ringkasRp(currentUsed)} dari ${_ringkasRp(limit!)} · $info',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isOver ? FontWeight.w700 : FontWeight.w400,
                        color: isOver ? q.bad : q.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              QuestBar(
                value: line?.fraction ?? 0,
                height: 6,
                color: line == null
                    ? q.line
                    : switch (line.level) {
                        BudgetLevel.over => q.bad,
                        BudgetLevel.warning => q.warn,
                        BudgetLevel.ok => q.good,
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu batas utama: fokus harian dengan maskot meter di kanan —
/// "sisa aman hari ini" (mockup v2.1). Tap = edit batas harian.

class _BatasBulananCard extends StatelessWidget {
  const _BatasBulananCard({
    required this.used,
    required this.limit,
    required this.onTap,
  });

  final int used;
  final int? limit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final hasLimit = limit != null && limit! > 0;
    final isOver = hasLimit && used >= limit!;
    final sisa = (limit ?? 0) - used;
    final fraction = hasLimit ? (used / limit!).clamp(0.0, 1.0) : 0.0;

    Color progressColor;
    if (isOver) {
      progressColor = q.bad;
    } else if (fraction >= 0.75) {
      progressColor = q.warn;
    } else {
      progressColor = q.good;
    }

    return QuestCard(
      variant: QuestCardVariant.hero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: q.primaryLight,
                        borderRadius: BorderRadius.circular(AppRadius.cell),
                      ),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        color: q.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: Spacing.s),
                    Flexible(
                      child: Text(
                        'Batas Total Bulanan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.qTitle(16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasLimit
                      ? (isOver
                            ? q.outgoingTint
                            : q.incomingTint)
                      : q.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: hasLimit
                    ? QuestMoney(
                        amount: isOver ? used - limit! : sisa,
                        prefix: isOver ? 'Lewat ' : 'Sisa ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isOver ? q.bad : q.good,
                        ),
                      )
                    : Text(
                        'Belum diatur',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: q.muted,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.m),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: hasLimit
                      ? QuestMoney(
                          amount: used,
                          suffix: ' dari ${Money.format(limit!)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: q.text,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        )
                      : Text(
                          'Ketuk untuk atur batas bulanan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: q.muted,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: Spacing.s),
              if (hasLimit)
                Text(
                  '${((used * 100 / limit!)).round()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: progressColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.s),
          QuestProgressBar(
            value: fraction,
            color: progressColor,
            backgroundColor: q.surface2,
          ),
        ],
      ),
    );
  }
}

/// Format ringkas untuk kartu mini: '18rb', '1,4jt' — tanpa 'Rp' agar
/// muat di sepertiga lebar layar.
String _ringkasRp(int v) {
  if (v >= 1000000) {
    final jt = v / 1000000;
    final s = jt == jt.roundToDouble()
        ? jt.round().toString()
        : jt.toStringAsFixed(1).replaceAll('.', ',');
    return '${s}jt';
  }
  if (v >= 1000) return '${(v / 1000).round()}rb';
  return '$v';
}
