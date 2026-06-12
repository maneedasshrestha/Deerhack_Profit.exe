import 'package:flutter/material.dart';

/// A single, immutable colour palette. We design the dark palette first and
/// derive the light one from the same accent so they switch cleanly.
///
/// Design rule: ONE accent (a muted electric violet), used sparingly — the orb,
/// active states, and key actions only. Everything else is a refined neutral
/// ramp. No rainbow UIs.
@immutable
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.accent,
    required this.accentSoft,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.warning,
    required this.positive,
    required this.recordingDot,
    required this.orbCore,
    required this.orbGlow,
  });

  final Brightness brightness;

  /// The one accent. Used for the orb, primary actions, active states.
  final Color accent;

  /// A translucent wash of the accent for fills/halos.
  final Color accentSoft;

  /// App background — the deepest layer.
  final Color bg;

  /// Card / sheet surface, one step up from [bg].
  final Color surface;

  /// Elevated surface (glass panels, pills).
  final Color surfaceHigh;

  /// 0.5px hairline borders — depth through layering, not shadows.
  final Color hairline;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Warning accent — paired with an icon to mark flagged jargon.
  final Color warning;

  /// Positive accent — high clarity.
  final Color positive;

  /// The live "recording" dot.
  final Color recordingDot;

  /// Orb gradient stops.
  final Color orbCore;
  final Color orbGlow;

  bool get isDark => brightness == Brightness.dark;

  /// Dark-first: this is the primary, most-considered palette.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    accent: Color(0xFF8B7CF6), // muted electric violet
    accentSoft: Color(0x338B7CF6),
    bg: Color(0xFF0B0B0F),
    surface: Color(0xFF141419),
    surfaceHigh: Color(0xFF1C1C24),
    hairline: Color(0x1FFFFFFF),
    textPrimary: Color(0xFFF4F4F7),
    textSecondary: Color(0xFFA8A8B3),
    textTertiary: Color(0xFF6E6E7A),
    warning: Color(0xFFE9A23B), // warm amber for jargon underlines
    positive: Color(0xFF5BD6A6),
    recordingDot: Color(0xFFFF5A6E),
    orbCore: Color(0xFFB3A8FF),
    orbGlow: Color(0xFF6D5BE0),
  );

  /// The app's primary palette — light, airy, with a confident purple accent.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    accent: Color(0xFF7C3AED),
    accentSoft: Color(0x147C3AED),
    bg: Color(0xFFF9F8FD),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF2EFFA),
    hairline: Color(0x14201A33),
    textPrimary: Color(0xFF1B1726),
    textSecondary: Color(0xFF5A5468),
    textTertiary: Color(0xFF9892A8),
    warning: Color(0xFFB45309),
    positive: Color(0xFF059669),
    recordingDot: Color(0xFFE11D48),
    orbCore: Color(0xFF9F7AFF),
    orbGlow: Color(0xFF7C3AED),
  );
}
