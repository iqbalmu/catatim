import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/quest.dart';
import '../theme/tokens.dart';

enum MascotMood { idle, happy, sleepy, celebrate, worried, broke }

/// Peta mood → aset raster (render 3D "Pochy", dikompres WebP).
///
/// Semua mood kini tampil sebagai render 3D: mood tanpa aset spesifik
/// memakai raster terdekat ([MascotMood.idle] dan [MascotMood.sleepy]
/// memakai wajah happy). Lukisan vektor hanya fallback terakhir bila
/// aset gagal dimuat — bukan gaya kedua.
const Map<MascotMood, String> _assetFor = {
  MascotMood.happy: 'assets/mascot/mascot_happy.webp',
  MascotMood.celebrate: 'assets/mascot/mascot_celebrate.webp',
  MascotMood.worried: 'assets/mascot/mascot_worried.webp',
  MascotMood.broke: 'assets/mascot/mascot_broke.webp',
  MascotMood.idle: 'assets/mascot/mascot_happy.webp',
  MascotMood.sleepy: 'assets/mascot/mascot_happy.webp',
};

/// Maskot "Duit" — Pochy, karung uang.
///
/// Mood yang punya aset 3D tampil sebagai gambar dengan bob halus
/// (hormat ke `disableAnimations`); mood lain dilukis vektor dengan
/// bentuk & warna Pochy yang sama.
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
    final asset = _assetFor[widget.mood];

    if (asset != null) {
      final image = Image.asset(
        asset,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        width: widget.size,
        height: widget.size,
        // Aset hilang → tetap pakai lukisan vektor, bukan kotak kosong.
        errorBuilder: (context, error, stack) => _vector(context),
      );
      if (MediaQuery.disableAnimationsOf(context)) return image;
      // Bob pelan (amplitudo 2% sisi) — meniru vektor.
      return AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final bob = math.sin(_ctrl.value * 2 * math.pi) * widget.size * 0.02;
          return Transform.translate(offset: Offset(0, bob), child: image);
        },
      );
    }

    return _vector(context);
  }

  Widget _vector(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return CustomPaint(
        size: Size.square(widget.size),
        painter: _PochyPainter(mood: widget.mood, t: 0.25, animate: false),
      );
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _PochyPainter(
          mood: widget.mood,
          t: _ctrl.value,
          animate: true,
        ),
      ),
    );
  }
}

/// Panggung maskot: latar lembut yang mengikuti ekspresi + bayangan
/// tanah. Warna & kekuatan dipetakan dari mood di satu tempat; puncak
/// alpha sengaja rendah (≤ 0,30) — halo terang justru menelan warna
/// render 3D maskot. Dipakai di hero & meter agar Duit terasa
/// "berpanggung", bukan tempelan kecil di sudut kartu.
class MascotStage extends StatelessWidget {
  const MascotStage({super.key, required this.mood, this.size = 124});

  final MascotMood mood;
  final double size;

  /// Warna & kekuatan latar per ekspresi:
  /// celebrate merayakan (emas), happy/positif (teal), broke merah
  /// seperti label defisit, worried amber waspada, sisanya netral.
  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final (tint, strength) = switch (mood) {
      MascotMood.celebrate => (SeedColors.honeyBright, 0.30),
      MascotMood.happy => (q.good, 0.22),
      MascotMood.worried => (q.warn, 0.22),
      MascotMood.broke => (q.bad, 0.22),
      MascotMood.idle => (q.surface, 0.40),
      MascotMood.sleepy => (q.surface, 0.25),
    };
    return SizedBox(
      width: size * 1.08,
      height: size + 16,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Latar ekspresi — kabur lembut di belakang karakter.
          Positioned(
            bottom: 2,
            child: Container(
              width: size * 0.94,
              height: size * 0.94,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    tint.withValues(alpha: strength),
                    tint.withValues(alpha: 0),
                  ],
                  stops: const [0.4, 1],
                ),
              ),
            ),
          ),
          // Bayangan tanah — tumit karakter ke panggung.
          Positioned(
            bottom: 0,
            child: Container(
              width: size * 0.5,
              height: size * 0.1,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x3D6B4937), Color(0x006B4937)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Mascot(mood: mood, size: size),
          ),
        ],
      ),
    );
  }
}

/// Pochy versi vektor: karung burlap, tali cokelat, syal teal, koin emas.
/// Warna diambil dari palet ADR-010 supaya sama dengan render 3D.
class _PochyPainter extends CustomPainter {
  _PochyPainter({required this.mood, required this.t, required this.animate});

  final MascotMood mood;
  final double t;
  final bool animate;

