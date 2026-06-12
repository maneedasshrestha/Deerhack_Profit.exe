import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/providers.dart';
import '../../application/session_args.dart';
import '../../domain/models/feynman_session.dart';
import '../widgets/clarity_sparkline.dart';
import '../widgets/orb/feynman_orb.dart';
import '../widgets/primary_button.dart';
import '../widgets/stage_indicator.dart';
import '../widgets/transcript_bubble.dart';
import 'live_voice_screen.dart';

/// Mode B — the reflection view. The payoff of the technique: the full
/// transcript, every flagged gap, and the clarity trend, all reviewable.
class ReflectionScreen extends ConsumerWidget {
  const ReflectionScreen({super.key, required this.session});

  final FeynmanSession session;

  void _teachAgain(BuildContext context, WidgetRef ref) {
    final repo = ref.read(sessionRepositoryProvider);
    final version = repo.nextVersion(session.conceptId);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: Motion.hero,
        pageBuilder: (_, _, _) => LiveVoiceScreen(
          args: SessionArgs(
            conceptId: session.conceptId,
            conceptName: session.conceptName,
            version: version,
          ),
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final repo = ref.watch(sessionRepositoryProvider);
    final versions = repo.versionsOf(session.conceptId);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: Icon(Icons.arrow_back_rounded, color: p.textSecondary),
                            tooltip: 'Back',
                          ),
                          Expanded(
                            child: Text(session.conceptName,
                                style: text.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _Header(session: session, versions: versions)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: StageIndicator(activeStage: session.gaps.isEmpty ? 2 : 1),
                    ),
                  ),
                  if (session.gaps.isNotEmpty)
                    SliverToBoxAdapter(child: _GapsSection(session: session)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Text('The conversation', style: text.titleMedium),
                    ),
                  ),
                  if (session.transcript.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('No turns were recorded this session.',
                            style: text.bodyMedium),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList.builder(
                        itemCount: session.transcript.length,
                        itemBuilder: (_, i) =>
                            TranscriptBubble(entry: session.transcript[i]),
                      ),
                    ),
                ],
              ),
            ),
            // Sticky "teach it again" action.
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: p.bg,
                border: Border(top: BorderSide(color: p.hairline, width: 0.5)),
              ),
              child: PrimaryButton(
                label: 'Teach it again',
                icon: Icons.refresh_rounded,
                onPressed: () => _teachAgain(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session, required this.versions});

  final FeynmanSession session;
  final List<FeynmanSession> versions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final clarity = session.finalClarity;
    final color = clarity >= 75
        ? p.positive
        : clarity >= 45
            ? p.accent
            : p.warning;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // The orb collapses into here from the live screen.
              Hero(
                tag: 'feynman-orb',
                flightShuttleBuilder: (a, b, c, d, e) => const OrbBadge(size: 64),
                child: const OrbBadge(size: 64),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('clarity', style: text.labelSmall),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$clarity',
                          style: text.displayLarge?.copyWith(color: color, fontSize: 52)),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('/100', style: text.labelMedium),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClaritySparkline(values: session.claritySeries),
          if (versions.length > 1) ...[
            const SizedBox(height: 16),
            _VersionsStrip(versions: versions, currentId: session.id),
          ],
        ],
      ),
    );
  }
}

/// v1 → v2 → v3 comparison so the learner can watch their explanation improve.
class _VersionsStrip extends StatelessWidget {
  const _VersionsStrip({required this.versions, required this.currentId});

  final List<FeynmanSession> versions;
  final String currentId;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your attempts', style: text.labelMedium),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < versions.length; i++) ...[
                _VersionPill(
                  session: versions[i],
                  isCurrent: versions[i].id == currentId,
                ),
                if (i < versions.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 14, color: p.textTertiary),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill({required this.session, required this.isCurrent});

  final FeynmanSession session;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrent ? p.accentSoft : p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? p.accent : p.hairline,
          width: isCurrent ? 1 : 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('v${session.version}', style: text.labelSmall),
          const SizedBox(height: 2),
          Text('${session.finalClarity}',
              style: text.titleMedium?.copyWith(
                  color: isCurrent ? p.accent : p.textPrimary)),
        ],
      ),
    );
  }
}

class _GapsSection extends StatelessWidget {
  const _GapsSection({required this.session});

  final FeynmanSession session;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 18, color: p.warning),
              const SizedBox(width: 8),
              Text('Gaps to close', style: text.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Terms you used without explaining them in plain words.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final term in session.gaps)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: p.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.warning.withValues(alpha: 0.3), width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: p.warning),
                      const SizedBox(width: 6),
                      Text(term, style: text.labelMedium?.copyWith(color: p.warning)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
