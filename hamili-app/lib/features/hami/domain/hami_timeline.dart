import 'package:flutter/animation.dart';

import 'hami_definition.dart';
import 'hami_pose.dart';

// Plays a Lab animation as a pure function of time so the widget only has
// to ask "what does Hami look like now?" each frame.

Curve curveFor(String transition) => switch (transition) {
      'snappy' => Curves.easeOutCubic,
      'spring' => Curves.easeOutBack,
      _ => Curves.easeInOut,
    };

List<HamiStep> _playbackSteps(HamiAnimation anim) {
  final steps = anim.steps;
  if (anim.playbackMode == 'pingPong' && steps.length > 2) {
    return [...steps, ...steps.sublist(1, steps.length - 1).reversed];
  }
  return steps;
}

/// Hami's pose [elapsedMs] into [anim]. The first transition starts from
/// [from], the pose Hami held when this animation began, so an interrupted
/// animation blends into the next one instead of jumping.
HamiPose evaluate(HamiDefinition def, HamiAnimation anim, int elapsedMs, {HamiPose? from}) {
  final steps = _playbackSteps(anim);
  final rest = poseFor(def, def.rest.name);
  if (steps.isEmpty) return from ?? rest;

  final cycle = steps.fold<int>(0, (sum, s) => sum + s.totalMs);
  var t = elapsedMs < 0 ? 0 : elapsedMs;
  var firstCycle = true;
  if (!anim.loops && t >= cycle) return poseFor(def, steps.last.expression);
  if (anim.loops && cycle > 0 && t >= cycle) {
    firstCycle = false;
    t %= cycle;
  }

  var previous = firstCycle ? (from ?? (anim.loops ? poseFor(def, steps.last.expression) : rest)) : poseFor(def, steps.last.expression);
  for (final step in steps) {
    final target = poseFor(def, step.expression);
    if (t < step.transitionMs) {
      final progress = curveFor(step.transition).transform(t / step.transitionMs);
      return HamiPose.lerp(previous, target, progress);
    }
    t -= step.transitionMs;
    if (t < step.holdMs) return target;
    t -= step.holdMs;
    previous = target;
  }
  return previous;
}

/// The single still frame that carries an animation's meaning, used when
/// the user asks for reduced motion: its longest-held non-resting step.
HamiPose peakPose(HamiDefinition def, HamiAnimation anim) {
  HamiStep? best;
  for (final step in anim.steps) {
    if (step.expression == def.rest.name) continue;
    if (best == null || step.holdMs > best.holdMs) best = step;
  }
  return poseFor(def, best?.expression ?? def.rest.name).stilled();
}

/// Eye openness during a blink that started [sinceMs] ago: closes, then
/// reopens over [durationMs].
double blinkOpenness(int sinceMs, int durationMs) {
  if (durationMs <= 0 || sinceMs < 0 || sinceMs >= durationMs) return 1;
  final half = durationMs / 2;
  final t = sinceMs < half ? sinceMs / half : (durationMs - sinceMs) / half;
  return 1 - t;
}
