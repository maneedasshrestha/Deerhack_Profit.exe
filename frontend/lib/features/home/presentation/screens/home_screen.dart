import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/mock_data.dart';
import 'lesson_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// HomeScreen
// ═══════════════════════════════════════════════════════════════════════════════
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _DailyGoalCard()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: Text(
                        'Your learning path',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 4)),
                  SliverToBoxAdapter(child: _LearningPath()),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.hairline, width: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: p.accent,
                child: Text(
                  MockData.userName[0],
                  style: text.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hey, ${MockData.userName.split(' ').first}! 👋',
                      style: text.titleMedium,
                    ),
                    Text(
                      '${MockData.daysToExam} days to ${MockData.examName}',
                      style: text.labelSmall?.copyWith(color: p.textTertiary),
                    ),
                  ],
                ),
              ),
              _StatPill(
                icon: MockData.leagueIcon(MockData.league),
                label: MockData.league,
                iconColor: MockData.leagueColor(MockData.league),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatPill(
                icon: Icons.local_fire_department_rounded,
                label: '${MockData.streak}',
                iconColor: const Color(0xFFFF6B35),
              ),
              const SizedBox(width: 8),
              _StatPill(
                icon: Icons.diamond_rounded,
                label: '${MockData.xp} XP',
                iconColor: const Color(0xFF8B7CF6),
              ),
              const SizedBox(width: 8),
              _StatPill(
                icon: Icons.schedule_rounded,
                label: '${MockData.daysToExam}d left',
                iconColor: const Color(0xFF10B981),
              ),
              const Spacer(),
              _LevelBar(),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label, required this.iconColor});
  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.hairline, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(label, style: text.labelMedium),
        ],
      ),
    );
  }
}

class _LevelBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final progress = MockData.xp / MockData.xpForNextLevel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Lv.${MockData.level}',
          style: text.labelMedium?.copyWith(
            color: p.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 64,
            height: 7,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: p.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(p.accent),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Daily goal ───────────────────────────────────────────────────────────────
class _DailyGoalCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final progress = (MockData.dailyXpEarned / MockData.dailyXpGoal).clamp(0.0, 1.0);
    final remaining = MockData.dailyXpGoal - MockData.dailyXpEarned;
    final done = remaining <= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.hairline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                done ? "Today's goal complete! 🎉" : "Today's goal",
                style: text.titleMedium,
              ),
              const Spacer(),
              Text(
                '${MockData.dailyXpEarned} / ${MockData.dailyXpGoal} XP',
                style: text.labelSmall?.copyWith(color: p.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: p.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(
                done ? const Color(0xFF10B981) : p.accent,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            done
                ? 'Excellent! ${MockData.streak}-day streak maintained 🔥'
                : '$remaining XP to go  ·  complete lessons to earn XP',
            style: text.bodyMedium?.copyWith(color: p.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Learning path
// ═══════════════════════════════════════════════════════════════════════════════
// Zigzag offsets from centre for each node (cycles with modulo).
const _kOffsets = [45.0, 0.0, -45.0, 0.0];

class _LearningPath extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final unit in MockData.units) _UnitSection(unit: unit),
      ],
    );
  }
}

