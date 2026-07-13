import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../chat_providers.dart';

/// A lightweight, asset-free piggy-bank mascot for the chat header. Idles
/// (gentle bob + blink), plays a one-shot coin-flip when Hami completes an
/// action, and sleeps (eyes closed + "z z z") when the AI backend is down.
class HamiMascot extends ConsumerStatefulWidget {
  const HamiMascot({super.key, this.size = 52});

  final double size;

  @override
  ConsumerState<HamiMascot> createState() => _HamiMascotState();
}

class _HamiMascotState extends ConsumerState<HamiMascot> with TickerProviderStateMixin {
  late final AnimationController _idle =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  late final AnimationController _flip =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void dispose() {
    _idle.dispose();
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sleeping = ref.watch(chatServersDownProvider);

    // Play the coin-flip once whenever the action counter changes (unless asleep).
    ref.listen<int>(hamiCoinFlipProvider, (_, __) {
      if (!ref.read(chatServersDownProvider)) _flip.forward(from: 0);
    });

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _flip]),
        builder: (context, _) => CustomPaint(
          painter: _PiggyPainter(idle: _idle.value, flip: _flip.value, sleeping: sleeping),
        ),
      ),
    );
  }
}

class _PiggyPainter extends CustomPainter {
  _PiggyPainter({required this.idle, required this.flip, required this.sleeping});

  final double idle; // 0..1 looping
  final double flip; // 0..1 one-shot (0 or 1 == inactive)
  final bool sleeping;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const dark = AppColors.secondary; // brand navy for the eye/details

    // Gentle bob (slower & deeper while asleep).
    final bob = math.sin(idle * 2 * math.pi) * (sleeping ? 1.4 : 0.8);
    canvas.translate(0, bob);

    final gold = Paint()..color = AppColors.primary;
    final goldDark = Paint()..color = AppColors.primaryDark;
    final goldLight = Paint()..color = AppColors.primaryLight;

    // Ear
    final ear = Path()
      ..moveTo(w * 0.30, h * 0.37)
      ..lineTo(w * 0.40, h * 0.19)
      ..lineTo(w * 0.49, h * 0.38)
      ..close();
    canvas.drawPath(ear, goldDark);

    // Legs
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.24, h * 0.72, w * 0.12, h * 0.14), Radius.circular(w * 0.03)),
        goldDark);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.62, h * 0.72, w * 0.12, h * 0.14), Radius.circular(w * 0.03)),
        goldDark);

    // Body
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, h * 0.33, w * 0.76, h * 0.45), Radius.circular(h * 0.22)),
        gold);

    // Snout
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.70, h * 0.49, w * 0.20, h * 0.19), Radius.circular(h * 0.07)),
        goldLight);
    final nostril = Paint()..color = AppColors.primaryDark;
    canvas.drawCircle(Offset(w * 0.77, h * 0.585), w * 0.018, nostril);
    canvas.drawCircle(Offset(w * 0.83, h * 0.585), w * 0.018, nostril);

    // Coin slot
    canvas.drawLine(
      Offset(w * 0.42, h * 0.355),
      Offset(w * 0.58, h * 0.355),
      Paint()
        ..color = AppColors.primaryDark
        ..strokeWidth = h * 0.02
        ..strokeCap = StrokeCap.round,
    );

    // Eye — closed (arc) when sleeping or mid-blink, else a dot.
    final phase = (idle * 2 * math.pi) % (2 * math.pi);
    final blinking = !sleeping && phase > 6.0; // brief blink near the end of each loop
    if (sleeping || blinking) {
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.55, h * 0.46)
          ..quadraticBezierTo(w * 0.60, h * 0.50, w * 0.65, h * 0.46),
        Paint()
          ..color = dark
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.022
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawCircle(Offset(w * 0.60, h * 0.46), w * 0.032, Paint()..color = dark);
    }

    // Coin-flip: a coin descends into the slot, flipping (scaleX oscillates).
    if (flip > 0.0 && flip < 1.0) {
      final y = (h * 0.02) + (h * 0.30 - h * 0.02) * Curves.easeIn.transform(flip);
      final scaleX = math.cos(flip * 4 * math.pi).abs().clamp(0.18, 1.0);
      final r = w * 0.10;
      canvas.save();
      canvas.translate(w * 0.50, y);
      canvas.scale(scaleX, 1.0);
      canvas.drawCircle(Offset.zero, r, Paint()..color = AppColors.primaryLight);
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..color = AppColors.primaryDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.02,
      );
      canvas.restore();
    }

    // Sleeping "z z z"
    if (sleeping) {
      for (var i = 0; i < 3; i++) {
        final prog = (idle + i * 0.33) % 1.0;
        final tp = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: 'z',
            style: TextStyle(
              color: AppColors.primaryDark.withValues(alpha: (1 - prog).clamp(0.0, 1.0)),
              fontSize: w * (0.11 + 0.05 * i),
              fontWeight: FontWeight.bold,
            ),
          ),
        )..layout();
        tp.paint(canvas, Offset(w * 0.70 + i * w * 0.07, h * 0.28 - prog * h * 0.22));
      }
    }
  }

  @override
  bool shouldRepaint(_PiggyPainter old) =>
      old.idle != idle || old.flip != flip || old.sleeping != sleeping;
}
