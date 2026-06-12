import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A small trend sparkline of clarity across turns. Draws a smooth accent line
/// with a soft fill below and a highlighted final point. Animates in.
class ClaritySparkline extends StatelessWidget {
  const ClaritySparkline({
    super.key,
    required this.values,
    this.height = 48,
  });

  final List<int> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (values.length < 2) {
      // Not enough points for a trend yet — keep the space, hint at it.
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            values.isEmpty ? 'No turns yet' : 'Explain again to see your trend',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        size: Size(double.infinity, height),
        painter: _SparkPainter(values, p.accent, p.accentSoft, t),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.line, this.fill, this.t);

  final List<int> values;
  final Color line;
  final Color fill;
  final double t; // reveal progress 0..1

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 6.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    final n = values.length;
    Offset point(int i) {
      final x = pad + (n == 1 ? 0 : w * i / (n - 1));
      final y = pad + h * (1 - (values[i].clamp(0, 100)) / 100);
      return Offset(x, y);
    }

    final pts = [for (var i = 0; i < n; i++) point(i)];

    // Reveal by clipping to a growing width.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * t, size.height));

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final cur = pts[i];
      final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      path.lineTo(cur.dx, cur.dy);
    }

    // Soft fill under the line.
    final fillPath = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fill, fill.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = line,
    );
    canvas.restore();

    // Final point marker (only once fully revealed enough to reach it).
    if (t > 0.92) {
      final last = pts.last;
      canvas.drawCircle(last, 4.5, Paint()..color = line);
      canvas.drawCircle(
          last, 4.5, Paint()..color = line.withValues(alpha: 0.25)..style = PaintingStyle.stroke..strokeWidth = 4);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.t != t || old.values != values;
}
