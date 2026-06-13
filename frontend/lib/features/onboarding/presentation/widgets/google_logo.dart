import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The four-colour Google "G", painted from arcs + a crossbar so we don't need
/// an asset or an SVG package. Sized to fit inside the sign-in button.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GoogleLogoPainter());
}

class _GoogleLogoPainter extends CustomPainter {
  // Brand colours.
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  // Degrees measured from 12 o'clock, clockwise. drawArc starts at 3 o'clock,
  // so we shift by -90°.
  static double _rad(double deg12) => (deg12 - 90) * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.23;
    final radius = (size.width - stroke) / 2;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    void arc(double startDeg, double sweepDeg, Color color) {
      paint.color = color;
      canvas.drawArc(rect, _rad(startDeg), sweepDeg * math.pi / 180, false, paint);
    }

    // Clockwise from the top: red over the top + left, blue up the right toward
    // the crossbar, green across the bottom-right, yellow up the lower-left.
    arc(-130, 150, _red); //  top + upper-left
    arc(20, 50, _blue); //    upper-right, into the crossbar
    arc(95, 70, _green); //   bottom-right
    arc(165, 65, _yellow); // lower-left, back up to red

    // The blue crossbar: a bar from the centre out to the right edge.
    final bar = Paint()..color = _blue;
    final barHeight = stroke;
    final barRect = RRect.fromRectAndCorners(
      Rect.fromLTRB(
        center.dx - barHeight * 0.15,
        center.dy - barHeight / 2,
        center.dx + radius + stroke / 2,
        center.dy + barHeight / 2,
      ),
      topRight: Radius.circular(barHeight / 2),
      bottomRight: Radius.circular(barHeight / 2),
    );
    canvas.drawRRect(barRect, bar);
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}
