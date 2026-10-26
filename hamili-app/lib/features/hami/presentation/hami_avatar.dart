import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/hami_definition.dart';
import '../domain/hami_pose.dart';
import '../domain/hami_reaction.dart';
import '../domain/hami_timeline.dart';
import 'hami_controller.dart';

/// A coin dropping into (or, reversed, out of) Hami, shown after he
/// completes a chat action.
typedef HamiCoin = ({int seq, bool reverse});

/// Hami, the pig mascot. Plays whatever reaction [hamiControllerProvider]
/// holds, idles between reactions, and honours reduced motion by showing a
/// still expression instead.
class HamiAvatar extends ConsumerStatefulWidget {
  const HamiAvatar({super.key, this.size = 52, this.sleeping = false, this.coin, this.reactive = true});

  final double size;
  final bool sleeping;
  final HamiCoin? coin;
  // False keeps Hami idle, for decorative spots like onboarding.
  final bool reactive;

  @override
  ConsumerState<HamiAvatar> createState() => _HamiAvatarState();
}

class _HamiAvatarState extends ConsumerState<HamiAvatar> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _random = math.Random();
  late final ValueNotifier<HamiFrame?> _frame = ValueNotifier(null);

  HamiDefinition? _def;
  bool _reduced = false;
  HamiPlayback _playback = const HamiPlayback(HamiReaction.idle, 0);
  int _nowMs = 0;
  int _startMs = 0;
  HamiPose? _from;
  HamiPose? _lastPose;
  int _nextBlinkMs = 0;
  int _blinkStartMs = -1;
  int _coinStartMs = -1;
  int? _coinSeq;

  @override
  void initState() {
    super.initState();
    _coinSeq = widget.coin?.seq;
    if (widget.reactive) _playback = ref.read(hamiControllerProvider);
  }

  @override
  void didUpdateWidget(HamiAvatar old) {
    super.didUpdateWidget(old);
    final coin = widget.coin;
    if (coin != null && coin.seq != _coinSeq) {
      _coinSeq = coin.seq;
      _coinStartMs = _nowMs;
    }
    if (old.sleeping != widget.sleeping) _render();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _start(HamiPlayback playback) {
    _from = _lastPose;
    _playback = playback;
    _startMs = _nowMs;
    final idle = _def?.animations['idle'];
    if (playback.isIdle && idle != null) _nextBlinkMs = _nowMs + idle.blink.initialDelayMs;
    _render();
  }

  void _tick(Duration elapsed) {
    _nowMs = elapsed.inMilliseconds;
    _render();
  }

  void _render() {
    final def = _def;
    if (def == null) return;
    HamiPose pose;
    final anim = def.animations[_playback.reaction.animation];
    if (_reduced) {
      pose = _playback.isIdle || anim == null ? poseFor(def, def.rest.name).stilled() : peakPose(def, anim);
    } else if (anim == null) {
      pose = poseFor(def, def.rest.name);
    } else {
      pose = evaluate(def, anim, _nowMs - _startMs, from: _from);
      if (_playback.isIdle) pose = pose.copyWith(eyeOpen: pose.eyeOpen * _blink(anim.blink));
    }
    if (!_playback.reaction.intense) pose = pose.copyWith(steam: 0);
    _lastPose = pose;

    final coinMs = _nowMs - _coinStartMs;
    _frame.value = HamiFrame(
      pose: pose,
      timeMs: _reduced ? 0 : _nowMs,
      eyeColor: def.eyeColor,
      sleeping: widget.sleeping,
      coin: _coinStartMs < 0 || _reduced ? 0 : (coinMs / 900).clamp(0.0, 1.0),
      coinReverse: widget.coin?.reverse ?? false,
    );
  }

  double _blink(HamiBlink blink) {
    if (!blink.enabled || widget.sleeping) return 1;
    if (_nowMs >= _nextBlinkMs) {
      _blinkStartMs = _nowMs;
      final spread = math.max(0, blink.maxIntervalMs - blink.minIntervalMs);
      _nextBlinkMs = _nowMs + blink.minIntervalMs + (spread == 0 ? 0 : _random.nextInt(spread));
    }
    return _blinkStartMs < 0 ? 1 : blinkOpenness(_nowMs - _blinkStartMs, blink.durationMs);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reactive) {
      ref.listen<HamiPlayback>(hamiControllerProvider, (_, next) => _start(next));
    }
    final def = ref.watch(hamiDefinitionProvider).valueOrNull;
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final changed = def != _def || reduced != _reduced;
    _def = def;
    _reduced = reduced;
    if (def != null && changed) {
      // Start from the resting face, not mid-breath.
      _from ??= poseFor(def, def.rest.name);
      if (reduced) {
        if (_ticker.isActive) _ticker.stop();
      } else if (!_ticker.isActive) {
        _nowMs = 0;
        _startMs = 0;
        _coinStartMs = -1;
        _ticker.start();
      }
      _render();
    }

    return Semantics(
      image: true,
      label: 'Hami',
      value: describeHamiReaction(_playback.reaction, sleeping: widget.sleeping),
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: widget.size,
          child: def == null ? null : CustomPaint(painter: HamiPainter(_frame)),
        ),
      ),
    );
  }
}

