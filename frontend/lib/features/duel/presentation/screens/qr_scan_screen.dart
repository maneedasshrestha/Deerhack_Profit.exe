import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../home/domain/mock_data.dart';
import '../../domain/duel_invite.dart';
import 'duel_race_screen.dart';

/// A full-screen QR scanner backed by the device camera (mobile_scanner). When
/// it reads a valid duel-invite code it locks on, confirms the matched player,
/// then drops straight into the live race.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with TickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat(reverse: true);
  late final AnimationController _lock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  bool _handled = false;
  bool _analyzing = false;
  String? _matchedName;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    _matchFrom(capture);
  }

  /// Returns true if a valid (non-self) invite was found and locked onto.
  bool _matchFrom(BarcodeCapture? capture) {
    for (final barcode in capture?.barcodes ?? const <Barcode>[]) {
      final name = DuelInvite.resolveName(barcode.rawValue);
      if (name != null && name != MockData.userName) {
        _lockOnto(name);
        return true;
      }
    }
    return false;
  }

  /// Pick an image from the gallery and look for a race code inside it.
  Future<void> _pickFromGallery() async {
    if (_handled || _analyzing) return;
    setState(() => _analyzing = true);
    try {
      final file =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null || _handled) return;
      final capture = await _controller.analyzeImage(file.path);
      if (!mounted || _handled) return;
      if (!_matchFrom(capture)) {
        _showSnack('No valid duel code found in that image');
      }
    } catch (_) {
      if (mounted) _showSnack('Couldn\'t read a code from that image');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _lockOnto(String name) async {
    _handled = true;
    Haptics.sessionStart();
    await _controller.stop();
    if (!mounted) return;
    setState(() => _matchedName = name);
    _scan.stop();
    _lock.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DuelRaceScreen(opponentName: name),
      ),
    );
  }

  @override
  void dispose() {
    _scan.dispose();
    _lock.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final detected = _matchedName != null;

    return Scaffold(
      backgroundColor: const Color(0xFF07070A),
      body: Stack(
        children: [
          // Live camera feed.
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) =>
                  _CameraError(error: error, palette: p),
              fit: BoxFit.cover,
            ),
          ),
          // Dim scrim so the framing window pops.
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.45)),
          ),

          // Framing window with corner brackets + scan line.
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _lock,
                      builder: (context, _) => CustomPaint(
                        painter: _FramePainter(
                          color: detected ? p.positive : Colors.white,
                          lock: _lock.value,
                        ),
                      ),
                    ),
                  ),
                  if (!detected)
                    AnimatedBuilder(
                      animation: _scan,
                      builder: (context, _) => Positioned(
                        left: 18,
                        right: 18,
                        top: 18 + (260 - 36) * _scan.value,
                        child: Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(
                              colors: [
                                p.accent.withValues(alpha: 0),
                                p.accent,
                                p.accent.withValues(alpha: 0),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: p.accent.withValues(alpha: 0.6),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (detected)
                    Center(
                      child: ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _lock,
                          curve: Curves.easeOutBack,
                        ),
                        child: _MatchedBadge(name: _matchedName!),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Caption.
          Positioned(
            left: 24,
            right: 24,
            bottom: 64 + MediaQuery.of(context).viewPadding.bottom,
            child: Column(
              children: [
                Text(
                  detected ? 'Code matched' : 'Scanning for a code…',
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  detected
                      ? 'Starting your duel'
                      : 'Point at a friend\'s duel code to challenge them',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                if (!detected) ...[
                  const SizedBox(height: 22),
                  _GalleryButton(
                    busy: _analyzing,
                    onTap: _pickFromGallery,
                  ),
                ],
              ],
            ),
          ),

          // Controls: close + torch toggle.
          Positioned(
            top: MediaQuery.of(context).viewPadding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                if (!detected)
                  IconButton(
                    icon: const Icon(Icons.flash_on_rounded,
                        color: Colors.white),
                    onPressed: () => _controller.toggleTorch(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.palette});
  final MobileScannerException error;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final denied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              denied ? Icons.no_photography_rounded : Icons.error_outline_rounded,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              denied ? 'Camera access needed' : 'Camera unavailable',
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              denied
                  ? 'Enable camera access in Settings to scan a friend\'s duel code.'
                  : 'Couldn\'t start the camera on this device.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}

/// A glassy "upload from gallery" pill shown beneath the scan caption.
class _GalleryButton extends StatelessWidget {
  const _GalleryButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            else
              const Icon(Icons.photo_library_rounded,
                  color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              busy ? 'Reading image…' : 'Upload from gallery',
              style: text.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchedBadge extends StatelessWidget {
  const _MatchedBadge({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final initials = MockData.friends.firstWhere(
      (f) => f['name'] == name,
      orElse: () => {'initials': name.isNotEmpty ? name[0] : '?'},
    )['initials'] as String;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.positive,
            boxShadow: [
              BoxShadow(
                color: p.positive.withValues(alpha: 0.5),
                blurRadius: 20,
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials,
              style: text.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          style: text.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Corner brackets that tighten into a full rounded square as [lock] → 1.
class _FramePainter extends CustomPainter {
  _FramePainter({required this.color, required this.lock});
  final Color color;
  final double lock;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(28),
    );

    if (lock >= 0.999) {
      canvas.drawRRect(rrect, paint);
      return;
    }

    final base = size.width * 0.18;
    final arm = base + (size.width / 2 - base) * lock;
    final path = Path();

    // Top-left
    path.moveTo(0, arm);
    path.lineTo(0, 28);
    path.arcToPoint(const Offset(28, 0), radius: const Radius.circular(28));
    path.lineTo(arm, 0);
    // Top-right
    path.moveTo(size.width - arm, 0);
    path.lineTo(size.width - 28, 0);
    path.arcToPoint(Offset(size.width, 28), radius: const Radius.circular(28));
    path.lineTo(size.width, arm);
    // Bottom-right
    path.moveTo(size.width, size.height - arm);
    path.lineTo(size.width, size.height - 28);
    path.arcToPoint(Offset(size.width - 28, size.height),
        radius: const Radius.circular(28));
    path.lineTo(size.width - arm, size.height);
    // Bottom-left
    path.moveTo(arm, size.height);
    path.lineTo(28, size.height);
    path.arcToPoint(Offset(0, size.height - 28),
        radius: const Radius.circular(28));
    path.lineTo(0, size.height - arm);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.color != color || old.lock != lock;
}
