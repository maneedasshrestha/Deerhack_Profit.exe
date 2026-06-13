import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../domain/mock_data.dart';
import '../../domain/plan_data.dart';
import '../screens/profile_screen.dart';

/// Slim top bar: wordmark + streak on the left, the account section on the
/// right — a compact "D-day" exam countdown and the avatar, both opening the
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
          // Account section: "D-day" countdown + avatar → profile.
          Pressable(
            onTap: () => _openProfile(context),
            child: Row(
              children: [
                const _DDayBadge(),
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

/// The "D-day" exam countdown: a compact pill reading `D-101`. The colour warms
/// from the calm accent to amber, then red, as the exam closes in — turning the
/// badge into a low-key urgency cue.
class _DDayBadge extends StatelessWidget {
  const _DDayBadge();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final days = PlanData.daysToExam;

    final Color color;
    if (days <= 7) {
      color = p.recordingDot; // final stretch — red
    } else if (days <= 30) {
      color = p.warning; // closing in — amber
    } else {
      color = p.accent; // plenty of runway — calm violet
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            'D-$days',
            style: text.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
