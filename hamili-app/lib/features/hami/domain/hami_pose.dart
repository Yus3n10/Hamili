import 'dart:ui';

import 'hami_definition.dart';

// Units are the Lab's: its head is 250 wide, Hami's painter works in a
// 100-unit box.
const double _labToPainter = 100 / 250;

/// Everything the painter needs for one frame of Hami's face, interpolatable
/// between expressions.
class HamiPose {
  final double pitch;
  final double yaw;
  final double roll;
  // Eye width relative to the resting face; above ~1.4 the eyes go googly.
  final double eyeScale;
  // Left eye/brow angle in degrees; the right side mirrors it. Positive
  // slants the brows down toward the snout (angry), negative raises the
  // inner ends (worried).
  final double eyeAngle;
  final double eyeLift;
  final double eyeSpread;
  final double eyeOpen;
  final double mouth;
  final double hop;
  final double shake;
  final double eyeJitter;
  final double steam;
  final double breath;
  final Color skin;

  const HamiPose({
    this.pitch = 0,
    this.yaw = 0,
    this.roll = 0,
    this.eyeScale = 1,
    this.eyeAngle = 0,
    this.eyeLift = 0,
    this.eyeSpread = 0,
    this.eyeOpen = 1,
    this.mouth = 0,
    this.hop = 0,
    this.shake = 0,
    this.eyeJitter = 0,
    this.steam = 0,
    this.breath = 0,
    required this.skin,
  });

  /// Brow strength from the eye angle: 1 fully angry, -1 fully worried.
  double get brow => (eyeAngle / 24).clamp(-1.0, 1.0);

  bool get isGoogly => eyeScale > 1.4;

  static HamiPose lerp(HamiPose a, HamiPose b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return HamiPose(
      pitch: l(a.pitch, b.pitch),
      yaw: l(a.yaw, b.yaw),
      roll: l(a.roll, b.roll),
      eyeScale: l(a.eyeScale, b.eyeScale),
      eyeAngle: l(a.eyeAngle, b.eyeAngle),
      eyeLift: l(a.eyeLift, b.eyeLift),
      eyeSpread: l(a.eyeSpread, b.eyeSpread),
      eyeOpen: l(a.eyeOpen, b.eyeOpen),
      mouth: l(a.mouth, b.mouth),
      hop: l(a.hop, b.hop),
      shake: l(a.shake, b.shake),
      eyeJitter: l(a.eyeJitter, b.eyeJitter),
      steam: l(a.steam, b.steam),
      breath: l(a.breath, b.breath),
      skin: Color.lerp(a.skin, b.skin, t.clamp(0.0, 1.0))!,
    );
  }

  /// The pose with movement removed and only the emotional read kept, for
  /// reduced-motion users.
  HamiPose stilled() => HamiPose(
        eyeScale: eyeScale,
        eyeAngle: eyeAngle,
        eyeLift: eyeLift,
        eyeSpread: eyeSpread,
        eyeOpen: eyeOpen,
        mouth: mouth,
        steam: steam,
        skin: skin,
      );

  HamiPose copyWith({double? eyeOpen, double? steam}) => HamiPose(
        pitch: pitch,
        yaw: yaw,
        roll: roll,
        eyeScale: eyeScale,
        eyeAngle: eyeAngle,
        eyeLift: eyeLift,
        eyeSpread: eyeSpread,
        eyeOpen: eyeOpen ?? this.eyeOpen,
        mouth: mouth,
        hop: hop,
        shake: shake,
        eyeJitter: eyeJitter,
        steam: steam ?? this.steam,
        breath: breath,
        skin: skin,
      );
}

/// Face details the Lab's format has no field for: it stores one body
/// colour and plain eyes, so eyelid narrowing, the small mouth, the
/// celebratory hop, steam and breathing are kept here per expression name.
class _FaceExtras {
  final double eyeOpen;
  final double mouth;
  final double hop;
  final double steam;
  final double breath;

  const _FaceExtras({this.eyeOpen = 1, this.mouth = 0, this.hop = 0, this.steam = 0, this.breath = 0});
}

const Map<String, _FaceExtras> _extras = {
  'breathe': _FaceExtras(breath: 1),
  'angry': _FaceExtras(eyeOpen: 0.62, mouth: -0.6),
  'angry-glare': _FaceExtras(eyeOpen: 0.48, mouth: -0.8, steam: 1),
  'excited': _FaceExtras(mouth: 1, hop: 3),
  'excited-wide': _FaceExtras(mouth: 1, hop: 7),
  'nod-down': _FaceExtras(mouth: 0.8),
  'nod-up': _FaceExtras(mouth: 0.8),
  'shake-left': _FaceExtras(eyeOpen: 0.72, mouth: -0.35),
  'shake-right': _FaceExtras(eyeOpen: 0.72, mouth: -0.35),
  'worried': _FaceExtras(mouth: -0.5),
  'worried-glance': _FaceExtras(mouth: -0.5),
};

double _motionAmount(String motion) => switch (motion) {
      'shake' => 1.0,
      'microSaccades' => 0.5,
      'slowDrift' => 0.25,
      _ => 0.0,
    };

HamiPose poseFor(HamiDefinition def, String expressionName) {
  final rest = def.rest;
  final e = def.expressions[expressionName] ?? rest;
  final extra = _extras[e.name] ?? const _FaceExtras();
  return HamiPose(
    pitch: e.headX,
    yaw: e.headY,
    roll: e.headZ,
    eyeScale: e.left.width / rest.left.width,
    eyeAngle: e.left.angle,
    // The Lab's y grows downward like the canvas, so a smaller y sits higher.
    eyeLift: (e.left.y - rest.left.y) * _labToPainter,
    eyeSpread: (e.spacing - rest.spacing) * _labToPainter / 2,
    eyeOpen: extra.eyeOpen,
    mouth: extra.mouth,
    hop: extra.hop,
    shake: _motionAmount(e.bodyMotion),
    eyeJitter: _motionAmount(e.eyeMotion),
    steam: extra.steam,
    breath: extra.breath,
    skin: e.bodyColor ?? def.bodyColor,
  );
}
