import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../domain/mock_data.dart';
import '../../domain/plan_data.dart';
import 'flashcards_screen.dart';
import 'lesson_screen.dart';
import 'mock_test_screen.dart';
import 'week_detail_screen.dart';

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
          const SliverToBoxAdapter(child: _NextWeekTeaser()),
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
/// Collapsible week banner. Collapsed, it's a slim strip (week label, theme,
/// progress) so the game map below gets the spotlight; expanded, it reveals the
/// week's goals, blurb and the link into this week's topics & questions.
class _WeekHeaderCard extends StatefulWidget {
  const _WeekHeaderCard({required this.week});
  final WeekPlan week;

  @override
  State<_WeekHeaderCard> createState() => _WeekHeaderCardState();
}

class _WeekHeaderCardState extends State<_WeekHeaderCard> {
  // Start collapsed so the Duolingo path is the first thing the eye lands on.
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final week = widget.week;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: p.accent.withValues(alpha: 0.40),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: const Color(0xFF6D28D9).withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            // Base gradient.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6D28D9), Color(0xFFA070FF)],
                  ),
                ),
              ),
            ),
            // Fluid blobs that morph and drift behind the content.
            const Positioned.fill(child: _FluidBlobs()),
            // Glossy top sheen for a 3D, lit-from-above feel.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.55],
                  ),
                ),
              ),
            ),
            // Animate the height as the body grows/shrinks.
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Always-visible header (tap to expand/collapse) ──
                    Pressable(
                      scale: 0.98,
                      onTap: _toggle,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WEEK ${week.weekNumber} OF '
                                  '${week.totalWeeks}',
                                  style: text.labelSmall?.copyWith(
                                    color:
                                        Colors.white.withValues(alpha: 0.85),
                                    letterSpacing: 1.6,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  week.theme,
                                  style: text.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ProgressRing(
                            progress: week.progress,
                            size: 42,
                            strokeWidth: 4,
                            color: Colors.white,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.25),
                            child: Text(
                              '${week.completedCount}/${week.levels.length}',
                              style: text.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _expanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Collapsible body ──
                    if (_expanded) _ExpandedBody(week: week),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The detail block revealed when the week card is expanded: the goals to
/// clear, the planning blurb and the link into this week's topics & questions.
class _ExpandedBody extends StatelessWidget {
  const _ExpandedBody({required this.week});
  final WeekPlan week;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              Icons.adjust_rounded,
              size: 13,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 5),
            Text(
              'GOALS TO CLEAR',
              style: text.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in week.targets)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      t,
                      style: text.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Drafted from last week\'s mock — clear every level, then '
          'prove it in Sunday\'s test.',
          style: text.labelMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 14),
        // Affordance: opens this week's topics + MCQs.
        Pressable(
          scale: 0.98,
          onTap: () => Navigator.of(
            context,
            rootNavigator: true,
          ).push(MaterialPageRoute(builder: (_) => const WeekDetailScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'See topics & questions',
                  style: text.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Fluid blobs (the week card's living backdrop) ────────────────────────────
/// Three soft, blurred white blobs that continuously morph their outline and
/// drift around the card — a slow "lava-lamp" motion that gives the card
/// character without competing with the content above it.
class _FluidBlobs extends StatefulWidget {
  const _FluidBlobs();

  @override
  State<_FluidBlobs> createState() => _FluidBlobsState();
}

class _FluidBlobsState extends State<_FluidBlobs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 14))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _BlobPainter(t: _c.value),
          ),
        ),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  const _BlobPainter({required this.t});

  /// Continuous loop value 0..1.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = t * 2 * math.pi;
    final s = size.shortestSide;

    // Large blob, top-right.
    _blob(
      canvas,
      center: Offset(size.width * 0.84 + 16 * math.sin(phase),
          size.height * 0.16 + 18 * math.cos(phase * 0.8)),
      baseR: s * 0.46,
      phase: phase,
      alpha: 0.16,
      blur: 18,
      h: const [0.18, 0.12, 0.08],
    );

    // Larger, softer blob, bottom-left.
    _blob(
      canvas,
      center: Offset(size.width * 0.12 + 20 * math.cos(phase * 0.7),
          size.height * 0.92 + 16 * math.sin(phase * 1.1)),
      baseR: s * 0.54,
      phase: phase * 1.3 + 1.5,
      alpha: 0.12,
      blur: 22,
      h: const [0.16, 0.10, 0.07],
    );

    // Small brighter accent blob roaming the middle.
    _blob(
      canvas,
      center: Offset(size.width * 0.5 + 34 * math.sin(phase * 1.4),
          size.height * 0.42 + 22 * math.cos(phase)),
      baseR: s * 0.2,
      phase: phase * 1.7,
      alpha: 0.10,
      blur: 12,
      h: const [0.24, 0.15, 0.10],
    );
  }

  /// Draws one organic blob: a closed loop whose radius is modulated by a few
  /// sine harmonics so the outline ripples and reshapes as [phase] advances.
  void _blob(
    Canvas canvas, {
    required Offset center,
    required double baseR,
    required double phase,
    required double alpha,
    required double blur,
    required List<double> h,
  }) {
    const n = 48;
    final path = Path();
    for (var i = 0; i <= n; i++) {
      final a = (i / n) * 2 * math.pi;
      final r = baseR *
          (1 +
              h[0] * math.sin(3 * a + phase) +
              h[1] * math.sin(5 * a - phase * 1.3) +
              h[2] * math.sin(2 * a + phase * 0.6));
      final pt = center + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t;
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
              borderRadius: BorderRadius.circular(14),
            ),
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
            child: Icon(
              Icons.pets_rounded,
              size: size * 0.5,
              color: p.textTertiary,
            ),
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
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
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
                child: _orb(
                  200 + 24 * t,
                  p.accent.withValues(alpha: 0.10 * (0.55 + 0.45 * t)),
                ),
              ),
              Positioned(
                top: 320 - 14 * t,
                right: -60,
                child: _orb(
                  240 - 20 * t,
                  const Color(
                    0xFFEC4899,
                  ).withValues(alpha: 0.07 * (0.55 + 0.45 * t)),
                ),
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

  void _bolt(
    Canvas canvas,
    Offset center,
    double r,
    double angle,
    Paint paint,
  ) {
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

class _LevelNodeState extends State<_LevelNode> with TickerProviderStateMixin {
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
    final lvl = widget.level;
    if (lvl.isCurrent) {
      _pulse.repeat(reverse: true);
      _spin.repeat();
    } else if (lvl.type == LevelType.flashcards &&
        !lvl.isLocked &&
        !lvl.isCompleted) {
      // The bonus node twinkles its sparkles even when it isn't the active one.
      _pulse.repeat(reverse: true);
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
    // The bonus deck: a special, available-but-not-yet-done flashcard node.
    final isBonus =
        level.type == LevelType.flashcards &&
        !level.isLocked &&
        !level.isCompleted;

    final Color bg;
    final Color fg;
    Border? border;
    Gradient? gradient;
    List<BoxShadow> shadows = const [];

    if (level.isLocked) {
      bg = const Color(0xFFEDEBF3);
      fg = p.textTertiary;
    } else if (isBonus) {
      // Pizzazz: a gem-like filled node so the bonus reads as a treat, not a
      // plain "to-do". Sparkles (added in the stack below) sell it further.
      bg = c;
      fg = Colors.white;
      gradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF472B6), Color(0xFFA855F7)],
      );
      shadows = [
        BoxShadow(
          color: const Color(0xFFEC4899).withValues(alpha: 0.45),
          blurRadius: 22,
          offset: const Offset(0, 9),
        ),
        BoxShadow(
          color: const Color(0xFFA855F7).withValues(alpha: 0.30),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];
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
                  clipBehavior: Clip.none,
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
                    // Twinkling sparkles around the bonus node.
                    if (isBonus) ...[
                      Positioned(
                        top: -6,
                        right: 4,
                        child: _Sparkle(
                          t: t,
                          phase: 0.0,
                          size: 17,
                          color: Color(0xFFFFE08A),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        left: -6,
                        child: _Sparkle(
                          t: t,
                          phase: 0.5,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                      Positioned(
                        top: 14,
                        left: -8,
                        child: _Sparkle(
                          t: t,
                          phase: 0.25,
                          size: 10,
                          color: Color(0xFFFFD1F0),
                        ),
                      ),
                    ],
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
            if (level.isCompleted) _StarsBadge(stars: level.stars),
          ],
        ),
      ),
    );
  }
}

// ─── Bonus sparkle ────────────────────────────────────────────────────────────
/// A single twinkling sparkle. [t] is the node's pulse value; [phase] offsets
/// it so a cluster of sparkles shimmers out of sync.
class _Sparkle extends StatelessWidget {
  const _Sparkle({
    required this.t,
    required this.phase,
    required this.size,
    required this.color,
  });

  final double t;
  final double phase;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tw = (math.sin((t + phase) * math.pi * 2) + 1) / 2;
    return Opacity(
      opacity: 0.3 + 0.7 * tw,
      child: Transform.scale(
        scale: 0.65 + 0.5 * tw,
        child: Icon(
          Icons.auto_awesome,
          size: size,
          color: color,
          shadows: [Shadow(color: color.withValues(alpha: 0.8), blurRadius: 6)],
        ),
      ),
    );
  }
}

