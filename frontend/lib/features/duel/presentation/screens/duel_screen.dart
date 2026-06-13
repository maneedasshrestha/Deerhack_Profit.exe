import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../onboarding/application/auth_providers.dart';
import '../../../onboarding/application/onboarding_providers.dart';
import '../../../onboarding/presentation/widgets/profile_avatar.dart';
import '../../application/duel_providers.dart';
import '../../domain/duel_invite.dart';
import '../../domain/duel_leaderboard_entry.dart';
import '../../domain/duel_match.dart';
import '../../domain/duel_player.dart';
import 'duel_race_screen.dart';
import 'qr_scan_screen.dart';

/// Push a full-screen duel flow over the whole shell.
Future<void> _push(BuildContext context, Widget screen) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => screen),
  );
}

void _openScanner(BuildContext context) =>
    _push(context, const QrScanScreen());

/// Start a fresh run that becomes a shareable challenge.
void _startChallenge(BuildContext context, {DuelPlayer? target}) =>
    _push(context, DuelRaceScreen.challenge(target: target));

/// Play an existing challenge as the opponent.
void _acceptDuel(BuildContext context, DuelMatch duel) =>
    _push(context, DuelRaceScreen.accept(duel: duel));

// ═══════════════════════════════════════════════════════════════════════════
// DuelScreen — race a friend through the same questions, asynchronously. You
// set a pace (your run becomes a code + QR); a friend scans it and tries to
// beat it. Quick-match picks up an open challenge from the pool. Stats, history
// and the players list are all backed by Supabase (see duel_providers.dart).
// ═══════════════════════════════════════════════════════════════════════════
class DuelScreen extends ConsumerStatefulWidget {
  const DuelScreen({super.key});

