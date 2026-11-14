part of '../laporan_screen.dart';

class _AccountOptionTile extends StatelessWidget {
  const _AccountOptionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected ? context.q.primaryLight : context.q.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? context.q.primaryText : context.q.muted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.q.text,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.qSmall(11.5),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: context.q.primaryText, size: 20),
          ],
        ),
        ),
      ),
    );
  }
}

class _LaporanPeriodSheet extends StatefulWidget {
  const _LaporanPeriodSheet({
    required this.initialMonth,
    required this.initialRange,
  });

  final DateTime initialMonth;
  final DateTimeRange? initialRange;

  @override
  State<_LaporanPeriodSheet> createState() => _LaporanPeriodSheetState();
}

class _LaporanPeriodSheetState extends State<_LaporanPeriodSheet> {
  late bool _customMode = widget.initialRange != null;
  late DateTimeRange? _range = widget.initialRange;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.s, Spacing.m, Spacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.q.muted.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: Spacing.m),
            Text('Pilih Periode Laporan', style: context.qTitle(16)),
            const SizedBox(height: Spacing.s),
            QuestSegmented<bool>(
              selected: _customMode,
              onChanged: (val) => setState(() => _customMode = val),
              options: const [
                (value: false, label: 'Per Bulan', icon: null),
                (value: true, label: 'Rentang Tanggal', icon: null),
              ],
            ),
            const SizedBox(height: Spacing.m),
            AnimatedSize(
              duration: QuestMotion.fast,
              curve: QuestMotion.easeOut,
              alignment: Alignment.topCenter,
              child: !_customMode
                  ? QuestMonthPicker(
                      initialMonth: widget.initialMonth,
                      onChanged: (m) => Navigator.pop(context, (month: m, range: null)),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QuestRangeCalendar(
                          initialRange: _range,
                          onChanged: (r) => setState(() => _range = r),
                        ),
                        const SizedBox(height: Spacing.m),
                        QuestButton(
                          label: 'Terapkan Rentang',
                          icon: Icons.check_rounded,
                          onPressed: _range == null
                              ? null
                              : () => Navigator.pop(context, (month: null, range: _range)),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({
    required this.height,
    required this.emptyColor,
    required this.segments,
    this.replayKey,
  });

  final double height;
  final Color emptyColor;
  final List<({int weight, Color color})> segments;
  final Object? replayKey;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: QuestReplay(
          duration: reduced ? Duration.zero : QuestMotion.grow,
          replayKey: replayKey,
          builder: (context, progress) => CustomPaint(
            painter: _SegmentedBarPainter(
              emptyColor: emptyColor,
              segments: segments,
              progress: progress,
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedBarPainter extends CustomPainter {
  const _SegmentedBarPainter({
    required this.emptyColor,
    required this.segments,
    required this.progress,
  });

  final Color emptyColor;
  final List<({int weight, Color color})> segments;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    // Selalu gambar track latar terlebih dahulu agar progres 0→target terlihat jelas.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = emptyColor,
    );
    final nonZero = segments.where((s) => s.weight > 0).toList();
    final total = nonZero.fold<int>(0, (sum, s) => sum + s.weight);
    if (nonZero.isEmpty || total <= 0 || progress <= 0) {
      return;
    }
    const gap = 2.5;
    final totalGap = math.max(0, nonZero.length - 1) * gap;
    final avail = math.max(0.0, size.width - totalGap);
    var x = 0.0;
    for (var i = 0; i < nonZero.length; i++) {
      final seg = nonZero[i];
      final w = i == nonZero.length - 1
          ? math.min(
              math.max(0.0, size.width - x),
              avail * (seg.weight / total) * progress,
            )
          : avail * (seg.weight / total) * progress;
      canvas.drawRect(
        Rect.fromLTWH(x, 0, w, size.height),
        Paint()..color = seg.color,
      );
      x += w + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedBarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.emptyColor != emptyColor ||
      oldDelegate.segments.length != segments.length ||
      [
        for (var i = 0; i < segments.length; i++)
          oldDelegate.segments[i].weight != segments[i].weight ||
              oldDelegate.segments[i].color != segments[i].color,
      ].any((changed) => changed);
}
