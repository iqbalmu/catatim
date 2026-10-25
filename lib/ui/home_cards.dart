import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/budget.dart';
import '../core/dates_id.dart';
import '../core/money.dart';
import '../game/mascot.dart';
import '../game/progress.dart';
import '../models.dart';
import '../storage/repository.dart';
import '../theme/tokens.dart';
import 'transaction_sheet.dart';

/// Design system fintech modern & gamified (merujuk referensi visual):
/// - Latar ultra-clean lavender-tinted soft white (`#F6F7FB`)
/// - Kartu putih murni beradius 26px, border hairline halus, soft diffuse shadow
/// - Panggung maskot besar di tengah dikelilingi circular horseshoe gauge arc multi-warna
/// - Angka besar & persentase tepat di bawah ring dengan legend kategori titik berwarna
/// - Kartu insight pintar ala "AI Insights" dengan ikon lampu/bintang
/// - Total Saldo dengan segmented pill control (`[Hari Ini] [Minggu Ini] [Bulan Ini]`) beraksen lilac/ungu
/// - Disiplin mingguan dengan vertical rounded pill bars ala "AI Forecast" chart
/// - Transaksi terbaru dengan squircle icon avatar dan nominal tabular

const _tabular = [FontFeature.tabularFigures()];

/// Palet warna design system
class _FintechColors {
  static const surface = Colors.white;
  static const border = Color(0x0A000000);

  // Tipografi
  static const textPrimary = Color(0xFF161924); // Obsidian
  static const textSecondary = Color(0xFF7C8BA0); // Slate
  static const textMuted = Color(0xFF9AA8BC);

  // Aksen Lilac/Purple (identik dengan pill aktif di referensi)
  static const lilacBg = Color(0xFFE9D8FD);
  static const lilacText = Color(0xFF6B46C1);
  static const purple = Color(0xFF8B5CF6);

  // Aksen Finansial
  static const green = Color(0xFF10B981); // Emerald / Income / Safe
  static const greenBg = Color(0xFFDEF7EC);
  static const greenText = Color(0xFF03543F);

  static const blue = Color(0xFF3B82F6); // Sky / Travel / Action

  static const amber = Color(0xFFF59E0B); // Pochy / Flame / Trophy
  static const amberBg = Color(0xFFFEF3C7);
  static const amberText = Color(0xFFB45309);

  static const red = Color(0xFFEF4444); // Coral / Over
  static const redBg = Color(0xFFFDE8E8);
  static const redText = Color(0xFF9B1C1C);

  static const track = Color(0xFFEEF2F6);
}

/// Dekorasi kartu sesuai design system: radius 26, soft shadow, hairline border
BoxDecoration _fintechCardDecoration({double radius = 26}) => BoxDecoration(
      color: _FintechColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _FintechColors.border, width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A2B3A4A),
          offset: Offset(0, 8),
          blurRadius: 24,
          spreadRadius: -2,
        ),
      ],
    );

