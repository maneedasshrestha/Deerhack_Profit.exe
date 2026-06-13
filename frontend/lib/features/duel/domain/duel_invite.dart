import 'dart:math';

/// Encoding for duel invites shared via QR. Each duel has a short, unique code;
/// the QR carries a deep-link payload around that code. The scanner uses
/// [resolveCode] to turn a scanned payload back into the duel's code, which is
/// then looked up against the backend.
class DuelInvite {
  DuelInvite._();

  static const String scheme = 'feynman://duel/';
  // Crockford-ish alphabet: no easily-confused glyphs (0/O, 1/I/L).
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static final Random _rng = Random();

  /// A fresh random 6-character, dash-grouped code (e.g. ABC-DEF). Collisions
  /// are vanishingly unlikely; the backend's unique constraint is the backstop.
  static String newCode() {
    final buf = StringBuffer();
    for (var i = 0; i < 6; i++) {
      buf.write(_alphabet[_rng.nextInt(_alphabet.length)]);
    }
    final code = buf.toString();
    return '${code.substring(0, 3)}-${code.substring(3)}';
  }

  /// Normalise a code for comparison/storage: upper-case, no dashes.
  static String normalize(String code) =>
      code.replaceAll('-', '').replaceAll(' ', '').toUpperCase();

  /// Re-group a 6-char normalised code as ABC-DEF for display.
  static String pretty(String code) {
    final n = normalize(code);
    if (n.length != 6) return n;
    return '${n.substring(0, 3)}-${n.substring(3)}';
  }

  /// The deep-link payload encoded into the QR for [code].
  static String payloadFor(String code) => '$scheme${normalize(code)}';

  // ---------------------------------------------------------------------------
  // Name-based helpers for the local mock duel flow. Real duels round-trip a
  // backend code (above); the mock share/scan flow instead encodes the player's
  // name directly so the scanner can match it against [MockData].
  // ---------------------------------------------------------------------------

  /// A stable, dash-grouped display code derived from [name]. Same name always
  /// yields the same code, so it's safe to show and copy as a manual fallback.
  static String codeFor(String name) {
    var h = 0;
    for (final unit in name.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    final buf = StringBuffer();
    for (var i = 0; i < 6; i++) {
      buf.write(_alphabet[h % _alphabet.length]);
      h = (h ~/ _alphabet.length) + (name.length + i + 1);
    }
    final code = buf.toString();
    return '${code.substring(0, 3)}-${code.substring(3)}';
  }

  /// The QR payload that encodes a player's [name] for the mock duel flow.
  static String payloadForName(String name) =>
      '$scheme${Uri.encodeComponent(name)}';

  /// Resolve a scanned payload (or typed value) back to the encoded player
  /// name, or null if it isn't a recognisable name invite.
  static String? resolveName(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (!value.startsWith(scheme)) return null;
    final encoded = value.substring(scheme.length);
    if (encoded.isEmpty) return null;
    return Uri.decodeComponent(encoded);
  }

  /// Resolve a scanned QR payload (or a manually typed value) back to a
  /// normalised duel code, or null if it isn't a recognisable duel invite.
  static String? resolveCode(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.startsWith(scheme)) {
      value = value.substring(scheme.length);
    }
    final code = normalize(value);
    // A valid code is exactly 6 chars drawn from our alphabet.
    if (code.length != 6) return null;
    for (final c in code.split('')) {
      if (!_alphabet.contains(c)) return null;
    }
    return code;
  }
}
