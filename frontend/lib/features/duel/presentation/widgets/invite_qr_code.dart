import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// A real, scannable QR code for a duel invite. Same `data` → same code, and it
/// encodes a genuine payload (a deep link) that the in-app scanner can read.
class InviteQrCode extends StatelessWidget {
  const InviteQrCode({
    super.key,
    required this.data,
    this.size = 220,
    this.foreground = const Color(0xFF12101A),
    this.background = Colors.white,
  });

  /// The invite payload encoded into the code (e.g. a deep link).
  final String data;
  final double size;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      backgroundColor: background,
      // Rounded modules + eyes to match the app's soft, premium feel.
      eyeStyle: QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: foreground,
      ),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: foreground,
      ),
      // Higher error correction so the code still scans with the centre logo
      // area and a tighter quiet zone on a phone screen.
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
  }
}