  /// Warna diambil langsung dari logo aplikasi (karung burlap, tali,
  /// syal teal + orana, koin emas) supaya maskot identik dengan logo.
  static const _burlap = Color(0xFFD7B285);
  static const _burlapDeep = Color(0xFFBF946F);
  static const _rope = Color(0xFF6B4937);
  static const _scarf = Color(0xFF499B8F);
  static const _scarfWarm = Color(0xFFEA732E);
  static const _coin = Color(0xFFFAC750);
  static const _coinDeep = Color(0xFFCB8F21);
  static const _blush = Color(0xFFF2A69E);

  static const _confetti = [
    Color(0xFFF77168), // koral teks "In" logo
    Color(0xFFEA732E), // orana syal
    Color(0xFF499B8F), // teal syal
    Color(0xFF628F63), // hijau daun grafik
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;

    final amp = mood == MascotMood.sleepy ? s * 0.010 : s * 0.018;
    final bob = animate ? math.sin(t * 2 * math.pi) * amp : 0.0;
    final breathe = animate ? 1 + 0.025 * math.sin(t * 2 * math.pi) : 1.0;

    // Kerangka karakter (fraksi sisi kanvas).
    final knotTop = s * 0.11;
    final neckY = s * 0.28;
    final neckHalf = s * 0.085;
    final bodyHalf = s * 0.26;
    final midY = s * 0.56;
    final bottomY = s * 0.84;

    canvas.save();
    canvas.translate(cx, size.height / 2);
    canvas.scale(breathe);
    canvas.translate(-cx, -size.height / 2);
    canvas.translate(0, bob);

    final stroke = Paint()
      ..color = _rope
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.026
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Kaki
    for (final dx in [-bodyHalf * 0.36, bodyHalf * 0.36]) {
      _blob(
        canvas,
        Offset(cx + dx, bottomY + s * 0.022),
        s * 0.105,
        s * 0.062,
        _burlap,
        stroke,
      );
    }

    // Lengan kiri (besar, di belakang badan)
    _blob(
      canvas,
      Offset(cx - bodyHalf * 0.94, midY - s * 0.02),
      s * 0.085,
      s * 0.13,
      _burlap,
      stroke,
    );
    // Lengan kanan (pegang koin)
    _blob(
      canvas,
      Offset(cx + bodyHalf * 0.96, midY - s * 0.05),
      s * 0.085,
      s * 0.13,
      _burlap,
      stroke,
    );

    // Badan: karung — leher sempit, perut melebar, dasar bulat.
    final bag = Path()
      ..moveTo(cx - neckHalf, neckY)
      ..lineTo(cx + neckHalf, neckY)
      ..cubicTo(
        cx + neckHalf * 2.0,
        neckY + s * 0.06,
        cx + bodyHalf,
        midY - s * 0.12,
        cx + bodyHalf,
        midY,
      )
      ..cubicTo(
        cx + bodyHalf,
        midY + s * 0.16,
        cx + bodyHalf * 0.74,
        bottomY,
        cx,
        bottomY,
      )
      ..cubicTo(
        cx - bodyHalf * 0.74,
        bottomY,
        cx - bodyHalf,
        midY + s * 0.16,
        cx - bodyHalf,
        midY,
      )
      ..cubicTo(
        cx - bodyHalf,
        midY - s * 0.12,
        cx - neckHalf * 2.0,
        neckY + s * 0.06,
        cx - neckHalf,
        neckY,
      )
      ..close();
    canvas.drawPath(
      bag,
      Paint()
        ..shader =
            const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_burlap, _burlapDeep],
            ).createShader(
              Rect.fromLTRB(cx - bodyHalf, knotTop, cx + bodyHalf, bottomY),
            ),
    );
    canvas.drawPath(bag, stroke);

    // Simpul ikat atas
    final knot = Rect.fromCenter(
      center: Offset(cx, (knotTop + neckY) / 2),
      width: neckHalf * 1.7,
      height: neckY - knotTop,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(knot, Radius.circular(s * 0.035)),
      Paint()..color = _burlapDeep,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(knot, Radius.circular(s * 0.035)),
      stroke,
    );

    // Tali cokelat mengikat leher
    final ropeBand = Rect.fromCenter(
      center: Offset(cx, neckY + s * 0.012),
      width: neckHalf * 2.7,
      height: s * 0.052,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(ropeBand, Radius.circular(s * 0.026)),
      Paint()..color = _rope,
    );

    // Syal teal + garis hangat, dengan ujung menjuntai
    final scarfY = neckY + s * 0.085;
    final scarfRect = Rect.fromCenter(
      center: Offset(cx, scarfY),
      width: neckHalf * 3.7,
      height: s * 0.078,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(scarfRect, Radius.circular(s * 0.032)),
      Paint()..color = _scarf,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, scarfY),
          width: neckHalf * 3.7,
          height: s * 0.022,
        ),
        Radius.circular(s * 0.011),
      ),
      Paint()..color = _scarfWarm,
    );
    final tail = Rect.fromCenter(
      center: Offset(cx + neckHalf * 1.35, scarfY + s * 0.085),
      width: s * 0.052,
      height: s * 0.115,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tail, Radius.circular(s * 0.026)),
      Paint()..color = _scarf,
    );

    // Koin emas di tangan
    final coinCenter = Offset(cx + bodyHalf * 0.98, midY - s * 0.14);
    final coinR = s * 0.095;
    canvas.drawCircle(coinCenter, coinR, Paint()..color = _coin);
    canvas.drawCircle(
      coinCenter,
      coinR,
      Paint()
        ..color = _coinDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018,
    );
    canvas.drawCircle(
      coinCenter,
      coinR * 0.42,
      Paint()..color = _coinDeep.withValues(alpha: 0.55),
    );

    // Wajah
    final eyeY = midY - s * 0.14;
    final eyeDx = s * 0.088;
    final eyeR = s * 0.031;
    final dot = Paint()..color = _rope;

    for (final dx in [-eyeDx, eyeDx]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + dx * 1.42, eyeY + s * 0.075),
          width: s * 0.07,
          height: s * 0.04,
        ),
        Paint()..color = _blush.withValues(alpha: 0.55),
      );
    }

    switch (mood) {
      case MascotMood.idle:
        _eyesOpen(canvas, cx, eyeY, eyeDx, eyeR, dot);
        _arc(canvas, Offset(cx, eyeY + s * 0.075), s * 0.055, 0.55, stroke);
      case MascotMood.happy:
        _eyesOpen(canvas, cx, eyeY, eyeDx, eyeR, dot);
        _arc(canvas, Offset(cx, eyeY + s * 0.07), s * 0.07, 0.75, stroke);
      case MascotMood.sleepy:
        for (final dx in [-eyeDx, eyeDx]) {
          canvas.drawLine(
            Offset(cx + dx - eyeR, eyeY),
            Offset(cx + dx + eyeR, eyeY),
            stroke,
          );
        }
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, eyeY + s * 0.085),
            width: s * 0.045,
            height: s * 0.055,
          ),
          dot,
        );
        _drawZzz(canvas, cx + bodyHalf * 1.05, neckY - s * 0.02, s);
      case MascotMood.worried || MascotMood.broke:
        _eyesOpen(canvas, cx, eyeY, eyeDx, eyeR, dot);
        // Alis miring ke dalam
        for (final dx in [-eyeDx, eyeDx]) {
          final inner = cx + dx + (dx.isNegative ? eyeR * 0.7 : -eyeR * 0.7);
          canvas.drawLine(
            Offset(cx + dx - (dx.isNegative ? -eyeR : eyeR), eyeY - eyeR * 2.1),
            Offset(inner, eyeY - eyeR * 0.9),
            stroke,
          );
        }
        _arc(canvas, Offset(cx, eyeY + s * 0.135), s * 0.06, -0.55, stroke);
        // Tetes keringat di pelipis
        final sweatY =
            eyeY -
            s * 0.02 +
            (animate ? math.sin(t * 4 * math.pi) * s * 0.012 : 0);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx - bodyHalf * 1.05, sweatY),
            width: s * 0.045,
            height: s * 0.07,
          ),
          Paint()..color = const Color(0x8C7FBDB1),
        );
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
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, eyeY + s * 0.105),
            width: s * 0.075,
            height: s * 0.085,
          ),
          dot,
        );
        // Konfeti mengorbit pelan
        final confettiPaint = Paint();
        for (var i = 0; i < 6; i++) {
          final angle = (animate ? t * 2 * math.pi : 0) + i * math.pi / 3;
          confettiPaint.color = _confetti[i % _confetti.length];
          canvas.drawCircle(
            Offset(
              cx + math.cos(angle) * bodyHalf * 1.28,
              midY + math.sin(angle) * s * 0.2,
            ),
            s * 0.026,
            confettiPaint,
          );
        }
    }

    canvas.restore();
  }

  void _eyesOpen(
    Canvas canvas,
    double cx,
    double eyeY,
    double eyeDx,
    double eyeR,
    Paint dot,
  ) {
    for (final dx in [-eyeDx, eyeDx]) {
      canvas.drawCircle(Offset(cx + dx, eyeY), eyeR, dot);
      canvas.drawCircle(
        Offset(cx + dx - eyeR * 0.3, eyeY - eyeR * 0.35),
        eyeR * 0.32,
        Paint()..color = SeedColors.surface,
      );
    }
  }

  void _blob(
    Canvas canvas,
    Offset center,
    double w,
    double h,
    Color fill,
    Paint stroke,
  ) {
    final rect = Rect.fromCenter(center: center, width: w, height: h);
    canvas.drawOval(rect, Paint()..color = fill);
    canvas.drawOval(rect, stroke);
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
            color: _rope.withValues(alpha: 0.8 - i * 0.22),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + i * s * 0.09, y - i * s * 0.10));
    }
  }

  @override
  bool shouldRepaint(covariant _PochyPainter oldDelegate) =>
      oldDelegate.mood != mood || oldDelegate.t != t;
}
