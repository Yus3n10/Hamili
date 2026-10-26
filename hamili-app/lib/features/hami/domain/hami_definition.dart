import 'dart:convert';

import 'package:flutter/services.dart';

// Hami's behaviour is authored in Bible Strong Avatar Lab and exported as
// assets/hami/hami.avatar.json. This reads that file as data; the Lab's own
// JavaScript runtime is never bundled, so Hamili renders Hami natively.

const hamiDefinitionAsset = 'assets/hami/hami.avatar.json';

class HamiEye {
  final double width;
  final double height;
  final double x;
  final double y;
  final double angle;

  const HamiEye({required this.width, required this.height, required this.x, required this.y, required this.angle});

  factory HamiEye.fromJson(Map<String, dynamic> json) => HamiEye(
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        angle: (json['angle'] as num).toDouble(),
      );
}

class HamiExpression {
  final String name;
  // Head rotation in degrees: x tilts up (+) and down, y turns, z rolls.
  final double headX;
  final double headY;
  final double headZ;
  final HamiEye left;
  final HamiEye right;
  final double spacing;
  final String eyeMotion;
  final String bodyMotion;
  final Color? bodyColor;

  const HamiExpression({
    required this.name,
    required this.headX,
    required this.headY,
    required this.headZ,
    required this.left,
    required this.right,
    required this.spacing,
    required this.eyeMotion,
    required this.bodyMotion,
    this.bodyColor,
  });

  factory HamiExpression.fromJson(String name, Map<String, dynamic> json) {
    final head = json['head'] as Map<String, dynamic>;
    final eyes = json['eyes'] as Map<String, dynamic>;
    final motion = json['motion'] as Map<String, dynamic>? ?? const {};
    final colors = json['colors'] as Map<String, dynamic>?;
    final body = colors?['body'] as String?;
    return HamiExpression(
      name: name,
      headX: (head['x'] as num).toDouble(),
      headY: (head['y'] as num).toDouble(),
      headZ: (head['z'] as num).toDouble(),
      left: HamiEye.fromJson(eyes['left'] as Map<String, dynamic>),
      right: HamiEye.fromJson(eyes['right'] as Map<String, dynamic>),
      spacing: (eyes['spacing'] as num).toDouble(),
      eyeMotion: motion['eyes'] as String? ?? 'none',
      bodyMotion: motion['body'] as String? ?? 'none',
      bodyColor: body == null ? null : parseHexColor(body),
    );
  }
}

class HamiStep {
  final String expression;
  final int holdMs;
  final int transitionMs;
  final String transition;

  const HamiStep({required this.expression, required this.holdMs, required this.transitionMs, required this.transition});

  int get totalMs => transitionMs + holdMs;

  factory HamiStep.fromJson(Map<String, dynamic> json) => HamiStep(
        expression: json['expression'] as String,
        holdMs: (json['holdMs'] as num).round(),
        transitionMs: (json['transitionMs'] as num).round(),
        transition: json['transition'] as String? ?? 'smooth',
      );
}

class HamiBlink {
  final bool enabled;
  final int initialDelayMs;
  final int minIntervalMs;
  final int maxIntervalMs;
  final int durationMs;

  const HamiBlink({
    required this.enabled,
    required this.initialDelayMs,
    required this.minIntervalMs,
    required this.maxIntervalMs,
    required this.durationMs,
  });

  static const off = HamiBlink(enabled: false, initialDelayMs: 0, minIntervalMs: 0, maxIntervalMs: 0, durationMs: 0);

  factory HamiBlink.fromJson(Map<String, dynamic>? json) {
    if (json == null) return off;
    return HamiBlink(
      enabled: json['enabled'] as bool? ?? false,
      initialDelayMs: (json['initialDelayMs'] as num? ?? 0).round(),
      minIntervalMs: (json['minIntervalMs'] as num? ?? 0).round(),
      maxIntervalMs: (json['maxIntervalMs'] as num? ?? 0).round(),
      durationMs: (json['durationMs'] as num? ?? 0).round(),
    );
  }
}

class HamiAnimation {
  final String name;
  // once | loop | pingPong, as the Lab defines them.
  final String playbackMode;
  final List<HamiStep> steps;
  final HamiBlink blink;

  const HamiAnimation({required this.name, required this.playbackMode, required this.steps, required this.blink});

  bool get loops => playbackMode != 'once';

  int get durationMs => steps.fold(0, (sum, s) => sum + s.totalMs);

  factory HamiAnimation.fromJson(String name, Map<String, dynamic> json) => HamiAnimation(
        name: name,
        playbackMode: json['playbackMode'] as String? ?? 'once',
        steps: [for (final s in json['steps'] as List) HamiStep.fromJson(s as Map<String, dynamic>)],
        blink: HamiBlink.fromJson(json['blink'] as Map<String, dynamic>?),
      );
}

class HamiDefinition {
  final Color bodyColor;
  final Color eyeColor;
  final Map<String, HamiExpression> expressions;
  final Map<String, HamiAnimation> animations;

  const HamiDefinition({
    required this.bodyColor,
    required this.eyeColor,
    required this.expressions,
    required this.animations,
  });

  // The resting face every other expression is measured against.
  HamiExpression get rest => expressions['friendly'] ?? expressions['neutral']!;

  factory HamiDefinition.fromJson(Map<String, dynamic> json) {
    if (json['schema'] != 'bible-strong/avatar-definition') {
      throw const FormatException('Not an avatar definition');
    }
    final colors = json['colors'] as Map<String, dynamic>;
    final expressions = json['expressions'] as Map<String, dynamic>;
    final animations = json['animations'] as Map<String, dynamic>;
    return HamiDefinition(
      bodyColor: parseHexColor(colors['body'] as String),
      eyeColor: parseHexColor(colors['eyes'] as String),
      expressions: {
        for (final e in expressions.entries) e.key: HamiExpression.fromJson(e.key, e.value as Map<String, dynamic>),
      },
      animations: {
        for (final a in animations.entries) a.key: HamiAnimation.fromJson(a.key, a.value as Map<String, dynamic>),
      },
    );
  }

  static Future<HamiDefinition> load([AssetBundle? bundle]) async {
    final source = await (bundle ?? rootBundle).loadString(hamiDefinitionAsset);
    return HamiDefinition.fromJson(jsonDecode(source) as Map<String, dynamic>);
  }
}

Color parseHexColor(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse(value.length == 6 ? 'FF$value' : value, radix: 16));
}
