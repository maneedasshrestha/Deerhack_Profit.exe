import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../home/domain/mock_data.dart';
import '../widgets/qr_share_sheet.dart';
import 'duel_race_screen.dart';
import 'qr_scan_screen.dart';

/// Push the head-to-head race over the whole shell (it's a full-screen flow).
void _startRace(BuildContext context, String opponentName) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => DuelRaceScreen(opponentName: opponentName),
    ),
  );
}

/// Open the simulated QR scanner full-screen.
void _openScanner(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const QrScanScreen(),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// DuelScreen — race a friend through the same questions in real time. The
// centrepiece is the pair of QR actions: scan a friend's code, or show your
// own. A quick random match and your online friends round it out.
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
            const SliverToBoxAdapter(child: StaggeredEntrance(child: _Hero())),
            const SliverToBoxAdapter(
                child: SectionHeader('Versus a friend')),
            const SliverToBoxAdapter(
                child: StaggeredEntrance(index: 1, child: _VersusActions())),
            const SliverToBoxAdapter(
                child: SectionHeader('Online now')),
            SliverToBoxAdapter(
                child: StaggeredEntrance(index: 2, child: _FriendsList())),
            // Clearance for the floating glass nav bar.
            const SliverToBoxAdapter(child: SizedBox(height: 124)),
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
  Timer? _matchTimer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300));
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _searching = !_searching);
    if (_searching) {
      _pulse.repeat(reverse: true);
      // Mock matchmaking: "find" an opponent after a short search.
      _matchTimer = Timer(const Duration(milliseconds: 1800), () {
        if (!mounted || !_searching) return;
        setState(() => _searching = false);
        _pulse.stop();
        _pulse.value = 0;
        _startRace(context, 'Priya Shah');
      });
    } else {
      _matchTimer?.cancel();
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
                _HeroAvatar(label: _searching ? '…' : '?', you: false),
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
          const SizedBox(height: 14),
          // Win/loss stat chips — a calmer, more elegant read than one line.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatPill(value: '$wins', label: 'wins', color: p.positive),
              const SizedBox(width: 10),
              _StatPill(value: '$losses', label: 'losses', color: p.textTertiary),
              const SizedBox(width: 10),
              _StatPill(value: '$rate%', label: 'win rate', color: p.accent),
            ],
          ),
          const SizedBox(height: 22),
          AppButton(
            label: _searching ? 'Searching… tap to cancel' : 'Quick match',
            icon: _searching ? null : Icons.bolt_rounded,
            tonal: true,
            onTap: _toggle,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: p.hairline),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: text.labelLarge
                ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 5),
          Text(label, style: text.labelSmall?.copyWith(color: p.textTertiary)),
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

// ─── Versus actions: scan a code, or show yours ───────────────────────────────
class _VersusActions extends StatelessWidget {
  const _VersusActions();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _ActionCard(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan a code',
              subtitle: 'Challenge by camera',
              filled: true,
              onTap: () => _openScanner(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionCard(
              icon: Icons.qr_code_2_rounded,
              title: 'My code',
              subtitle: 'Let a friend scan',
              filled: false,
              accent: p.accent,
              onTap: () => showQrShareSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.filled,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final c = accent ?? p.accent;

    return Pressable(
      onTap: onTap,
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: filled
              ? const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF9F5BFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: filled ? null : p.surface,
          borderRadius: BorderRadius.circular(20),
          border: filled ? null : Border.all(color: p.hairline, width: 1),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: c.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF2A2150).withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: filled
                    ? Colors.white.withValues(alpha: 0.2)
                    : c.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: filled ? Colors.white : c, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: text.titleMedium?.copyWith(
                color: filled ? Colors.white : p.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: text.labelSmall?.copyWith(
                color: filled
                    ? Colors.white.withValues(alpha: 0.8)
                    : p.textTertiary,
              ),
            ),
          ],
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
    // Online friends first — they're the only ones you can challenge live.
    final friends = [...MockData.friends]..sort((a, b) =>
        (b['online'] as bool ? 1 : 0).compareTo(a['online'] as bool ? 1 : 0));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < friends.length; i++) ...[
              _FriendRow(friend: friends[i]),
              if (i < friends.length - 1)
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
              onTap: () => _startRace(context, friend['name'] as String),
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