  @override
  ConsumerState<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends ConsumerState<DuelScreen> {
  @override
  void initState() {
    super.initState();
    // Self-register (and heartbeat) so others can find and challenge us.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(duelControllerProvider).registerSelf();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(duelStatsProvider);
            ref.invalidate(duelPlayersProvider);
            ref.invalidate(incomingChallengesProvider);
            ref.invalidate(duelLeaderboardProvider);
            await ref.read(duelControllerProvider).registerSelf();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: const [
              SliverToBoxAdapter(child: StaggeredEntrance(child: _Hero())),
              SliverToBoxAdapter(child: SectionHeader('Versus a friend')),
              SliverToBoxAdapter(
                child: StaggeredEntrance(index: 1, child: _VersusActions()),
              ),
              SliverToBoxAdapter(child: _IncomingChallenges()),
              SliverToBoxAdapter(child: SectionHeader('Online now')),
              SliverToBoxAdapter(
                child: StaggeredEntrance(index: 2, child: _PlayersList()),
              ),
              SliverToBoxAdapter(child: SectionHeader('Leaderboard')),
              SliverToBoxAdapter(
                child: StaggeredEntrance(index: 3, child: _Leaderboard()),
              ),
              // Clearance for the floating glass nav bar.
              SliverToBoxAdapter(child: SizedBox(height: 124)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Hero: the whole pitch in one screen-third ────────────────────────────────
class _Hero extends ConsumerStatefulWidget {
  const _Hero();

  @override
  ConsumerState<_Hero> createState() => _HeroState();
}

class _HeroState extends ConsumerState<_Hero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _quickMatch() async {
    if (_searching) return;
    setState(() => _searching = true);
    _pulse.repeat(reverse: true);
    try {
      final open = await ref.read(duelControllerProvider).findOpenChallenge();
      if (!mounted) return;
      if (open != null) {
        _acceptDuel(context, open);
      } else {
        // No one's waiting — set the pace yourself; your run opens a challenge.
        _startChallenge(context);
      }
    } finally {
      if (mounted) setState(() => _searching = false);
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final me = ref.watch(currentPlayerProvider);
    // Same photo precedence as the profile screen / top bar: the learner's
    // uploaded photo, else the signed-in Google avatar.
    final myPhoto = ref.watch(userProfileProvider)?.photoPath ??
        ref.watch(signedInAvatarUrlProvider);
    final stats = ref.watch(duelStatsProvider);
    final wins = stats.valueOrNull?.wins ?? 0;
    final losses = stats.valueOrNull?.losses ?? 0;
    final rate = stats.valueOrNull?.winRate ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      child: Column(
        children: [
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
                _HeroAvatar(label: me.initials, you: true, photoPath: myPhoto),
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
          Text(
            'Same questions, your pace. Fastest correct answers win.',
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatPill(value: '$wins', label: 'wins', color: p.positive),
              const SizedBox(width: 10),
              _StatPill(
                value: '$losses',
                label: 'losses',
                color: p.textTertiary,
              ),
              const SizedBox(width: 10),
              _StatPill(value: '$rate%', label: 'win rate', color: p.accent),
            ],
          ),
          const SizedBox(height: 22),
          AppButton(
            label: _searching ? 'Finding a challenge…' : 'Quick match',
            icon: _searching ? null : Icons.bolt_rounded,
            tonal: true,
            onTap: _quickMatch,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.value,
    required this.label,
    required this.color,
  });
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
            style: text.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: text.labelSmall?.copyWith(color: p.textTertiary)),
        ],
      ),
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  const _HeroAvatar({required this.label, required this.you, this.photoPath});
  final String label;
  final bool you;

  /// The signed-in learner's photo, shown for the "you" side when set.
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    // Drop the "you" gradient/shadow framing onto the actual photo when present.
    final hasPhoto = (photoPath ?? '').isNotEmpty;
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: you && !hasPhoto
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
      child: hasPhoto
          ? ProfileAvatar(initials: label, photoPath: photoPath, size: 76)
          : Center(
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

// ─── Versus actions: scan a code, or set your own ─────────────────────────────
class _VersusActions extends StatelessWidget {
  const _VersusActions();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'Scan a code',
                  subtitle: 'Take a friend\'s challenge',
                  filled: true,
                  onTap: () => _openScanner(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.flag_rounded,
                  title: 'Set a pace',
                  subtitle: 'Play, then share your code',
                  filled: false,
                  accent: p.accent,
                  onTap: () => _startChallenge(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _showCodeEntry(context),
            icon: const Icon(Icons.keyboard_rounded, size: 18),
            label: const Text('Enter a code manually'),
          ),
        ],
      ),
    );
  }
}

/// A small dialog to type / paste a duel code, then take that challenge.
Future<void> _showCodeEntry(BuildContext context) async {
  final controller = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Consumer(
      builder: (context, ref, _) {
        Future<void> submit() async {
          final code = DuelInvite.resolveCode(controller.text);
          if (code == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('That doesn\'t look like a code')),
            );
            return;
          }
          final me = ref.read(currentPlayerProvider);
          final duel =
              await ref.read(duelControllerProvider).loadByCode(code);
          if (!context.mounted) return;
          if (duel == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No duel found for that code')),
            );
            return;
          }
          if (duel.challengerId == me.id || duel.isCompleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('That challenge isn\'t playable')),
            );
            return;
          }
          Navigator.of(dialogContext).pop();
          _acceptDuel(context, duel);
        }

        return AlertDialog(
          title: const Text('Enter duel code'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'ABC-DEF'),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(onPressed: submit, child: const Text('Take it')),
          ],
        );
      },
    ),
  );
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