String? describeHamiReaction(HamiReaction reaction, {bool sleeping = false}) {
  if (sleeping) return 'napping';
  return switch (reaction) {
    HamiReaction.idle => null,
    HamiReaction.budgetConcern => 'looking worried',
    HamiReaction.celebrateIncome => 'happy about the income',
    HamiReaction.celebrateSavings => 'excited about the savings',
    HamiReaction.answerYes => 'nodding yes',
    HamiReaction.answerNo => 'shaking his head no',
    HamiReaction.warnSpending => 'angry about the spending',
    HamiReaction.overBudget => 'fuming, over budget',
  };
}

@immutable
class HamiFrame {
  final HamiPose pose;
  final int timeMs;
  final Color eyeColor;
  final bool sleeping;
  final double coin;
  final bool coinReverse;

  const HamiFrame({
    required this.pose,
    required this.timeMs,
    required this.eyeColor,
    this.sleeping = false,
    this.coin = 0,
    this.coinReverse = false,
  });
}

Color _shade(Color color, double lightness, {double saturation = 1}) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness((hsl.lightness + lightness).clamp(0.0, 1.0))
      .withSaturation((hsl.saturation * saturation).clamp(0.0, 1.0))
      .toColor();
}

Path _roundedTriangle(List<Offset> points, double radius) {
  final path = Path();
  for (var i = 0; i < 3; i++) {
    final prev = points[(i + 2) % 3];
    final cur = points[i];
    final next = points[(i + 1) % 3];
    Offset toward(Offset from, Offset to) {
      final d = to - from;
      return from + d / d.distance * math.min(radius, d.distance / 2);
    }

    final a = toward(cur, prev);
    final b = toward(cur, next);
    if (i == 0) {
      path.moveTo(a.dx, a.dy);
    } else {
      path.lineTo(a.dx, a.dy);
    }
    path.quadraticBezierTo(cur.dx, cur.dy, b.dx, b.dy);
  }
  return path..close();
}

/// Paints Hami in a 100-unit box: one round pink silhouette, triangular ears
/// with darker insides, a large snout with oval nostrils and small dark eyes.
class HamiPainter extends CustomPainter {
  HamiPainter(this.frame) : super(repaint: frame);

  final ValueListenable<HamiFrame?> frame;

  static const _center = Offset(50, 58);

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame.value;
    if (f == null) return;
    final p = f.pose;
    final t = f.timeMs / 1000;

    canvas.save();
    canvas.scale(size.shortestSide / 100);

