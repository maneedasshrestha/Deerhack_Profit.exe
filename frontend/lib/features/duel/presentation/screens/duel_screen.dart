import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../home/domain/mock_data.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DuelScreen — battle arena lobby
// ═══════════════════════════════════════════════════════════════════════════════
class DuelScreen extends StatelessWidget {
  const DuelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      // Gradient bg — darker and more intense than the learn tab.
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: p.isDark
                ? [const Color(0xFF0D0D1A), const Color(0xFF1A0A2E)]
                : [const Color(0xFFF0EDFF), const Color(0xFFEDE9FE)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _DuelHeader()),
              SliverToBoxAdapter(child: _UserStatsCard()),
              SliverToBoxAdapter(child: _FindMatchButton()),
              SliverToBoxAdapter(child: _SectionLabel('Challenge a friend')),
              SliverToBoxAdapter(child: _FriendsSection()),
              SliverToBoxAdapter(child: _SectionLabel('Recent battles')),
              SliverToBoxAdapter(child: _HistorySection()),
              SliverToBoxAdapter(child: _SectionLabel('This week\'s leaderboard')),
              SliverToBoxAdapter(child: _LeaderboardSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _DuelHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, color: p.accent, size: 28),
          const SizedBox(width: 10),
          Text('Duel Arena', style: text.headlineSmall),
          const Spacer(),
          _WinRateBadge(),
        ],
      ),
    );
  }
}

class _WinRateBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final wins = MockData.duelWins;
    final losses = MockData.duelLosses;
    final total = wins + losses;
    final rate = total == 0 ? 0 : (wins * 100) ~/ total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, size: 14, color: p.accent),
          const SizedBox(width: 5),
          Text('$rate% win rate',
              style: text.labelMedium?.copyWith(color: p.accent)),
        ],
      ),
    );
  }
}

// ─── User stats card ──────────────────────────────────────────────────────────
class _UserStatsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final wins = MockData.duelWins;
    final losses = MockData.duelLosses;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: p.isDark ? 0.7 : 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.hairline, width: 0.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: p.accent,
            child: Text(
              MockData.userName[0],
              style: text.headlineSmall?.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(MockData.userName, style: text.titleMedium),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(MockData.leagueIcon(MockData.league),
                        size: 14,
                        color: MockData.leagueColor(MockData.league)),
                    const SizedBox(width: 4),
                    Text(
                      '${MockData.league} league',
                      style: text.labelSmall?.copyWith(
                          color: MockData.leagueColor(MockData.league)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              _DuelStat(value: '$wins', label: 'Wins', color: const Color(0xFF10B981)),
              const SizedBox(height: 10),
              _DuelStat(value: '$losses', label: 'Losses', color: const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              _DuelStat(value: '1,380', label: 'Rating', color: p.accent),
              const SizedBox(height: 10),
              _DuelStat(value: '#8', label: 'Rank', color: const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DuelStat extends StatelessWidget {
  const _DuelStat({required this.value, required this.label, required this.color});
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(value,
            style: text.titleMedium?.copyWith(
                color: color, fontWeight: FontWeight.w800)),
        Text(label, style: text.labelSmall),
      ],
    );
  }
}

// ─── Find match button (animated) ─────────────────────────────────────────────
class _FindMatchButton extends StatefulWidget {
  @override
  State<_FindMatchButton> createState() => _FindMatchButtonState();
}

class _FindMatchButtonState extends State<_FindMatchButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _pulse = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _searching = !_searching);
    if (_searching) {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl.stop();
      _ctrl.animateTo(1.0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final c = p.accent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Transform.scale(
          scale: _searching ? _pulse.value : 1.0,
          child: child,
        ),
        child: GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _searching
                    ? [const Color(0xFFEF4444), const Color(0xFFFF6B6B)]
                    : [c, c.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (_searching ? const Color(0xFFEF4444) : c)
                      .withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_searching)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                else
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 26),
                const SizedBox(width: 12),
                Text(
                  _searching ? 'Searching for opponent…' : 'Find a match',
                  style: text.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_searching) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: p.textPrimary),
      ),
    );
  }
}