// ─── Stars badge ──────────────────────────────────────────────────────────────
/// The earned-stars rating, lifted into a glossy 3D pill so it stands clear of
/// the path connectors instead of getting lost among them.
class _StarsBadge extends StatelessWidget {
  const _StarsBadge({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const gold = Color(0xFFF59E0B);
    return Container(
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.surface, p.surfaceHigh],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: 0.30), width: 1),
        boxShadow: [
          BoxShadow(
            color: gold.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            _Star3D(filled: i < stars, dim: p.textTertiary),
          ],
        ],
      ),
    );
  }
}

/// A chunky, beveled star — a darker base behind the gold face plus a white
/// glint reads as a raised, three-dimensional star.
class _Star3D extends StatelessWidget {
  const _Star3D({required this.filled, required this.dim});

  final bool filled;
  final Color dim;

  @override
  Widget build(BuildContext context) {
    if (!filled) {
      return Icon(
        Icons.star_rounded,
        size: 18,
        color: dim.withValues(alpha: 0.4),
      );
    }
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Darker base, nudged down, gives the star "thickness".
          Transform.translate(
            offset: const Offset(0, 1.4),
            child: const Icon(
              Icons.star_rounded,
              size: 18,
              color: Color(0xFFB45309),
            ),
          ),
          // Gold face.
          const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFBBF24)),
          // Glossy top glint.
          Positioned(
            top: 2.5,
            child: Icon(
              Icons.star_rounded,
              size: 8,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
              child: Icon(Icons.lock_rounded, size: 20, color: p.textTertiary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Week ${PlanData.nextWeekNumber}',
                    style: text.titleMedium?.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    PlanData.nextWeekHint,
                    style: text.labelMedium?.copyWith(color: p.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: MockData.mathColor.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
