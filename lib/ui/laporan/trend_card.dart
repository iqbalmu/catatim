part of '../laporan_screen.dart';

class _InteractiveTrendCard extends StatelessWidget {
  const _InteractiveTrendCard({
    required this.buckets,
    required this.isMonthlyGranularity,
    required this.selectedIndex,
    required this.onSelectIndex,
  });

  final List<TrendBucket> buckets;
  final bool isMonthlyGranularity;
  final int? selectedIndex;
  final ValueChanged<int> onSelectIndex;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return const SizedBox.shrink();

    int defaultIdx = buckets.length - 1;
    for (var i = buckets.length - 1; i >= 0; i--) {
      if (buckets[i].incoming > 0 || buckets[i].outgoing > 0) {
        defaultIdx = i;
        break;
      }
    }
    final activeIdx = (selectedIndex != null &&
            selectedIndex! >= 0 &&
            selectedIndex! < buckets.length)
        ? selectedIndex!
        : defaultIdx;
    final activeBucket = buckets[activeIdx];
    final maxVal = buckets.fold<int>(
      0,
      (m, b) => math.max(m, math.max(b.incoming, b.outgoing)),
    );

    return Container(
      padding: const EdgeInsets.all(Spacing.m),
      decoration: BoxDecoration(
        color: context.q.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.q.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                isMonthlyGranularity ? 'Perbandingan Bulanan' : 'Perbandingan Mingguan',
                style: context.qTitle(15),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniLegend(color: context.q.good, label: 'Masuk'),
                  const SizedBox(width: 10),
                  _MiniLegend(color: context.q.bad, label: 'Keluar'),
                ],
              ),
            ],
          ),
          const SizedBox(height: Spacing.s + 2),

          // Selected Bucket Inspector Strip (Wrap = zero overflow)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: context.q.surface2,
              borderRadius: BorderRadius.circular(AppRadius.cell),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                QuestSwap(
                  slide: false,
                  child: Text(
                    isMonthlyGranularity
                        ? 'Bulan ${activeBucket.label}'
                        : 'Mulai ${activeBucket.label}',
                    key: ValueKey('lbl-$activeIdx-${activeBucket.label}'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: context.q.text,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    QuestMoney(
                      amount: activeBucket.incoming,
                      prefix: '+',
                      duration: QuestMotion.medium,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.q.good,
                        fontFeatures: _tabular,
                      ),
                    ),
                    QuestMoney(
                      amount: activeBucket.outgoing,
                      prefix: '−',
                      duration: QuestMotion.medium,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.q.bad,
                        fontFeatures: _tabular,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),

          // Interactive Chart Canvas
          SizedBox(
            height: 176,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const yAxisWidth = 46.0;
                final plotWidth = math.max(1.0, constraints.maxWidth - yAxisWidth);

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final dx = details.localPosition.dx - yAxisWidth;
                    if (dx < 0) return;
                    final idx = (dx / (plotWidth / buckets.length))
                        .floor()
                        .clamp(0, buckets.length - 1);
                    onSelectIndex(idx);
                  },
                  child: QuestReplay(
                    duration:
                        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
                        ? Duration.zero
                        : const Duration(milliseconds: 720),
                    curve: Curves.linear,
                    builder: (context, chartProgress) => CustomPaint(
                      size: Size(constraints.maxWidth, 176),
                      painter: _StructuredTrendPainter(
                        buckets: buckets,
                        maxValue: maxVal,
                        selectedIndex: activeIdx,
                        progress: chartProgress,
                        yAxisWidth: yAxisWidth,
                        inColor: context.q.good,
                        outColor: context.q.bad,
                        gridColor: context.q.line,
                        highlightColor:
                            SeedColors.primaryLight.withValues(alpha: 0.7),
                        labelColor: context.q.muted,
                        activeLabelColor: context.q.primary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLegend extends StatelessWidget {
  const _MiniLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: context.qSmall(11)),
      ],
    );
  }
}

class _StructuredTrendPainter extends CustomPainter {
  _StructuredTrendPainter({
    required this.buckets,
    required this.maxValue,
    required this.selectedIndex,
    required this.progress,
    required this.yAxisWidth,
    required this.inColor,
    required this.outColor,
    required this.gridColor,
    required this.highlightColor,
    required this.labelColor,
    required this.activeLabelColor,
  });

  final List<TrendBucket> buckets;
  final int maxValue;
  final int selectedIndex;
  final double progress;
  final double yAxisWidth;
  final Color inColor;
  final Color outColor;
  final Color gridColor;
  final Color highlightColor;
  final Color labelColor;
  final Color activeLabelColor;

  static String _compactAxis(int v) {
    if (v <= 0) return '0';
    if (v >= 1000000000) {
      return '${(v / 1000000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
    if (v >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1).replaceAll('.0', '')}jt';
    }
    if (v >= 1000) {
      return '${(v / 1000).round()}rb';
    }
    return '$v';
  }

  @override
  void paint(Canvas canvas, Size size) {
    const topPad = 8.0;
    const bottomAxisH = 24.0;
    final chartH = size.height - topPad - bottomAxisH;
    final plotW = math.max(1.0, size.width - yAxisWidth);
    final effectiveMax = maxValue > 0 ? maxValue : 100000;

    // 1. Horizontal Gridlines + Y-Axis Labels (Top, Mid, Zero)
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final levels = [
      (y: topPad, val: effectiveMax),
      (y: topPad + chartH / 2, val: (effectiveMax / 2).round()),
      (y: topPad + chartH, val: 0),
    ];

    for (final lvl in levels) {
      canvas.drawLine(
        Offset(yAxisWidth, lvl.y),
        Offset(size.width, lvl.y),
        gridPaint,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: _compactAxis(lvl.val),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: labelColor,
            fontFeatures: _tabular,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: yAxisWidth - 6);
      tp.paint(
        canvas,
        Offset(yAxisWidth - tp.width - 6, lvl.y - tp.height / 2),
      );
    }

    if (buckets.isEmpty) return;

    final groupW = plotW / buckets.length;
    final barW = (groupW * 0.28).clamp(5.0, 16.0);
    const barGap = 3.0;
    final labelStride = buckets.length > 8 ? (buckets.length / 5).ceil() : 1;

    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final groupLeft = yAxisWidth + i * groupW;
      final centerX = groupLeft + groupW / 2;
      final isSelected = i == selectedIndex;

      // Active column highlight band
      if (isSelected) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(groupLeft + 2, 0, math.max(0, groupW - 4), chartH + topPad),
            const Radius.circular(8),
          ),
          Paint()..color = highlightColor,
        );
      }

      final baseY = topPad + chartH;
      final spread =
          buckets.length > 1 ? (i / (buckets.length - 1)) * 0.34 : 0.0;
      final localRaw = ((progress - spread) / (1.0 - spread)).clamp(0.0, 1.0);
      final barProgress = Curves.easeOutCubic.transform(localRaw);

      // Incoming bar
      if (b.incoming > 0 && maxValue > 0 && barProgress > 0) {
        final h =
            math.max(4.0, (b.incoming / maxValue) * chartH) * barProgress;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(centerX - barGap / 2 - barW, baseY - h, barW, h),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()..color = inColor,
        );
      }

      // Outgoing bar
      if (b.outgoing > 0 && maxValue > 0 && barProgress > 0) {
        final h =
            math.max(4.0, (b.outgoing / maxValue) * chartH) * barProgress;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(centerX + barGap / 2, baseY - h, barW, h),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()..color = outColor,
        );
      }

      // X-axis label (strided so labels never collide)
      if (i % labelStride == 0 || isSelected || i == buckets.length - 1) {
        if (!isSelected &&
            i == buckets.length - 1 &&
            labelStride > 1 &&
            (i % labelStride) < (labelStride ~/ 2)) {
          continue;
        }
        final xTp = TextPainter(
          text: TextSpan(
            text: b.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? activeLabelColor : labelColor,
            ),
          ),
          maxLines: 1,
          ellipsis: '…',
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: math.max(groupW * labelStride - 2, 36));
        final double clampedX = (centerX - xTp.width / 2)
            .clamp(yAxisWidth, math.max(yAxisWidth, size.width - xTp.width))
            .toDouble();
        xTp.paint(canvas, Offset(clampedX, baseY + 6));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StructuredTrendPainter oldDelegate) =>
      oldDelegate.maxValue != maxValue ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.progress != progress ||
      oldDelegate.buckets.length != buckets.length;
}

/// 03 · Kartu Komposisi Kategori (Stacked Bar + Tabel Terstruktur)
