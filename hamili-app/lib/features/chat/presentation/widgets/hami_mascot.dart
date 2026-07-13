import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../chat_providers.dart';

/// A lightweight, asset-free pink piggy-bank mascot for the chat header. Idles
/// (gentle bob + blink), plays a coin animation when Hami completes an action
/// (a gold coin drops *in* for income, rises *out* for expense), and sleeps
/// (eyes closed + "z z z") when the AI backend is down.
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
  bool _reverse = false;

  @override
  void dispose() {
    _idle.dispose();
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sleeping = ref.watch(chatServersDownProvider);

    // Play the coin animation whenever the action signal changes (unless asleep).
    // Expense actions play in reverse (coin taken out of the piggy).
    ref.listen<CoinFlip>(hamiCoinFlipProvider, (_, next) {
      if (!ref.read(chatServersDownProvider)) {
        _reverse = next.reverse;
        _flip.forward(from: 0);
      }
    });

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _flip]),
        builder: (context, _) => CustomPaint(
          painter: _PiggyPainter(idle: _idle.value, flip: _flip.value, reverse: _reverse, sleeping: sleeping),
        ),
      ),
    );
  }
}

class _PiggyPainter extends CustomPainter {
  _PiggyPainter({required this.idle, required this.flip, required this.reverse, required this.sleeping});

  final double idle; // 0..1 looping
  final double flip; // 0..1 one-shot (0 or 1 == inactive)
  final bool reverse; // coin comes out (expense) instead of in (income)
  final bool sleeping;

  // Normal pig pinks; coin stays gold so "money" reads against the pink.
  static const Color _body = Color(0xFFF4A6C0);
  static const Color _snout = Color(0xFFF8C6D8);
  static const Color _darkPink = Color(0xFFE07BA0);
  static const Color _coinFill = Color(0xFFFFD86B);
  static const Color _coinEdge = Color(0xFFE0A700);
  static const Color _eye = AppColors.secondary; // brand navy

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Gentle bob (slower & deeper while asleep).
    final bob = math.sin(idle * 2 * math.pi) * (sleeping ? 1.4 : 0.8);
    canvas.translate(0, bob);

    final body = Paint()..color = _body;
    final dark = Paint()..color = _darkPink;

    // Legs
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.24, h * 0.72, w * 0.12, h * 0.14), Radius.circular(w * 0.03)),
        dark);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.62, h * 0.72, w * 0.12, h * 0.14), Radius.circular(w * 0.03)),
        dark);

    // Body (rounded rectangle — the original shape, minus the triangle)
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, h * 0.33, w * 0.76, h * 0.45), Radius.circular(h * 0.22)),
        body);

    // Snout with nostrils
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.70, h * 0.49, w * 0.20, h * 0.19), Radius.circular(h * 0.07)),
        Paint()..color = _snout);
    canvas.drawCircle(Offset(w * 0.77, h * 0.585), w * 0.018, dark);
    canvas.drawCircle(Offset(w * 0.83, h * 0.585), w * 0.018, dark);

    // Coin slot
    canvas.drawLine(
      Offset(w * 0.42, h * 0.355),
      Offset(w * 0.58, h * 0.355),
      Paint()
        ..color = _darkPink
        ..strokeWidth = h * 0.02
        ..strokeCap = StrokeCap.round,
    );

    // Eye — closed (arc) when sleeping or mid-blink, else a dot.
    final phase = (idle * 2 * math.pi) % (2 * math.pi);
    final blinking = !sleeping && phase > 6.0;
    if (sleeping || blinking) {
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.55, h * 0.46)
          ..quadraticBezierTo(w * 0.60, h * 0.50, w * 0.65, h * 0.46),
        Paint()
          ..color = _eye
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.022
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawCircle(Offset(w * 0.60, h * 0.46), w * 0.032, Paint()..color = _eye);
    }

    // Coin animation: income drops the coin into the slot; expense lifts it out
    // (and fades) — "taking a coin from inside him".
    if (flip > 0.0 && flip < 1.0) {
      final top = h * 0.02;
      final slot = h * 0.30;
      final e = Curves.easeIn.transform(flip);
      final y = reverse ? slot + (top - slot) * e : top + (slot - top) * e;
      final scaleX = math.cos(flip * 4 * math.pi).abs().clamp(0.18, 1.0);
      final a = reverse ? (1 - flip).clamp(0.0, 1.0) : 1.0;
      final r = w * 0.10;
      canvas.save();
      canvas.translate(w * 0.50, y);
      canvas.scale(scaleX, 1.0);
      canvas.drawCircle(Offset.zero, r, Paint()..color = _coinFill.withValues(alpha: a));
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..color = _coinEdge.withValues(alpha: a)
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
              color: _darkPink.withValues(alpha: (1 - prog).clamp(0.0, 1.0)),
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
      old.idle != idle || old.flip != flip || old.reverse != reverse || old.sleeping != sleeping;
}