/// Wadah kartu fintech
class _FintechCardBox extends StatelessWidget {
  const _FintechCardBox({
    required this.child,
    this.onTap,
    this.padding,
    this.radius = 26,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: _fintechCardDecoration(radius: radius),
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

/// Format rupiah ringkas: 1.500.000 → '1,5jt', 78.000 → '78rb'.
String _shortMoney(int v) {
  final sign = v < 0 ? '-' : '';
  final a = v.abs();
  if (a >= 1000000) {
    final jt = (a / 100000).round() / 10;
    final s = jt == jt.roundToDouble()
        ? jt.toStringAsFixed(0)
        : jt.toStringAsFixed(1);
    return '$sign${s.replaceAll('.', ',')}jt';
  }
  if (a >= 10000) return '$sign${a ~/ 1000}rb';
  return '$sign${Money.format(a)}';
}

/// Ikon kategori dari colorIndex
const _categoryIcons = <IconData>[
  Icons.restaurant_rounded, // 0 Makanan
  Icons.directions_bus_rounded, // 1 Transportasi
  Icons.receipt_long_rounded, // 2 Tagihan
  Icons.shopping_bag_rounded, // 3 Belanja
  Icons.sports_esports_rounded, // 4 Hiburan
  Icons.favorite_rounded, // 5 Kesehatan
  Icons.payments_rounded, // 6 Gaji
  Icons.swap_horiz_rounded, // 7 Transfer
  Icons.category_rounded, // 8 Lainnya
];

IconData _categoryIcon(int colorIndex) =>
    _categoryIcons[colorIndex % _categoryIcons.length];

// ─────────────────────────────────────────────────────────────────────────────
// 1. HERO MASKOT DENGAN CIRCULAR PROGRESS GAUGE (Spendings & Goals)
// ─────────────────────────────────────────────────────────────────────────────

/// Panggung Utama:
/// Maskot Pochy besar di tengah, dikelilingi Horseshoe Circular Gauge multi-segmen
/// (hijau, biru, ungu), dengan angka pengeluaran & persentase tepat di bawah ring,
/// diikuti kartu Smart Insights.
class UangCard extends StatelessWidget {
  const UangCard({
    super.key,
    required this.progress,
    this.repository,
  });

  final ProgressService progress;
  final LedgerRepository? repository;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        final latest = progress.latest;
        final lines = latest?.snapshot.lines;
        LimitLine? at(int i) =>
            lines != null && lines.length > i ? lines[i] : null;

        final dLimit = at(0)?.limit;
        final dUsed = at(0)?.used ?? 0;
        final hasDaily = dLimit != null && dLimit > 0;
        final fraction = hasDaily
            ? (dUsed / dLimit).clamp(0.0, 1.0)
            : (dUsed > 0 ? 0.35 : 0.0);
        final isOver = hasDaily && dUsed > dLimit;

        return _MascotGaugeSection(
          mood: latest?.mood ?? MascotMood.idle,
          caption: latest?.moodCaption,
          subLine: latest?.moodLine,
          streakDays: latest?.streakDays ?? 0,
          usedAmount: dUsed,
          limitAmount: dLimit,
          progressFraction: fraction,
          isOver: isOver,
        );
      },
    );
  }
}

class _MascotGaugeSection extends StatelessWidget {
  const _MascotGaugeSection({
    required this.mood,
    this.caption,
    this.subLine,
    required this.streakDays,
    required this.usedAmount,
    this.limitAmount,
    required this.progressFraction,
    required this.isOver,
  });

