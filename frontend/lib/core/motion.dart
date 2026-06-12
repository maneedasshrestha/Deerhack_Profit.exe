import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Motion tokens. Spring-based / eased animations — never linear. Every state
/// change animates. These constants keep the feel consistent across the app.
class Motion {
  Motion._();

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 360);
  static const Duration slow = Duration(milliseconds: 640);

  /// The shared-element transition between the orb and the reflection view.
  static const Duration hero = Duration(milliseconds: 560);

  /// A confident, slightly overshooting ease for entrances and morphs.
  static const Curve emphasized = Curves.easeOutCubic;

  /// A gentle settle, no overshoot — for fades and opacity.
  static const Curve gentle = Curves.easeInOut;

  /// Spring-like, used for the orb scale and pill pops.
  static const Curve spring = Cubic(0.34, 1.4, 0.64, 1.0);
}

/// Whether the OS "reduce motion" accessibility setting is on. The orb and other
/// continuous animations honour this — they hold a calm steady state instead of
/// looping. Read it once per build via [MediaQuery]; this helper is for places
/// without a [BuildContext].
bool get platformReduceMotion =>
    SchedulerBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

/// `context.reduceMotion` — true when animations should be minimised.
extension ReduceMotionContext on BuildContext {
  bool get reduceMotion => MediaQuery.maybeOf(this)?.disableAnimations ?? platformReduceMotion;
}