// ─── Incoming challenges: targeted duels waiting for you to play ──────────────
class _IncomingChallenges extends ConsumerWidget {
  const _IncomingChallenges();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final incoming = ref.watch(incomingChallengesProvider).valueOrNull ?? [];
    if (incoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Challenges for you'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < incoming.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        ProfileAvatar(
                          initials: DuelPlayer.initialsFor(
                              incoming[i].challengerName),
                          photoPath: incoming[i].challengerPhotoUrl,
                          size: 36,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(incoming[i].challengerName,
                                  style: text.labelLarge),
                              Text(
                                '${incoming[i].topic} · scored '
                                '${incoming[i].challengerScore}/'
                                '${incoming[i].questionCount}',
                                style: text.labelSmall
                                    ?.copyWith(color: p.textTertiary),
                              ),
                            ],
                          ),
                        ),
                        Pressable(
                          onTap: () => _acceptDuel(context, incoming[i]),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: p.accentSoft,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Text(
                              'Beat it',
                              style: text.labelMedium?.copyWith(
                                color: p.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < incoming.length - 1)
                    Divider(height: 0, thickness: 0.5, color: p.hairline),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Players: registered duellists you can challenge ──────────────────────────
class _PlayersList extends ConsumerWidget {
  const _PlayersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final players = ref.watch(duelPlayersProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: players.when(
        loading: () => const AppCard(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
        error: (_, _) => AppCard(
          child: Text('Couldn\'t load players',
              style: text.bodyMedium?.copyWith(color: p.textTertiary)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return AppCard(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'No one else here yet. Set a pace and share your code to '
                  'get a friend in.',
                  style: text.bodyMedium?.copyWith(color: p.textTertiary),
                ),
              ),
            );
          }
          // Online players first.
          final sorted = [...list]
            ..sort((a, b) =>
                (b.isOnline ? 1 : 0).compareTo(a.isOnline ? 1 : 0));
          return AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < sorted.length; i++) ...[
                  _PlayerRow(player: sorted[i]),
                  if (i < sorted.length - 1)
                    Divider(height: 0, thickness: 0.5, color: p.hairline),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player});
  final DuelPlayer player;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final online = player.isOnline;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Stack(
            children: [
              ProfileAvatar(
                initials: player.initials,
                photoPath: player.photoUrl,
                size: 36,
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
            child: Text(player.displayName, style: text.labelLarge),
          ),
          Pressable(
            onTap: () => _startChallenge(context, target: player),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
          ),
        ],
      ),
    );
  }
}

// ─── Leaderboard: every duellist ranked by wins ───────────────────────────────
class _Leaderboard extends ConsumerWidget {
  const _Leaderboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final board = ref.watch(duelLeaderboardProvider);
    final meId = ref.watch(currentPlayerProvider).id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: board.when(
        loading: () => const AppCard(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
        error: (_, _) => AppCard(
          child: Text('Couldn\'t load the leaderboard',
              style: text.bodyMedium?.copyWith(color: p.textTertiary)),
        ),
        data: (all) {
          // A leaderboard only means something once duels are decided — show
          // players who've finished at least one, ranked highest wins first.
          final ranked = all.where((e) => e.played > 0).toList();
          if (ranked.isEmpty) {
            return AppCard(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'No duels finished yet. Win a race to claim the top spot.',
                  style: text.bodyMedium?.copyWith(color: p.textTertiary),
                ),
              ),
            );
          }
          return AppCard(
            padding: EdgeInsets.zero,
            // Clip so a highlighted (You) row at the top/bottom keeps the
            // card's rounded corners instead of poking out square.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  for (var i = 0; i < ranked.length; i++) ...[
                    _LeaderboardRow(
                      rank: i + 1,
                      entry: ranked[i],
                      isMe: ranked[i].id == meId,
                    ),
                    if (i < ranked.length - 1)
                      Divider(height: 0, thickness: 0.5, color: p.hairline),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.isMe,
  });

  final int rank;
  final DuelLeaderboardEntry entry;
  final bool isMe;

  // Medal tints for the top three; everyone else gets a plain numbered badge.
  static const _gold = Color(0xFFE9A23B);
  static const _silver = Color(0xFFAEB4C0);
  static const _bronze = Color(0xFFC9803E);

  Color? get _medal => switch (rank) {
        1 => _gold,
        2 => _silver,
        3 => _bronze,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final medal = _medal;

    return Container(
      // Subtly highlight the signed-in player's own standing.
      color: isMe ? p.accent.withValues(alpha: 0.06) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: medal != null
                  ? medal.withValues(alpha: 0.18)
                  : p.surfaceHigh,
            ),
            child: Text(
              '$rank',
              style: text.labelMedium?.copyWith(
                color: medal ?? p.textTertiary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ProfileAvatar(
            initials: entry.initials,
            photoPath: entry.photoUrl,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge?.copyWith(
                      color: isMe ? p.accent : null,
                      fontWeight: isMe ? FontWeight.w700 : null,
                    ),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  TagChip(label: 'You', color: p.accent),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.wins} ${entry.wins == 1 ? 'win' : 'wins'}',
                style: text.labelLarge?.copyWith(
                  color: p.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${entry.winRate}% · ${entry.played} played',
                style: text.labelSmall?.copyWith(color: p.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
