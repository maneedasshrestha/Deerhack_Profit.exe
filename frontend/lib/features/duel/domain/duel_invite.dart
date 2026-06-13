import '../../home/domain/mock_data.dart';

/// Encoding for duel invites shared via QR. A person maps to a short, stable
/// code; the QR carries a deep-link payload around that code. The scanner uses
/// [resolveName] to turn a scanned payload back into a known player.
class DuelInvite {
  DuelInvite._();

  static const String scheme = 'feynman://duel/';
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// A 6-character, dash-grouped code derived deterministically from [name].
  static String codeFor(String name) {
    var n = name.hashCode & 0x7fffffff;
    final buf = StringBuffer();
    for (var i = 0; i < 6; i++) {
      buf.write(_alphabet[n % _alphabet.length]);
      n ~/= _alphabet.length;
    }
    final code = buf.toString();
    return '${code.substring(0, 3)}-${code.substring(3)}';
  }

  /// The deep-link payload encoded into the QR for [name].
  static String payloadFor(String name) =>
      '$scheme${codeFor(name).replaceAll('-', '')}';

  /// Resolve a scanned QR payload back to a player name, or null if it isn't a
  /// recognisable duel invite. Matches against the user and their friends.
  static String? resolveName(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (!value.startsWith(scheme)) return null;
    final scanned = value.substring(scheme.length).toUpperCase();
    if (scanned.isEmpty) return null;

    String norm(String c) => c.replaceAll('-', '').toUpperCase();

    final candidates = <String>[
      MockData.userName,
      for (final f in MockData.friends) f['name'] as String,
    ];
    for (final name in candidates) {
      if (norm(codeFor(name)) == scanned) return name;
    }
    return null;
  }
}
