import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum MascotMood { idle, happy, sleepy, celebrate, worried }

/// Maskot "Duit" — blob bulat dengan 5 mood.
///
/// Animasi hanya bob/breathing halus; hormat ke `disableAnimations`.
class Mascot extends StatefulWidget {
  const Mascot({super.key, required this.mood, this.size = 72});

  final MascotMood mood;
  final double size;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noMotion = MediaQuery.disableAnimationsOf(context);
    if (noMotion) {
      return CustomPaint(
        size: Size.square(widget.size),
        painter: _MascotPainter(
          mood: widget.mood,
          t: 0.25,
          animate: false,
          ink: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _MascotPainter(
          mood: widget.mood,
          t: _ctrl.value,
          animate: true,
          ink: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  /// Rentang tinta vertikal per mood (fraksi tinggi kanvas): tepi atas
  /// (telinga / Zzz / keringat) dan tepi bawah (kaki). Dipakai menormalisasi
  /// framing agar tiap mood mengisi kanvas sama besar.
  static const _inkTop = {
    MascotMood.idle: 0.30,
    MascotMood.happy: 0.30,
    MascotMood.sleepy: 0.06,
    MascotMood.worried: 0.29,
    MascotMood.celebrate: 0.30,
  };
  static const _inkBottom = 0.875;

  /// Setengah lebar tinta maksimum (fraksi lebar kanvas) — agar ornamen
  /// horizontal (konfeti, Zzz) tak terpotong kanvas.
  static const _inkHalfW = {
    MascotMood.idle: 0.243,
    MascotMood.happy: 0.243,
    MascotMood.sleepy: 0.463,
    MascotMood.worried: 0.304,
    MascotMood.celebrate: 0.36,
  };

  _MascotPainter({
    required this.mood,
    required this.t,
    required this.animate,
    required this.ink,
  });

  final MascotMood mood;
  final double t;
  final bool animate;
  final Color ink;

  static const _confetti = [
    Color(0xFFE07A5F),
    Color(0xFF3D8AA8),
    Color(0xFF8A6FBF),
    Color(0xFF4E9A6F),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;

    final amp = mood == MascotMood.sleepy ? s * 0.012 : s * 0.02;
    final bob = animate ? math.sin(t * 2 * math.pi) * amp : 0.0;
    final bodyCy = size.height * 0.58 + bob;

    final breathe = animate ? 1 + 0.03 * math.sin(t * 2 * math.pi) : 1.0;
    final bodyW = s * 0.54;
    final bodyH = s * 0.44 * breathe;
    final bodyRect = Rect.fromCenter(
      center: Offset(cx, bodyCy),
      width: bodyW,
      height: bodyH,
    );

    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round;

    // Normalisasi framing: petakan rentang tinta mood ini ke [0.03, 0.97].
    // Skala seragam (tanpa distorsi); dibatasi agar muat horizontal.
    final inkTop = _inkTop[mood]!;
    final vFit = 0.94 / (_inkBottom - inkTop);
    final hFit = 1.0 / (2 * _inkHalfW[mood]!);
    final frameScale = vFit < hFit ? vFit : hFit;
    final frameCy = (inkTop + _inkBottom) / 2;
    canvas.save();
    canvas.translate(cx, size.height * 0.5);
    canvas.scale(frameScale);
    canvas.translate(-cx, -size.height * frameCy);
    // Telinga
    for (final dx in [-0.16, 0.16]) {
      final ear = Rect.fromCenter(
        center: Offset(cx + dx * s, bodyRect.top),
        width: s * 0.13,
        height: s * 0.09,
      );
      canvas.drawOval(ear, Paint()..color = SeedColors.honey);
      canvas.drawOval(ear, stroke);
    }

    // Badan
    canvas.drawOval(bodyRect, Paint()..color = SeedColors.honey);
    canvas.drawOval(bodyRect, stroke);

    // Kaki
    for (final dx in [-0.13, 0.13]) {
      canvas.drawCircle(
        Offset(cx + dx * s, bodyRect.bottom + s * 0.01),
        s * 0.065,
        Paint()..color = SeedColors.honey,
      );
    }

    final eyeY = bodyCy - bodyH * 0.10;
    final eyeDx = bodyW * 0.18;
    final eyeR = s * 0.028;
    final dot = Paint()..color = ink;

    switch (mood) {
      case MascotMood.idle:
        canvas.drawCircle(Offset(cx - eyeDx, eyeY), eyeR, dot);
        canvas.drawCircle(Offset(cx + eyeDx, eyeY), eyeR, dot);
        _arc(
          canvas,
          Offset(cx, bodyCy + bodyH * 0.10),
          bodyW * 0.14,
          0.25,
          stroke,
        );
      case MascotMood.happy:
        canvas.drawCircle(Offset(cx - eyeDx, eyeY), eyeR, dot);
        canvas.drawCircle(Offset(cx + eyeDx, eyeY), eyeR, dot);
        _arc(
          canvas,
          Offset(cx, bodyCy + bodyH * 0.08),
          bodyW * 0.18,
          0.7,
          stroke,
        );
      case MascotMood.sleepy:
        for (final dx in [-eyeDx, eyeDx]) {
          canvas.drawLine(
            Offset(cx + dx - eyeR, eyeY),
            Offset(cx + dx + eyeR, eyeY),
            stroke,
          );
        }
        _arc(
          canvas,
          Offset(cx, bodyCy + bodyH * 0.16),
          bodyW * 0.08,
          -0.5,
          stroke,
        );
        _drawZzz(canvas, cx + bodyW * 0.38, bodyRect.top - s * 0.06, s);
      case MascotMood.worried:
        // Alis miring ke dalam + mata sayu + mulut cemberut + keringat.
        for (final dx in [-eyeDx, eyeDx]) {
          final inner = cx + dx - (dx.isNegative ? -1 : 1) * eyeR * 0.7;
          canvas.drawLine(
            Offset(cx + dx - eyeR * (dx.isNegative ? 1 : -1), eyeY - eyeR * 2),
            Offset(inner, eyeY - eyeR * 0.9),
            stroke,
          );
          canvas.drawCircle(Offset(cx + dx, eyeY + eyeR * 0.4), eyeR, dot);
        }
        _arc(
          canvas,
          Offset(cx, bodyCy + bodyH * 0.26),
          bodyW * 0.11,
          -0.6,
          stroke,
        );
        // Tetes keringat di pelipis.
        final sweatY =
            bodyRect.top - s * 0.02 + (animate ? math.sin(t * 4 * math.pi) * s * 0.012 : 0);
        final sweat = Rect.fromCenter(
          center: Offset(cx - bodyW * 0.52, sweatY),
          width: s * 0.045,
          height: s * 0.07,
        );
        canvas.drawOval(sweat, Paint()..color = ink.withValues(alpha: 0.55));
      case MascotMood.celebrate:
        for (final dx in [-eyeDx, eyeDx]) {
          _arc(
            canvas,
            Offset(cx + dx, eyeY + eyeR * 0.6),
            eyeR * 1.6,
            1.0,
            stroke,
            flip: true,
          );
        }
        canvas.drawCircle(Offset(cx, bodyCy + bodyH * 0.14), s * 0.035, dot);
        // Konfeti mengorbit pelan
        final colors = Paint();
        for (var i = 0; i < 6; i++) {
          final angle = (animate ? t * 2 * math.pi : 0) + i * math.pi / 3;
          colors.color = _confetti[i % _confetti.length];
          canvas.drawCircle(
            Offset(
              cx + math.cos(angle) * bodyW * 0.62,
              bodyCy + math.sin(angle) * bodyH * 0.85,
            ),
            s * 0.025,
            colors,
          );
        }
    }
    canvas.restore();
  }

  void _arc(
    Canvas canvas,
    Offset center,
    double radius,
    double sweepFactor,
    Paint stroke, {
    bool flip = false,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final start = flip ? math.pi : 0.15 * math.pi;
    final sweep = math.pi * 0.7 * sweepFactor * (flip ? -1 : 1);
    canvas.drawArc(rect, start, sweep, false, stroke);
  }

  void _drawZzz(Canvas canvas, double x, double y, double s) {
    for (var i = 0; i < 3; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'z',
          style: TextStyle(
            fontSize: s * (0.07 + i * 0.03),
            color: ink.withValues(alpha: 0.8 - i * 0.22),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + i * s * 0.09, y - i * s * 0.10));
    }
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) =>
      oldDelegate.mood != mood || oldDelegate.t != t || oldDelegate.ink != ink;
}
