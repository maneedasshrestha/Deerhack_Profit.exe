import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/providers.dart';
import '../../application/session_args.dart';
import '../../domain/models/feynman_phase.dart';
import '../../domain/models/feynman_session.dart';
import '../widgets/orb/feynman_orb.dart';
import '../widgets/primary_button.dart';
import 'live_voice_screen.dart';

/// Entry screen. Pick a concept to teach, or revisit a recent one. Generous
/// negative space; the orb sits up top as a calm preview of the live mode.
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

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final repo = ref.watch(sessionRepositoryProvider);
    final recents = repo.latestPerConcept();
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      tooltip: 'Toggle theme',
                      onPressed: () => ref.read(themeModeProvider.notifier).state =
                          themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                      icon: Icon(
                        themeMode == ThemeMode.dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
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
                    Text('Teach a student', style: text.displayMedium),
                    const SizedBox(height: 10),
                    Text(
                      'Explain a concept out loud as if teaching a curious kid. '
                      'They’ll react, ask the naive questions that expose your '
                      'gaps, and you’ll see exactly where your understanding '
                      'is fuzzy.',
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
                        label: 'Start teaching',
                        icon: Icons.graphic_eq_rounded,
                        onPressed:
                            value.text.trim().isEmpty ? null : () => _start(_controller.text),
                      ),
                    ),
                    if (recents.isNotEmpty) ...[
                      const SizedBox(height: 40),
                      Text('Recent concepts', style: text.titleMedium),
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
                separatorBuilder: (_, _) => const SizedBox(height: 12),
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
          hintText: 'e.g. photosynthesis, recursion, inflation…',
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
          padding: const EdgeInsets.all(16),
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
                    const SizedBox(height: 4),
                    Text(
                      '$versionCount ${versionCount == 1 ? 'attempt' : 'attempts'} · '
                      '${session.gaps.length} ${session.gaps.length == 1 ? 'gap' : 'gaps'}',
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
