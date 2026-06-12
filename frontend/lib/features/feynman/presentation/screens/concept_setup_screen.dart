import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../application/providers.dart';
import '../../application/session_args.dart';
import '../../domain/models/feynman_phase.dart';
import '../../domain/models/feynman_session.dart';
import '../widgets/orb/feynman_orb.dart';
import '../widgets/primary_button.dart';
import 'live_voice_screen.dart';

/// Entry screen for the Feynman coach. Pick a topic, explain it in your own
/// words, and the coach returns constructive criticism on exactly where the
/// explanation fell short.
class ConceptSetupScreen extends ConsumerStatefulWidget {
  const ConceptSetupScreen({super.key});

  @override
  ConsumerState<ConceptSetupScreen> createState() => _ConceptSetupScreenState();
}

class _ConceptSetupScreenState extends ConsumerState<ConceptSetupScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start(String name, {String? existingConceptId}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final repo = ref.read(sessionRepositoryProvider);
    final conceptId =
        existingConceptId ?? repo.conceptIdForName(trimmed) ?? _newConceptId(trimmed);
    final version = repo.nextVersion(conceptId);

    _focus.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveVoiceScreen(
          args: SessionArgs(
            conceptId: conceptId,
            conceptName: trimmed,
            version: version,
          ),
        ),
      ),
    );
  }

  String _newConceptId(String name) {
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return '$slug-${DateTime.now().microsecondsSinceEpoch}';
  }

  /// One clean row per topic. Defensive de-dupe by normalised name so legacy
  /// double-saved sessions can never show twice in the history.
  List<FeynmanSession> _cleanHistory(List<FeynmanSession> recents) {
    final seen = <String>{};
    final out = <FeynmanSession>[];
    for (final s in recents) {
      final key = s.conceptName.trim().toLowerCase();
      if (seen.add(key)) out.add(s);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final repo = ref.watch(sessionRepositoryProvider);
    final recents = _cleanHistory(repo.latestPerConcept());

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 36),
                    Center(
                      child: Hero(
                        tag: 'feynman-orb',
                        flightShuttleBuilder: (flightContext, anim, direction,
                                fromContext, toContext) =>
                            const OrbBadge(size: 120),
                        child: FeynmanOrb(
                          mode: OrbMode.idle,
                          level: 0,
                          reduceMotion: MediaQuery.of(context).disableAnimations,
                          size: 160,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text('Feynman coach', style: text.displayMedium),
                    const SizedBox(height: 10),
                    Text(
                      'Pick a topic and explain it out loud in your own '
                      'words. Your coach listens, probes the shaky spots, '
                      'and gives you constructive feedback on exactly where '
                      'your explanation fell short.',
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    _ConceptField(
                      controller: _controller,
                      focus: _focus,
                      onSubmit: () => _start(_controller.text),
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (context, value, _) => PrimaryButton(
                        label: 'Start session',
                        icon: Icons.graphic_eq_rounded,
                        onPressed:
                            value.text.trim().isEmpty ? null : () => _start(_controller.text),
                      ),
                    ),
                    if (recents.isNotEmpty) ...[
                      const SizedBox(height: 40),
                      Text('History', style: text.titleMedium),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverList.separated(
                itemCount: recents.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final s = recents[i];
                  final versions = repo.versionsOf(s.conceptId).length;
                  return _RecentCard(
                    session: s,
                    versionCount: versions,
                    onTap: () => _start(s.conceptName, existingConceptId: s.conceptId),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConceptField extends StatelessWidget {
  const _ConceptField({
    required this.controller,
    required this.focus,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.hairline, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        focusNode: focus,
        textInputAction: TextInputAction.go,
        onSubmitted: (_) => onSubmit(),
        style: text.bodyLarge,
        cursorColor: p.accent,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'e.g. projectile motion, integration, bonding…',
          hintStyle: text.bodyLarge?.copyWith(color: p.textTertiary),
        ),
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.session,
    required this.versionCount,
    required this.onTap,
  });

  final FeynmanSession session;
  final int versionCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.hairline, width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.conceptName,
                        style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                      '$versionCount ${versionCount == 1 ? 'session' : 'sessions'}',
                      style: text.labelSmall,
                    ),
                  ],
                ),
              ),
              _ClarityChip(value: session.finalClarity),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: p.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClarityChip extends StatelessWidget {
  const _ClarityChip({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final color = value >= 75
        ? p.positive
        : value >= 45
            ? p.accent
            : p.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$value', style: text.labelMedium?.copyWith(color: color)),
    );
  }
}