    final shakeX = p.shake * 1.8 * math.sin(t * 2 * math.pi * 14);
    canvas.translate(shakeX, -p.hop - p.breath * 0.6);
    canvas.translate(50, 94);
    canvas.scale(1 + p.breath * 0.012, 1 + p.breath * 0.022);
    canvas.translate(-50, -94);
    // A turn also tilts and shifts the whole head and a nod dips it, so a
    // head shake or nod reads clearly even at chat-header size.
    canvas.translate(p.yaw * 0.12, -p.pitch * 0.3);
    canvas.translate(_center.dx, _center.dy);
    canvas.rotate((p.roll + p.yaw * 0.3) * math.pi / 180);
    canvas.translate(-_center.dx, -_center.dy);

    final skin = p.skin;
    final earInner = _shade(skin, -0.15);
    final snout = _shade(skin, -0.11);
    final nostril = _shade(skin, -0.33, saturation: 0.55);

    // Ears sit behind the head and drift a little against a turn or nod.
    final earShift = Offset(-p.yaw * 0.06, p.pitch * 0.08);
    for (final side in const [-1.0, 1.0]) {
      Offset at(double x, double y) => Offset(50 + side * (50 - x), y) + earShift;
      canvas.drawPath(_roundedTriangle([at(12, 12), at(42, 25), at(16, 50)], 4), Paint()..color = skin);
      canvas.drawPath(_roundedTriangle([at(17.5, 19), at(35, 27.5), at(19.5, 42)], 3), Paint()..color = earInner);
    }

    final headScaleX = 1 - p.yaw.abs() * 0.0015;
    final headScaleY = 1 - p.pitch.abs() * 0.001;
    canvas.drawOval(
      Rect.fromCenter(center: _center, width: 74 * headScaleX, height: 71 * headScaleY),
      Paint()..color = skin,
    );

    // Features ride on the turn and nod; the snout is closer, so it moves more.
    final face = Offset(p.yaw * 0.4, -p.pitch * 0.3);
    final snoutShift = Offset(p.yaw * 0.5, -p.pitch * 0.38);

    final eyePaint = Paint()..color = f.eyeColor;
    for (final side in const [-1.0, 1.0]) {
      final eye = Offset(50 + side * (14 + p.eyeSpread), 46 + p.eyeLift) + face;
      final angle = p.eyeAngle * math.pi / 180 * -side;
      _paintEye(canvas, f, eye, angle, side, t, eyePaint);
      _paintBrow(canvas, f, eye, angle);
    }