// ─── Friends section ──────────────────────────────────────────────────────────
class _FriendsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final f in MockData.friends) ...[
            _FriendCard(friend: f),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.friend});
  final Map<String, dynamic> friend;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final online = friend['online'] as bool;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: p.isDark ? 0.7 : 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: online ? p.accent.withValues(alpha: 0.4) : p.hairline,
          width: online ? 1.2 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: online
                        ? p.accent.withValues(alpha: 0.2)
                        : p.surfaceHigh,
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
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: online
                            ? const Color(0xFF10B981)
                            : const Color(0xFF6B7280),
                        border: Border.all(color: p.bg, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: MockData.leagueColor(friend['league'] as String)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  friend['league'] as String,
                  style: text.labelSmall?.copyWith(
                    color: MockData.leagueColor(friend['league'] as String),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            (friend['name'] as String).split(' ').first,
            style: text.labelLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '🔥 ${friend['streak']} streak',
            style: text.labelSmall?.copyWith(color: p.textTertiary),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: online ? () {} : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: online ? p.accent : p.surfaceHigh,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                online ? 'Challenge' : 'Offline',
                style: text.labelMedium?.copyWith(
                  color: online ? Colors.white : p.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Duel history ─────────────────────────────────────────────────────────────
class _HistorySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (final d in MockData.duelHistory) _HistoryItem(duel: d),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.duel});
  final Map<String, dynamic> duel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final isWin = duel['result'] == 'win';
    final resultColor =
        isWin ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: p.isDark ? 0.7 : 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.hairline, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: resultColor.withValues(alpha: 0.15),
              border: Border.all(color: resultColor.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                isWin ? 'W' : 'L',
                style: text.titleMedium?.copyWith(
                    color: resultColor, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('vs ${duel['opponent']}', style: text.labelLarge),
                const SizedBox(height: 2),
                Text(
                  '${duel['topic']}  ·  ${duel['ago']}',
                  style: text.labelSmall?.copyWith(color: p.textTertiary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                duel['score'] as String,
                style: text.titleMedium?.copyWith(
                    color: resultColor, fontWeight: FontWeight.w800),
              ),
              Text(isWin ? '🏆 Win' : '💪 Loss',
                  style: text.labelSmall?.copyWith(color: p.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Leaderboard ──────────────────────────────────────────────────────────────
class _LeaderboardSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: p.isDark ? 0.7 : 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.hairline, width: 0.5),
      ),
      child: Column(
        children: [
          for (var i = 0; i < MockData.leaderboard.length; i++) ...[
            _LeaderRow(entry: MockData.leaderboard[i], isLast: i == MockData.leaderboard.length - 1),
            if (i < MockData.leaderboard.length - 1)
              Divider(height: 0, thickness: 0.5, color: p.hairline),
          ],
        ],
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.entry, required this.isLast});
  final Map<String, dynamic> entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final isYou = entry['isYou'] == true;
    final rank = entry['rank'] as int;
    final rankColor = rank == 1
        ? const Color(0xFFF59E0B)
        : rank == 2
            ? const Color(0xFF9CA3AF)
            : rank == 3
                ? const Color(0xFFB45309)
                : p.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isYou ? p.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.vertical(
          top: Radius.zero,
          bottom: isLast ? const Radius.circular(20) : Radius.zero,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: text.labelLarge?.copyWith(
                  color: rankColor, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 16,
            backgroundColor: isYou
                ? p.accent
                : MockData.leagueColor(entry['league'] as String)
                    .withValues(alpha: 0.25),
            child: Text(
              entry['initials'] as String,
              style: text.labelSmall?.copyWith(
                color: isYou
                    ? Colors.white
                    : MockData.leagueColor(entry['league'] as String),
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry['name'] as String,
              style: text.labelLarge?.copyWith(
                color: isYou ? p.accent : p.textPrimary,
                fontWeight: isYou ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${entry['xp']} XP',
            style: text.labelMedium?.copyWith(
                color: isYou ? p.accent : p.textSecondary),
          ),
        ],
      ),
    );
  }
}
