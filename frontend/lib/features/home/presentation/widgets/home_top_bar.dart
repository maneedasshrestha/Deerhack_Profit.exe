import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../domain/mock_data.dart';
import '../../domain/plan_data.dart';
import '../screens/profile_screen.dart';

/// Slim top bar: wordmark + streak on the left, the account section on the
/// right — a compact exam-countdown ring and the avatar, both opening the
/// profile. No stat-pill clutter.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});

  void _openProfile(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.hairline, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            'acely',
            style: text.titleMedium?.copyWith(
              color: p.accent,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              fontSize: 21,
            ),
          ),
          const SizedBox(width: 12),
          TagChip(
            label: '${MockData.streak}',
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFF97316),
          ),
          const Spacer(),
          // Account section: countdown ring + avatar → profile.
          Pressable(
            onTap: () => _openProfile(context),
            child: Row(
              children: [
                ExamCountdownRing(size: 40),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: p.accent, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: p.accentSoft,
                    child: Text(
                      MockData.userName[0],
                      style: text.labelLarge?.copyWith(
                        color: p.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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

/// Days-to-exam at a glance: a ring that fills as prep weeks pass, with the
/// remaining day count in the middle.
class ExamCountdownRing extends StatelessWidget {
  const ExamCountdownRing({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    const week = PlanData.currentWeek;
    final elapsed = (week.weekNumber - 1) / week.totalWeeks;

    return ProgressRing(
      progress: elapsed,
      size: size,
      strokeWidth: 3.5,
      color: p.accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${PlanData.daysToExam}',
            style: text.labelMedium?.copyWith(
              color: p.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.3,
              height: 1,
            ),
          ),
          Text(
            'days',
            style: text.labelSmall?.copyWith(
              color: p.textTertiary,
              fontSize: size * 0.17,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