    final snoutCenter = const Offset(50, 70) + snoutShift;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: snoutCenter, width: 36, height: 25), const Radius.elliptical(16, 12.5)),
      Paint()..color = snout,
    );
    for (final side in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(snoutCenter.dx + side * 5.5, snoutCenter.dy - 0.5);
      canvas.rotate(side * 0.14);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 4.6, height: 7.4), Paint()..color = nostril);
      canvas.restore();
    }

    if (p.mouth.abs() > 0.05) {
      final y = 86.5 + snoutShift.dy * 0.6;
      final x = 50 + snoutShift.dx;
      canvas.drawPath(
        Path()
          ..moveTo(x - 5, y)
          ..quadraticBezierTo(x, y + p.mouth * 4, x + 5, y),
        Paint()
          ..color = f.eyeColor.withValues(alpha: 0.85 * p.mouth.abs().clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }

    if (p.steam > 0) {
      for (final side in const [-1.0, 1.0]) {
        final vent = Offset(50 + side * 22, 22) + earShift;
        for (var i = 0; i < 3; i++) {
          final prog = (t / 0.9 + i / 3) % 1;
          canvas.drawCircle(
            vent + Offset(side * 3 * prog, -prog * 16),
            2 + prog * 2.5,
            Paint()..color = const Color(0xFFB4B4B4).withValues(alpha: p.steam * (1 - prog) * 0.75),
          );
        }
      }
    }

    canvas.restore();

    if (f.coin > 0 && f.coin < 1) _paintCoin(canvas, size, f);
    if (f.sleeping) _paintSleep(canvas, size, t, skin);
  }

  void _paintEye(Canvas canvas, HamiFrame f, Offset eye, double angle, double side, double t, Paint eyePaint) {
    final p = f.pose;
    final open = f.sleeping ? 0.0 : p.eyeOpen.clamp(0.0, 1.0);
    final width = 6 * p.eyeScale;
    final height = 8 * p.eyeScale * open;

    canvas.save();
    canvas.translate(eye.dx, eye.dy);
    canvas.rotate(angle);
    if (height < 1.2) {
      canvas.drawPath(
        Path()
          ..moveTo(-width / 2, 0)
          ..quadraticBezierTo(0, 2, width / 2, 0),
        Paint()
          ..color = f.eyeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
      return;
    }

    // Wide eyes go googly; narrowed ones (anger, a squint) stay solid slits.
    final googly = ((p.eyeScale - 1.3) / 0.45).clamp(0.0, 1.0) * ((p.eyeOpen - 0.8) / 0.2).clamp(0.0, 1.0);
    if (googly > 0) {
      final r = width / 2;
      canvas.drawCircle(Offset.zero, r * 1.08, Paint()..color = Colors.white.withValues(alpha: googly));
      final wobble = Offset(math.sin(t * 31 + side) * 0.7, math.cos(t * 23 + side) * 0.6) * p.eyeJitter * p.eyeScale;
      final pupil = r * (1 - 0.42 * googly);
      canvas.drawOval(
        Rect.fromCenter(center: wobble, width: pupil * 2, height: pupil * 2 * (height / width).clamp(0.6, 1.4)),
        eyePaint,
      );
      canvas.drawCircle(wobble + Offset(-pupil * 0.35, -pupil * 0.4), pupil * 0.3, Paint()..color = Colors.white);
    } else {
      final jitter = Offset(math.sin(t * 29 + side) * 0.35, 0) * p.eyeJitter;
      canvas.drawOval(Rect.fromCenter(center: jitter, width: width, height: height), eyePaint);
    }
    canvas.restore();
  }

  void _paintBrow(Canvas canvas, HamiFrame f, Offset eye, double angle) {
    final strength = ((f.pose.brow.abs() - 0.12) / 0.35).clamp(0.0, 1.0);
    if (strength == 0 || f.sleeping) return;
    final lift = 4 * f.pose.eyeScale * f.pose.eyeOpen.clamp(0.4, 1.0) + 3.5;
    canvas.save();
    canvas.translate(eye.dx, eye.dy - lift);
    canvas.rotate(angle);
    canvas.drawLine(
      const Offset(-4.5, 0),
      const Offset(4.5, 0),
      Paint()
        ..color = f.eyeColor.withValues(alpha: strength)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _paintCoin(Canvas canvas, Size size, HamiFrame f) {
    final w = size.width;
    final h = size.height;
    final top = h * 0.0;
    final slot = h * 0.24;
    final e = Curves.easeIn.transform(f.coin);
    final y = f.coinReverse ? slot + (top - slot) * e : top + (slot - top) * e;
    final scaleX = math.cos(f.coin * 4 * math.pi).abs().clamp(0.18, 1.0);
    final a = f.coinReverse ? (1 - f.coin).clamp(0.0, 1.0) : 1.0;
    final r = w * 0.09;
    canvas.save();
    canvas.translate(w * 0.5, y);
    canvas.scale(scaleX, 1.0);
    canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFFFFD86B).withValues(alpha: a));
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..color = const Color(0xFFE0A700).withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02,
    );
    canvas.restore();
  }

  void _paintSleep(Canvas canvas, Size size, double t, Color skin) {
    final w = size.width;
    final h = size.height;
    final color = _shade(skin, -0.3);
    for (var i = 0; i < 3; i++) {
      final prog = (t / 3 + i * 0.33) % 1.0;
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: 'z',
          style: TextStyle(
            color: color.withValues(alpha: (1 - prog).clamp(0.0, 1.0)),
            fontSize: w * (0.11 + 0.05 * i),
            fontWeight: FontWeight.bold,
          ),
        ),
      )..layout();
      tp.paint(canvas, Offset(w * 0.72 + i * w * 0.07, h * 0.22 - prog * h * 0.2));
    }
  }

  @override
  bool shouldRepaint(HamiPainter old) => old.frame != frame;
}