// ─── Unit section (banner + zigzag nodes) ─────────────────────────────────────
class _UnitSection extends StatelessWidget {
  const _UnitSection({required this.unit});
  final Unit unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _UnitBanner(unit: unit),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < unit.chapters.length; i++) ...[
                if (i > 0)
                  _PathConnector(
                    fromDx: _kOffsets[(i - 1) % _kOffsets.length],
                    toDx: _kOffsets[i % _kOffsets.length],
                    color: unit.color,
                    solid: unit.chapters[i - 1].isCompleted,
                  ),
                Transform.translate(
                  offset: Offset(_kOffsets[i % _kOffsets.length], 0),
                  child: _ChapterNode(chapter: unit.chapters[i], unit: unit),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Unit banner ──────────────────────────────────────────────────────────────
class _UnitBanner extends StatelessWidget {
  const _UnitBanner({required this.unit});
  final Unit unit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = unit.color;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c, c.withValues(alpha: 0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(unit.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.subject.toUpperCase(),
                  style: text.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(unit.title,
                    style: text.titleMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  '${unit.completedCount} / ${unit.totalCount} chapters done',
                  style: text.labelSmall
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: unit.progress,
                  strokeWidth: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
                Text(
                  '${(unit.progress * 100).round()}%',
                  style: text.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Path connector (diagonal line between two nodes) ─────────────────────────
class _PathConnector extends StatelessWidget {
  const _PathConnector({
    required this.fromDx,
    required this.toDx,
    required this.color,
    required this.solid,
  });

  final double fromDx;
  final double toDx;
  final Color color;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 28,
      child: CustomPaint(
        painter: _ConnectorPainter(
          fromDx: fromDx,
          toDx: toDx,
          lineColor: solid ? color : color.withValues(alpha: 0.22),
          dashed: !solid,
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({
    required this.fromDx,
    required this.toDx,
    required this.lineColor,
    required this.dashed,
  });

  final double fromDx;
  final double toDx;
  final Color lineColor;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final start = Offset(cx + fromDx, 0);
    final end = Offset(cx + toDx, size.height);
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    if (!dashed) {
      canvas.drawLine(start, end, paint);
      return;
    }
    const dashLen = 5.0;
    const gap = 5.0;
    final dist = (end - start).distance;
    var drawn = 0.0;
    while (drawn < dist) {
      final t1 = drawn / dist;
      final t2 = math.min((drawn + dashLen) / dist, 1.0);
      canvas.drawLine(
        Offset.lerp(start, end, t1)!,
        Offset.lerp(start, end, t2)!,
        paint,
      );
      drawn += dashLen + gap;
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.fromDx != fromDx ||
      old.toDx != toDx ||
      old.lineColor != lineColor ||
      old.dashed != dashed;
}

// ─── Chapter node ─────────────────────────────────────────────────────────────
class _ChapterNode extends StatefulWidget {
  const _ChapterNode({required this.chapter, required this.unit});
  final Chapter chapter;
  final Unit unit;

  @override
  State<_ChapterNode> createState() => _ChapterNodeState();
}

class _ChapterNodeState extends State<_ChapterNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _anim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    if (widget.chapter.isCurrent) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _openLesson(BuildContext context) {
    if (widget.chapter.isLocked) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            LessonScreen(chapter: widget.chapter, unit: widget.unit),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.chapter;
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final color = widget.unit.color;

    return GestureDetector(
      onTap: () => _openLesson(context),
      child: SizedBox(
        width: 112,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ch.isCurrent)
              _ActionBadge(label: 'CONTINUE', color: color)
            else if (ch.isAvailable)
              _ActionBadge(label: 'START', color: color, outlined: true),
            const SizedBox(height: 5),
            AnimatedBuilder(
              animation: _anim,
              builder: (context, child) => Stack(
                alignment: Alignment.center,
                children: [
                  if (ch.isCurrent)
                    Container(
                      width: 72 + 20 * _anim.value,
                      height: 72 + 20 * _anim.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(
                          alpha: 0.22 * (1 - _anim.value),
                        ),
                      ),
                    ),
                  child!,
                ],
              ),
              child: _NodeCircle(
                chapter: ch,
                unit: widget.unit,
                onTap: () => _openLesson(context),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              ch.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(
                color: ch.isLocked ? p.textTertiary : p.textSecondary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 5),
            if (!ch.isLocked) _StarRow(count: ch.stars, color: color),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

class _NodeCircle extends StatelessWidget {
  const _NodeCircle({
    required this.chapter,
    required this.unit,
    required this.onTap,
  });
  final Chapter chapter;
  final Unit unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ch = chapter;
    final c = unit.color;

    final Color bg;
    final Color iconColor;
    final IconData icon;
    final Border? border;
    final List<BoxShadow> shadows;

    if (ch.isLocked) {
      bg = p.surfaceHigh;
      iconColor = p.textTertiary;
      icon = Icons.lock_rounded;
      border = Border.all(color: p.hairline);
      shadows = const [];
    } else if (ch.isCompleted) {
      bg = c;
      iconColor = Colors.white;
      icon = unit.icon;
      border = null;
      shadows = [
        BoxShadow(
            color: c.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5)),
      ];
    } else if (ch.isCurrent) {
      bg = c.withValues(alpha: 0.15);
      iconColor = c;
      icon = Icons.play_arrow_rounded;
      border = Border.all(color: c, width: 3);
      shadows = [
        BoxShadow(
            color: c.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 6)),
      ];
    } else {
      bg = p.surface;
      iconColor = c;
      icon = unit.icon;
      border = Border.all(color: c.withValues(alpha: 0.6), width: 2.5);
      shadows = [
        BoxShadow(
            color: p.hairline, blurRadius: 6, offset: const Offset(0, 2)),
      ];
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: ch.isLocked ? null : onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: border,
            boxShadow: shadows,
          ),
          child: Center(child: Icon(icon, color: iconColor, size: 30)),
        ),
      ),
    );
  }
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({
    required this.label,
    required this.color,
    this.outlined = false,
  });
  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
        boxShadow: outlined
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Text(
        label,
        style: text.labelSmall?.copyWith(
          color: outlined ? color : Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              i < count ? Icons.star_rounded : Icons.star_border_rounded,
              size: 14,
              color: i < count
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF6B7280),
            ),
          ),
      ],
    );
  }
}
