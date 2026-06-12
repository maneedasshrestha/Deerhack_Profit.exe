import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../home/domain/mock_data.dart';

// ═══════════════════════════════════════════════════════════════════════════
// DuelScreen — deliberately minimal. One idea: race a friend through the same
// mock questions in real time. One primary action, a short friends list, and
// a compact match history. Nothing else.
// ═══════════════════════════════════════════════════════════════════════════
class DuelScreen extends StatelessWidget {
  const DuelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
                child: StaggeredEntrance(child: _Hero())),
            const SliverToBoxAdapter(
                child: SectionHeader('Challenge a friend')),
            SliverToBoxAdapter(
                child: StaggeredEntrance(index: 1, child: _FriendsList())),
            const SliverToBoxAdapter(child: SectionHeader('Recent')),
            SliverToBoxAdapter(
                child: StaggeredEntrance(index: 2, child: _RecentList())),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }
}

// ─── Hero: the whole pitch in one screen-third ────────────────────────────────
class _Hero extends StatefulWidget {
  const _Hero();

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _searching = !_searching);
    if (_searching) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final wins = MockData.duelWins;
    final losses = MockData.duelLosses;
    final total = wins + losses;
    final rate = total == 0 ? 0 : (wins * 100) ~/ total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      child: Column(
        children: [
          // Two avatars, one VS — that's the concept.
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Transform.scale(
              scale: _searching
                  ? 1 + 0.02 * Curves.easeInOut.transform(_pulse.value)
                  : 1,
              child: child,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _HeroAvatar(label: MockData.userName[0], you: true),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Text(
                    'vs',
                    style: text.displayMedium?.copyWith(
                      color: p.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 30,
                    ),
                  ),
                ),
                _HeroAvatar(
                    label: _searching ? '…' : '?', you: false),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text('Race a friend', style: text.displayMedium),
          const SizedBox(height: 8),
          Text(
            'Same questions, live. Fastest correct answer wins.',
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '$wins wins · $losses losses · $rate% win rate',
            style: text.labelSmall?.copyWith(color: p.textTertiary),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: _searching ? 'Searching… tap to cancel' : 'Find a match',
            icon: _searching ? null : Icons.bolt_rounded,
            onTap: _toggle,
          ),
        ],
      ),
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  const _HeroAvatar({required this.label, required this.you});
  final String label;
  final bool you;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: you
            ? const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF9F5BFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: you ? null : p.surfaceHigh,
        border: you ? null : Border.all(color: p.hairline, width: 2),
        boxShadow: you
            ? [
                BoxShadow(
                  color: p.accent.withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          label,
          style: text.headlineSmall?.copyWith(
            color: you ? Colors.white : p.textTertiary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ─── Friends: plain rows, one action ──────────────────────────────────────────
class _FriendsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < MockData.friends.length; i++) ...[
              _FriendRow(friend: MockData.friends[i]),
              if (i < MockData.friends.length - 1)
                Divider(height: 0, thickness: 0.5, color: p.hairline),
            ],
          ],
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend});
  final Map<String, dynamic> friend;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final online = friend['online'] as bool;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: online ? p.accentSoft : p.surfaceHigh,
                child: Text(
                  friend['initials'] as String,
                  style: text.labelMedium?.copyWith(
                    color: online ? p.accent : p.textTertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: online
                        ? const Color(0xFF059669)
                        : p.textTertiary.withValues(alpha: 0.4),
                    border: Border.all(color: p.surface, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(friend['name'] as String, style: text.labelLarge),
          ),
          if (online)
            Pressable(
              onTap: () {},
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  'Challenge',
                  style: text.labelMedium?.copyWith(
                    color: p.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            Text('offline',
                style: text.labelSmall?.copyWith(color: p.textTertiary)),
        ],
      ),
    );
  }
}

// ─── Recent: one line per match ───────────────────────────────────────────────
class _RecentList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < MockData.duelHistory.length; i++) ...[
              _RecentRow(duel: MockData.duelHistory[i]),
              if (i < MockData.duelHistory.length - 1)
                Divider(height: 0, thickness: 0.5, color: p.hairline),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.duel});
  final Map<String, dynamic> duel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final isWin = duel['result'] == 'win';
    final color = isWin ? const Color(0xFF059669) : const Color(0xFFE11D48);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('vs ${duel['opponent']}', style: text.labelLarge),
          ),
          Text(
            '${duel['score']}',
            style: text.labelLarge
                ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 10),
          Text(
            duel['ago'] as String,
            style: text.labelSmall?.copyWith(color: p.textTertiary),
          ),
        ],
      ),
    );
  }
}