  final MascotMood mood;
  final String? caption;
  final String? subLine;
  final int streakDays;
  final int usedAmount;
  final int? limitAmount;
  final double progressFraction;
  final bool isOver;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final now = DateTime.now();
    final percentVal = (progressFraction * 100).toInt();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPadding + 4, 20, 8),
      child: Column(
        children: [
          // Header Bar: "Hey, Teman 👋" & Tanggal hari ini
          Padding(
            padding: const EdgeInsets.only(right: 96, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hey, Teman 👋',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: _FintechColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    idFullDate(now),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _FintechColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Judul Seksi ala "Spendings & Goals"
          const Text(
            'Target & Pengeluaran',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: _FintechColors.textPrimary,
            ),
          ),

          const SizedBox(height: 14),

          // Panggung Circular Gauge dengan Maskot Besar di Tengah
          GestureDetector(
            onTap: () => HapticFeedback.lightImpact(),
            child: SizedBox(
              width: 248,
              height: 248,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Horseshoe circular progress ring
                  CustomPaint(
                    size: const Size(244, 244),
                    painter: _HorseshoeGaugePainter(
                      progress: progressFraction,
                      isOver: isOver,
                    ),
                  ),

                  // Maskot Pochy besar di tengah (size: 152)
                  Positioned(
                    top: 14,
                    child: MascotStage(
                      mood: mood,
                      size: 152,
                      glow: _FintechColors.amber.withValues(alpha: 0.3),
                      glowStrength: 0.6,
                    ),
                  ),

                  // Angka Pengeluaran & Persentase di celah bawah ring
                  Positioned(
                    bottom: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Money.format(usedAmount),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: isOver
                                ? _FintechColors.red
                                : _FintechColors.green,
                            fontFeatures: _tabular,
                          ),
                        ),
                        Text(
                          '$percentVal%',
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            color: _FintechColors.textPrimary,
                            fontFeatures: _tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Legend kategori titik berwarna ala referensi
          // • Makanan (Hijau) • Transport (Biru) • Belanja (Ungu)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(_FintechColors.green, 'Makanan'),
              const SizedBox(width: 14),
              _legendDot(_FintechColors.blue, 'Transport'),
              const SizedBox(width: 14),
              _legendDot(_FintechColors.purple, 'Belanja'),
            ],
          ),

          const SizedBox(height: 14),

          // Smart Insight Card ala "AI Insights" di referensi
          _FintechCardBox(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _FintechColors.lilacBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: _FintechColors.lilacText,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caption ?? mascotCaption(mood),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _FintechColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subLine ??
                            (isOver
                                ? 'Pengeluaran harian melewati jatah batas'
                                : 'Disiplin terjaga, pengeluaran aman hari ini'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: _FintechColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: _FintechColors.textMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: _FintechColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Custom painter untuk circular horseshoe gauge arc (membuka di bawah)
class _HorseshoeGaugePainter extends CustomPainter {
  _HorseshoeGaugePainter({
    required this.progress,
    required this.isOver,
  });

  final double progress;
  final bool isOver;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;
    const strokeWidth = 9.5;

    // Busur tapal kuda: Mulai dari kiri bawah (135°), berputar searah jarum jam 270° ke kanan bawah
    const startAngle = 135 * math.pi / 180;
    const totalSweep = 270 * math.pi / 180;

    // Track latar belakang
    final trackPaint = Paint()
      ..color = _FintechColors.track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    // Busur progres aktif
    if (progress > 0) {
      final activeSweep = progress.clamp(0.04, 1.0) * totalSweep;

      final activePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      if (isOver) {
        activePaint.color = _FintechColors.red;
      } else {
        // Multi-warna bersegmen: Hijau -> Biru -> Ungu (identik dengan referensi)
        activePaint.shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + totalSweep,
          colors: const [
            _FintechColors.green,
            _FintechColors.blue,
            _FintechColors.purple,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HorseshoeGaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isOver != isOver;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. TOTAL BALANCE & SEGMENTED CONTROLS (Hari Ini | Minggu Ini | Bulan Ini)
// ─────────────────────────────────────────────────────────────────────────────

/// Kartu Total Saldo & Pengeluaran Bersegmen ala referensi visual bawah:
/// Header "Total Balance", nominal besar, kontrol pill bersegmen beraksen lilac,
/// bar progres horizontal bergradien, dan status pill (+3% / -15%).
class SpendingCard extends StatefulWidget {
  const SpendingCard({
    super.key,
    required this.progress,
    this.repository,
    this.onTap,
  });

  final ProgressService progress;
  final LedgerRepository? repository;
  final VoidCallback? onTap;

  @override
  State<SpendingCard> createState() => _SpendingCardState();
}

class _SpendingCardState extends State<SpendingCard> {
  bool _hideBalance = false;
  int _selectedSegment = 0; // 0 = Hari Ini, 1 = Minggu Ini, 2 = Bulan Ini

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.progress,
      builder: (context, _) {
        final lines = widget.progress.latest?.snapshot.lines;
        LimitLine? at(int i) =>
            lines != null && lines.length > i ? lines[i] : null;

        // Ambil data sesuai segmen yang dipilih
        final activeLine = at(_selectedSegment);
        final used = activeLine?.used ?? 0;
        final limit = activeLine?.limit;
        final hasLimit = limit != null && limit > 0;
        final isOver = hasLimit && used > limit;
        final fraction = hasLimit ? (used / limit).clamp(0.0, 1.0) : 0.0;
        final sisa = hasLimit ? limit - used : null;

        final segmentTitles = ['Hari Ini', 'Minggu Ini', 'Bulan Ini'];

        return _FintechCardBox(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris Total Saldo (jika repository tersedia)
              if (widget.repository != null) ...[
                StreamBuilder<Map<int, int>>(
                  stream: widget.repository!.watchAccountBalances(),
                  builder: (context, snapshot) {
                    final balances = snapshot.data;
                    final total = balances == null
                        ? 0
                        : balances.values.fold<int>(0, (a, b) => a + b);

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL BALANCE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: _FintechColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _hideBalance ? '••••••••' : Money.format(total),
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                                color: _FintechColors.textPrimary,
                                fontFeatures: _tabular,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _hideBalance = !_hideBalance);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _hideBalance
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 19,
                              color: _FintechColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Segmented Control Pill ala [Overview] [Transactions] [Goals] di referensi
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < segmentTitles.length; i++)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedSegment = i);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedSegment == i
                                  ? _FintechColors.lilacBg
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              segmentTitles[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: _selectedSegment == i
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: _selectedSegment == i
                                    ? _FintechColors.lilacText
                                    : _FintechColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Detail Pengeluaran untuk segmen terpilih
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pengeluaran ${segmentTitles[_selectedSegment]}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _FintechColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            Money.format(used),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: _FintechColors.textPrimary,
                              fontFeatures: _tabular,
                            ),
                          ),
                          if (hasLimit) ...[
                            const SizedBox(width: 6),
                            Text(
                              'of ${_shortMoney(limit)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _FintechColors.textMuted,
                                fontFeatures: _tabular,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  if (hasLimit && sisa != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isOver
                            ? _FintechColors.redBg
                            : _FintechColors.greenBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isOver
                            ? '−${_shortMoney(sisa.abs())}'
                            : '+${_shortMoney(sisa)} sisa',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: isOver
                              ? _FintechColors.redText
                              : _FintechColors.greenText,
                          fontFeatures: _tabular,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Bar Progres Horizontal Bergradien
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 8,
                  color: _FintechColors.track,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: hasLimit ? fraction : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: isOver
                              ? const [Color(0xFFF87171), _FintechColors.red]
                              : const [
                                  _FintechColors.blue,
                                  _FintechColors.purple,
                                ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. DISIPLIN MINGGUAN (AI FORECAST BAR CHART)
// ─────────────────────────────────────────────────────────────────────────────

/// Strip Disiplin Mingguan berbentuk Bar Chart vertikal modern ala layar "AI Forecast"
/// di referensi visual: 7 pilar vertikal berujung rounded (Senin–Minggu) dengan badge aktif.
class StreakStrip extends StatelessWidget {
  const StreakStrip({super.key, required this.progress});

  final ProgressService progress;

  static const _dayLabelsId = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min'
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final monday = today.subtract(Duration(days: now.weekday - 1));

        final byDay = <DateTime, DailyDiscipline>{
          for (final d
              in progress.latest?.disciplineMonth ?? const <DailyDiscipline>[])
            DateTime(d.day.year, d.day.month, d.day.day): d,
        };

        final streakDays = progress.latest?.streakDays ?? 0;

        return _FintechCardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Disiplin Mingguan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _FintechColors.amberBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_fire_department_rounded,
                          size: 18,
                          color: _FintechColors.amberText,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Disiplin Mingguan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _FintechColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _FintechColors.amberBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '🔥 $streakDays Hari',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _FintechColors.amberText,
                        fontFeatures: _tabular,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Bar Chart 7 Hari vertikal ala "AI Forecast"
              SizedBox(
                height: 108,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _ForecastPillar(
                          day: monday.add(Duration(days: i)),
                          today: today,
                          byDay: byDay,
                          label: _dayLabelsId[i],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Satu pilar vertikal hari dalam chart disiplin
class _ForecastPillar extends StatelessWidget {
  const _ForecastPillar({
    required this.day,
    required this.today,
    required this.byDay,
    required this.label,
  });

  final DateTime day;
  final DateTime today;
  final Map<DateTime, DailyDiscipline> byDay;
  final String label;

  @override
  Widget build(BuildContext context) {
    final disc = byDay[day];
    final future = disc?.future ?? day.isAfter(today);
    final kept = !future && (disc?.within ?? false);
    final broke = !future && disc != null && !disc.within;
    final isToday = day == today;

    // Tinggi pilar (antara 42 hingga 66 px)
    final double pillarHeight = isToday
        ? 66
        : kept
            ? 56
            : broke
                ? 44
                : 36;

    // Warna & isi pilar
    final Color barColor = isToday
        ? _FintechColors.purple
        : kept
            ? const Color(0xFFC4B5FD)
            : broke
                ? const Color(0xFFFCA5A5)
                : const Color(0xFFE2E8F0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Floating pill badge untuk hari ini ala `$173` di referensi
        if (isToday)
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: _FintechColors.lilacBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Ini',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: _FintechColors.lilacText,
              ),
            ),
          )
        else
          const SizedBox(height: 18),

        // Batang pilar rounded
        Container(
          width: double.infinity,
          height: pillarHeight,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: kept
              ? const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: Colors.white,
                )
              : broke
                  ? const Icon(
                      Icons.close_rounded,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
        ),

        const SizedBox(height: 4),

        // Label nama hari
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: isToday
                ? _FintechColors.textPrimary
                : _FintechColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. TRANSAKSI TERBARU (Squircle Avatar Cards)
// ─────────────────────────────────────────────────────────────────────────────

/// Kartu Transaksi Terbaru ala referensi atas kiri ("Burger King Food -$32.34"):
/// Avatar squircle berpalet pastel, nama jelas, subteks kategori, nominal tebal,
/// dan tombol panah circular ↗ "Lihat semua".
class TransaksiTerbaruCard extends StatefulWidget {
  const TransaksiTerbaruCard({
    super.key,
    required this.repository,
    required this.progress,
    required this.onSeeAll,
  });

  final LedgerRepository repository;
  final ProgressService progress;
  final VoidCallback onSeeAll;

  @override
  State<TransaksiTerbaruCard> createState() => _TransaksiTerbaruCardState();
}

class _TransaksiTerbaruCardState extends State<TransaksiTerbaruCard> {
  late final Stream<List<TxWithCategory>> _recent;

  @override
  void initState() {
    super.initState();
    _recent = widget.repository.watchRecentWithCategory(limit: 4);
  }

  @override
  Widget build(BuildContext context) {
    return _FintechCardBox(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transaksi Terbaru',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _FintechColors.textPrimary,
                ),
              ),
              InkWell(
                onTap: widget.onSeeAll,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.arrow_outward_rounded,
                    size: 16,
                    color: _FintechColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<TxWithCategory>>(
            stream: _recent,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 120,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final items = snapshot.data ?? const <TxWithCategory>[];
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.receipt_long_outlined,
                            size: 22,
                            color: _FintechColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Belum ada transaksi',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _FintechColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Catat transaksi pertamamu lewat tombol + di bawah',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _FintechColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF8FAFC),
                      ),
                    _FintechRecentRow(
                      item: items[i],
                      repository: widget.repository,
                      progress: widget.progress,
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FintechRecentRow extends StatelessWidget {
  const _FintechRecentRow({
    required this.item,
    required this.repository,
    required this.progress,
  });

  final TxWithCategory item;
  final LedgerRepository repository;
  final ProgressService progress;

  @override
  Widget build(BuildContext context) {
    final tx = item.tx;
    final incoming = tx.direction == Direction.incoming;
    final title = (tx.counterparty != null && tx.counterparty!.isNotEmpty)
        ? tx.counterparty!
        : tx.kind.label;

    // Warna & icon squircle avatar kategori
    final Color avatarColor;
    final IconData avatarIcon;

    if (item.category != null) {
      avatarColor = SeedColors.categoryColor(item.category!.colorIndex);
      avatarIcon = _categoryIcon(item.category!.colorIndex);
    } else if (tx.kind == TxKind.transfer) {
      avatarColor = const Color(0xFF64748B);
      avatarIcon = Icons.swap_horiz_rounded;
    } else {
      avatarColor = incoming ? _FintechColors.green : _FintechColors.red;
      avatarIcon = incoming
          ? Icons.arrow_downward_rounded
          : Icons.arrow_upward_rounded;
    }

    return InkWell(
      onTap: () => TransactionSheet.show(
        context,
        repository,
        existing: item,
        progress: progress,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          children: [
            // Squircle rounded avatar ala referensi
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: avatarColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(avatarIcon, size: 22, color: avatarColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _FintechColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.category?.name ?? (incoming ? 'Pemasukan' : 'Pengeluaran')} • ${idDayMonth(tx.occurredAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _FintechColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${incoming ? '+' : '−'}${Money.format(tx.amount)}',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: incoming
                    ? _FintechColors.green
                    : _FintechColors.textPrimary,
                fontFeatures: _tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
