import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../domain/mock_data.dart';
import '../../domain/plan_data.dart';
import 'flashcards_screen.dart';
import 'lesson_screen.dart';
import 'mock_test_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// HomeScreen — the weekly plan, rendered as a Duolingo-style path.
// One week = daily MCQ levels → a bonus flashcard deck → Sunday's mock test.
// ═══════════════════════════════════════════════════════════════════════════
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const week = PlanData.currentWeek;
    return Scaffold(
      // The shared top bar lives in the shell above this screen.
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: _LastWeekRecap()),
          const SliverToBoxAdapter(
            child: StaggeredEntrance(
              index: 1,
              child: _WeekHeaderCard(week: week),
            ),
          ),
          SliverToBoxAdapter(child: _WeekPath(week: week)),
          const SliverToBoxAdapter(
            child: _NextWeekTeaser(),
          ),
          // Clearance for the floating glass nav bar.
          const SliverToBoxAdapter(child: SizedBox(height: 124)),
        ],
      ),
    );
  }
}

// ─── Last week recap (subtle, above the fold) ─────────────────────────────────
class _LastWeekRecap extends StatelessWidget {
  const _LastWeekRecap();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return StaggeredEntrance(
      index: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(
          children: [
            Icon(Icons.verified_rounded, size: 16, color: p.positive),
            const SizedBox(width: 6),
            Text(
              'Week ${PlanData.lastWeekNumber} complete',
              style: text.labelMedium?.copyWith(color: p.textSecondary),
            ),
            Text(
              '  ·  mock ${PlanData.lastWeekMockPercent}%',
              style: text.labelMedium?.copyWith(color: p.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Week header card ─────────────────────────────────────────────────────────
class _WeekHeaderCard extends StatelessWidget {
  const _WeekHeaderCard({required this.week});
  final WeekPlan week;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C3AED), Color(0xFF9F5BFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: p.accent.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'WEEK ${week.weekNumber} OF ${week.totalWeeks}',
                  style: text.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ProgressRing(
                progress: week.progress,
                size: 40,
                strokeWidth: 4,
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                child: Text(
                  '${week.completedCount}/${week.levels.length}',
                  style: text.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            week.theme,
            style: text.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in week.targets)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    t,
                    style: text.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Drafted from last week\'s mock — clear every level, then prove '
            'it in Sunday\'s test.',
            style: text.labelMedium
                ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// The path
// ═══════════════════════════════════════════════════════════════════════════
const double _kAmplitude = 64;

double _dxFor(int i) => math.sin(i * math.pi / 2) * _kAmplitude;

class _WeekPath extends StatelessWidget {
  const _WeekPath({required this.week});
  final WeekPlan week;

  void _open(BuildContext context, WeekLevel level) {
    if (level.isLocked) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            content: const Text('Finish the previous level to unlock this one'),
          ),
        );
      return;
    }
    final route = switch (level.type) {
      LevelType.mcq => MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => LessonScreen(
            title: level.title,
            questions: PlanData.questionsForLevel(level.id),
          ),
        ),
      LevelType.flashcards => MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const FlashcardsScreen(),
        ),
      LevelType.mockTest => MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const MockTestScreen(),
        ),
    };
    Navigator.of(context, rootNavigator: true).push(route);
  }

  // Keep the winding zigzag, but pin the *current* level to dead centre so the
  // "you are here" button always lands in the middle, whatever day it is.
  double _dx(List<WeekLevel> levels, int i) =>
      levels[i].isCurrent ? 0.0 : _dxFor(i);

  @override
  Widget build(BuildContext context) {
    final levels = week.levels;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Stack(
        children: [
          // Soft, slowly breathing orbs drifting behind the path for depth.
          const Positioned.fill(child: _AmbientOrbs()),
          Column(
            children: [
              for (var i = 0; i < levels.length; i++) ...[
                if (i > 0)
                  _Trail(
                    fromDx: _dx(levels, i - 1),
                    toDx: _dx(levels, i),
                    done: levels[i - 1].isCompleted,
                    // A mascot sits in the gap; it stays greyed out until the
                    // level just below it is cleared, then springs to colour.
                    // TODO(art): supply real art via `mascotAsset:` later, e.g.
                    //   mascotAsset: 'assets/mascots/owl.png'
                    mascotUnlocked: levels[i].isCompleted,
                    mascotOnLeft: i.isEven,
                  ),
                StaggeredEntrance(
                  index: i + 2,
                  child: Transform.translate(
                    offset: Offset(_dx(levels, i), 0),
                    child: _LevelNode(
                      level: levels[i],
                      onTap: () => _open(context, levels[i]),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Trail (connector + a mascot tucked in the gap) ───────────────────────────
class _Trail extends StatelessWidget {
  const _Trail({
    required this.fromDx,
    required this.toDx,
    required this.done,
    required this.mascotUnlocked,
    required this.mascotOnLeft,
    // ignore: unused_element_parameter
    this.mascotAsset,
  });

  final double fromDx, toDx;
  final bool done;
  final bool mascotUnlocked;
  final bool mascotOnLeft;

  /// Asset path for the gap's mascot art, wired straight through to
  /// [_MascotSlot]. Left null for now (a placeholder shows); set it later, e.g.
  /// `mascotAsset: 'assets/mascots/owl.png'`, with no other changes needed.
  final String? mascotAsset;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: _ConnectorPainter(
              fromDx: fromDx,
              toDx: toDx,
              color: done ? p.accent : p.accent.withValues(alpha: 0.18),
              dashed: !done,
            ),
          ),
          Align(
            alignment: mascotOnLeft
                ? const Alignment(-0.66, 0)
                : const Alignment(0.66, 0),
            child: _MascotSlot(unlocked: mascotUnlocked, asset: mascotAsset),
          ),
        ],
      ),
    );
  }
}

/// Placeholder for a future mascot illustration tucked between two levels.
///
/// Drop real art in later by passing [asset] (e.g.
/// `asset: 'assets/mascots/owl.png'`). The grey-while-locked / colour-when-
/// unlocked treatment lives here, so swapping the image needs no other changes.
class _MascotSlot extends StatelessWidget {
  const _MascotSlot({required this.unlocked, this.asset});

  final bool unlocked;
  final String? asset;

  static const double size = 50;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final Widget art = asset != null
        ? Image.asset(asset!, width: size, height: size, fit: BoxFit.contain)
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.surfaceHigh,
              border: Border.all(color: p.hairline, width: 1.2),
            ),
            child: Icon(Icons.pets_rounded,
                size: size * 0.5, color: p.textTertiary),
          );

    // A little spring + full colour once unlocked; flat greyscale until then.
    return AnimatedScale(
      scale: unlocked ? 1.0 : 0.9,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: unlocked ? 1.0 : 0.5,
        child: unlocked
            ? art
            : ColorFiltered(
                colorFilter: const ColorFilter.matrix(_kGreyscale),
                child: art,
              ),
      ),
    );
  }
}

/// Luminance-preserving greyscale matrix for locked mascots.
const List<double> _kGreyscale = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Two oversized, soft orbs that slowly breathe behind the path — pure ambience
/// to make the screen feel alive and a touch more dimensional.
class _AmbientOrbs extends StatefulWidget {
  const _AmbientOrbs();

  @override
  State<_AmbientOrbs> createState() => _AmbientOrbsState();
}

class _AmbientOrbsState extends State<_AmbientOrbs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _orb(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient:
              RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_c.value);
          return Stack(
            children: [
              Positioned(
                top: 30 + 10 * t,
                left: -50,
                child: _orb(200 + 24 * t,
                    p.accent.withValues(alpha: 0.10 * (0.55 + 0.45 * t))),
              ),
              Positioned(
                top: 320 - 14 * t,
                right: -60,
                child: _orb(
                    240 - 20 * t,
                    const Color(0xFFEC4899)
                        .withValues(alpha: 0.07 * (0.55 + 0.45 * t))),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Electric ring (the current node's "alive" effect) ────────────────────────
/// A rotating arc of energy with a glowing spark head and occasional lightning
/// branches — drawn just outside the current level's node to make it crackle.
class _ElectricRingPainter extends CustomPainter {
  const _ElectricRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;

    // Faint, steady base ring.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.16),
    );

    // A bright arc of energy chasing its way around the ring.
    final rect = Rect.fromCircle(center: center, radius: r);
    final sweep = SweepGradient(
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0),
        color.withValues(alpha: 0.95),
        color.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.55, 0.82, 1.0],
      transform: GradientRotation(progress * 2 * math.pi),
    ).createShader(rect);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..shader = sweep,
    );

    // The glowing spark at the head of the arc.
    final ang = progress * 2 * math.pi;
    final spark = center + Offset(math.cos(ang), math.sin(ang)) * r;
    canvas.drawCircle(
      spark,
      3.4,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(spark, 1.7, Paint()..color = Colors.white);

    // Occasional lightning flickers branching off the ring.
    final flick = math.sin(progress * 2 * math.pi * 5);
    if (flick > 0.72) {
      final a = ((flick - 0.72) / 0.28).clamp(0.0, 1.0);
      final bolt = Paint()
        ..color = color.withValues(alpha: 0.85 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      _bolt(canvas, center, r, ang + math.pi * 0.5, bolt);
      _bolt(canvas, center, r, ang - math.pi * 0.6, bolt);
    }
  }

  void _bolt(Canvas canvas, Offset center, double r, double angle, Paint paint) {
    final dir = Offset(math.cos(angle), math.sin(angle));
    final perp = Offset(-dir.dy, dir.dx);
    final base = center + dir * r;
    final path = Path()
      ..moveTo(base.dx, base.dy)
      ..relativeLineTo(dir.dx * 5 + perp.dx * 3, dir.dy * 5 + perp.dy * 3)
      ..relativeLineTo(dir.dx * 5 - perp.dx * 5, dir.dy * 5 - perp.dy * 5)
      ..relativeLineTo(dir.dx * 5 + perp.dx * 2, dir.dy * 5 + perp.dy * 2);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ElectricRingPainter old) =>
      old.progress != progress || old.color != color;
}

class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({
    required this.fromDx,
    required this.toDx,
    required this.color,
    required this.dashed,
  });

  final double fromDx, toDx;
  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final start = Offset(cx + fromDx, -4);
    final end = Offset(cx + toDx, size.height + 4);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Gentle S-curve instead of a straight diagonal.
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx,
        start.dy + size.height * 0.55,
        end.dx,
        end.dy - size.height * 0.55,
        end.dx,
        end.dy,
      );

    if (!dashed) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      const dash = 7.0, gap = 7.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.fromDx != fromDx ||
      old.toDx != toDx ||
      old.color != color ||
      old.dashed != dashed;
}

// ─── Level node ───────────────────────────────────────────────────────────────
class _LevelNode extends StatefulWidget {
  const _LevelNode({required this.level, required this.onTap});
  final WeekLevel level;
  final VoidCallback onTap;

  @override
  State<_LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<_LevelNode>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  // Drives the rotating "electric" ring on the current node.
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (widget.level.isCurrent) {
      _pulse.repeat(reverse: true);
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  Color get _color {
    final p = context.palette;
    return switch (widget.level.type) {
      LevelType.mcq => p.accent,
      LevelType.flashcards => const Color(0xFFEC4899),
      LevelType.mockTest => const Color(0xFFF59E0B),
    };
  }

  IconData get _icon => switch (widget.level.type) {
        LevelType.mcq => Icons.menu_book_rounded,
        LevelType.flashcards => Icons.style_rounded,
        LevelType.mockTest => Icons.emoji_events_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final level = widget.level;
    final c = _color;
    final big = level.type == LevelType.mockTest;
    final diameter = big ? 84.0 : 72.0;

    final Color bg;
    final Color fg;
    Border? border;
    Gradient? gradient;
    List<BoxShadow> shadows = const [];

    if (level.isLocked) {
      bg = const Color(0xFFEDEBF3);
      fg = p.textTertiary;
    } else if (level.isCompleted) {
      bg = c;
      fg = Colors.white;
      // Radial highlight reads as a glossy 3D sphere rather than a flat disc.
      gradient = RadialGradient(
        center: const Alignment(-0.4, -0.5),
        radius: 1.1,
        colors: [Color.lerp(c, Colors.white, 0.5)!, c],
      );
      shadows = [
        BoxShadow(
          color: c.withValues(alpha: 0.45),
          blurRadius: 18,
          offset: const Offset(0, 9),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ];
    } else if (level.isCurrent) {
      bg = p.surface;
      fg = c;
      border = Border.all(color: c, width: 3.5);
      gradient = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 1.0,
        colors: [Color.lerp(p.surface, c, 0.16)!, p.surface],
      );
      shadows = [
        BoxShadow(
          color: c.withValues(alpha: 0.34),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ];
    } else {
      bg = p.surface;
      fg = c;
      border = Border.all(color: c.withValues(alpha: 0.45), width: 2.5);
      gradient = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 1.0,
        colors: [Color.lerp(p.surface, c, 0.05)!, p.surface],
      );
      shadows = [
        BoxShadow(
          color: const Color(0xFF2A2150).withValues(alpha: 0.10),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ];
    }

    return Pressable(
      onTap: widget.onTap,
      scale: 0.93,
      child: SizedBox(
        width: 168,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (level.isCurrent)
              _StartBubble(color: c, pulse: _pulse)
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  level.dayLabel.toUpperCase(),
                  style: text.labelSmall?.copyWith(
                    color: level.isLocked ? p.textTertiary : c,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            AnimatedBuilder(
              animation: Listenable.merge([_pulse, _spin]),
              builder: (context, child) {
                final t = Curves.easeInOut.transform(_pulse.value);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulsing halo.
                    if (level.isCurrent)
                      Container(
                        width: diameter + 14 + 14 * t,
                        height: diameter + 14 + 14 * t,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.withValues(alpha: 0.18 * (1 - t)),
                        ),
                      ),
                    // Crackling electric ring chasing around the node.
                    if (level.isCurrent)
                      CustomPaint(
                        size: Size.square(diameter + 20),
                        painter: _ElectricRingPainter(
                          progress: _spin.value,
                          color: c,
                        ),
                      ),
                    child!,
                  ],
                );
              },
              child: Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gradient == null ? bg : null,
                  gradient: gradient,
                  border: border,
                  boxShadow: shadows,
                ),
                child: Center(
                  child: Icon(
                    level.isLocked ? Icons.lock_rounded : _icon,
                    color: fg,
                    size: big ? 38 : 30,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              level.title,
              textAlign: TextAlign.center,
              style: text.labelLarge?.copyWith(
                color: level.isLocked ? p.textTertiary : p.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              level.subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: p.textTertiary),
            ),
            if (level.isCompleted) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Icon(
                      i < level.stars
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 15,
                      color: i < level.stars
                          ? const Color(0xFFF59E0B)
                          : p.textTertiary.withValues(alpha: 0.5),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The bobbing "START" callout above the current node.
class _StartBubble extends StatelessWidget {
  const _StartBubble({required this.color, required this.pulse});
  final Color color;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -3 * Curves.easeInOut.transform(pulse.value)),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'START',
                style: text.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            CustomPaint(
              size: const Size(12, 6),
              painter: _TrianglePainter(color),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

// ─── Next week teaser ─────────────────────────────────────────────────────────
class _NextWeekTeaser extends StatelessWidget {
  const _NextWeekTeaser();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: p.surfaceHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.hairline, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.surface,
                border: Border.all(color: p.hairline),
              ),
              child: Icon(Icons.lock_rounded,
                  size: 20, color: p.textTertiary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Week ${PlanData.nextWeekNumber}',
                    style: text.titleMedium
                        ?.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    PlanData.nextWeekHint,
                    style:
                        text.labelMedium?.copyWith(color: p.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(Icons.auto_awesome_rounded,
                size: 18, color: MockData.mathColor.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}
