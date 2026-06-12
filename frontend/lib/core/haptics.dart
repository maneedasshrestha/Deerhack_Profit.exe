import 'package:flutter/services.dart';

/// Subtle, intentional haptics — never buzzy. Used at the three moments the
/// spec calls out: session start, the student finishing a question, and session
/// end. Wrapped so we can no-op gracefully if the platform has no haptics.
class Haptics {
  Haptics._();

  static Future<void> sessionStart() => _safe(HapticFeedback.lightImpact);

  /// The student just finished asking — a soft "your turn" tap.
  static Future<void> studentDoneSpeaking() => _safe(HapticFeedback.selectionClick);

  static Future<void> sessionEnd() => _safe(HapticFeedback.mediumImpact);

  /// A featherweight tick for the gaps counter / minor state changes.
  static Future<void> tick() => _safe(HapticFeedback.selectionClick);

  static Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // No haptics on this device — fine.
    }
  }
}
