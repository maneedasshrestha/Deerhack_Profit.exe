import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../application/onboarding_providers.dart';
import '../../application/plan_providers.dart';
import '../../data/plan_service.dart';
import '../../domain/curated_plan.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PlanGenerationScreen — the loading state shown straight after signup, while
// the backend turns the learner's condition (exam, days left, target, hours)
// into a curated plan. On success it saves the plan, which flips
// curatedPlanProvider non-null and swaps the app into its main shell.
//
// It never dead-ends: if the backend can't be reached, the learner can retry
// or continue with a locally-built starter plan.
// ═══════════════════════════════════════════════════════════════════════════

enum _Status { loading, error }

class PlanGenerationScreen extends ConsumerStatefulWidget {
  const PlanGenerationScreen({super.key});

  @override
  ConsumerState<PlanGenerationScreen> createState() =>
      _PlanGenerationScreenState();
}

class _PlanGenerationScreenState extends ConsumerState<PlanGenerationScreen> {
  _Status _status = _Status.loading;
  String _error = '';

  Timer? _captionTimer;
  int _captionIndex = 0;

  static const _captions = [
    'Reading your timeline…',
    'Weighting subjects by marks…',
    'Pacing your weeks…',
    'Drafting milestones…',
    'Almost there…',
  ];

  // The plan should feel considered, so we hold the loader for at least this
  // long even if the backend (or the mock) answers instantly.
  static const _minShow = Duration(milliseconds: 2400);

  @override
  void initState() {
    super.initState();
    _startCaptions();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _captionTimer?.cancel();
    super.dispose();
  }

  void _startCaptions() {
    _captionTimer?.cancel();
    _captionTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!mounted) return;
      setState(() => _captionIndex = (_captionIndex + 1) % _captions.length);
    });
  }

  Future<void> _run() async {
    final profile = ref.read(userProfileProvider);
    if (profile == null) return; // Gated upstream; nothing to build.

    if (mounted) setState(() => _status = _Status.loading);
    _startCaptions();

    final service = ref.read(planServiceProvider);
    try {
      final results = await Future.wait([
        service.generate(profile),
        Future<void>.delayed(_minShow),
      ]);
      final plan = results.first as CuratedPlan;
      if (!mounted) return;
      // Persisting flips curatedPlanProvider → FeynmanApp swaps to MainShell
      // and this screen is disposed.
      await ref.read(curatedPlanProvider.notifier).complete(plan);
    } on PlanServiceException catch (e) {
      if (!mounted) return;
      _captionTimer?.cancel();
      setState(() {
        _status = _Status.error;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      _captionTimer?.cancel();
      setState(() {
        _status = _Status.error;
        _error = 'Something went wrong building your plan.';
      });
    }
  }

  /// Guaranteed local fallback so the learner is never stuck behind a down
  /// backend.
  Future<void> _useStarterPlan() async {
    final profile = ref.read(userProfileProvider);
    if (profile == null) return;
    HapticFeedback.lightImpact();
    final plan = MockPlanService.buildLocalPlan(profile);
    if (!mounted) return;
    await ref.read(curatedPlanProvider.notifier).complete(plan);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Center(
            child: _status == _Status.loading
                ? _LoadingView(
                    caption: _captions[_captionIndex],
                    examName: profile?.examName ?? 'your exam',
                    days: profile?.daysToExam(),
                  )
                : _ErrorView(
                    message: _error,
                    onRetry: _run,
                    onStarter: _useStarterPlan,
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Loading view: pulsing orb + heading + cycling caption ───────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView({
    required this.caption,
    required this.examName,
    required this.days,
  });

  final String caption;
  final String examName;
  final int? days;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _AssemblingPlanLoader(),
        const SizedBox(height: 36),
        Text(
          'Building your plan',
          style: text.displayMedium?.copyWith(fontSize: 30),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          days == null
              ? 'Tailoring it to $examName.'
              : 'Tailoring $examName around your $days days.',
          style: text.bodyMedium?.copyWith(color: p.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        // The cycling status line, cross-faded as it changes.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 360),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.25),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Row(
            key: ValueKey(caption),
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(p.accent),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                caption,
                style: text.labelLarge?.copyWith(color: p.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Loader: the plan assembling itself ──────────────────────────────────────
// Skeleton week-cards slide in one after another, and a soft violet sheen sweeps
// across them on a loop — so the wait reads as "your plan is being built", not
// "something is spinning". Honours reduce-motion (cards present, no sweep).
class _AssemblingPlanLoader extends StatefulWidget {
  const _AssemblingPlanLoader();

  @override
  State<_AssemblingPlanLoader> createState() => _AssemblingPlanLoaderState();
}

class _AssemblingPlanLoaderState extends State<_AssemblingPlanLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  // Per-card bar widths, so the stack looks composed rather than cloned.
  static const _bars = <List<double>>[
    [0.66, 0.42],
    [0.56, 0.50],
    [0.72, 0.38],
    [0.50, 0.46],
  ];

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Column(
              children: [
                for (var i = 0; i < _bars.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  StaggeredEntrance(
                    index: i,
                    baseDelay: const Duration(milliseconds: 140),
                    child: _SkeletonWeekCard(widths: _bars[i]),
                  ),
                ],
              ],
            ),
            if (!reduceMotion)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _shimmer,
                    builder: (context, _) => LayoutBuilder(
                      builder: (context, c) {
                        const band = 96.0;
                        final dx = (c.maxWidth + band) * _shimmer.value - band;
                        return Transform.translate(
                          offset: Offset(dx, 0),
                          child: Transform(
                            transform: Matrix4.skewX(-0.32),
                            child: Container(
                              width: band,
                              height: c.maxHeight,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    p.accent.withValues(alpha: 0),
                                    p.accent.withValues(alpha: 0.18),
                                    p.accent.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single placeholder plan card: a tinted leading tile + two shimmer bars.
class _SkeletonWeekCard extends StatelessWidget {
  const _SkeletonWeekCard({required this.widths});

  /// Fractional widths of the two text-line placeholders.
  final List<double> widths;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.hairline, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A2150).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(p, widthFactor: widths[0], height: 11),
                const SizedBox(height: 9),
                _bar(p, widthFactor: widths[1], height: 9),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(AppPalette p,
          {required double widthFactor, required double height}) =>
      FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: p.surfaceHigh,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      );
}

// ─── Error view: retry or fall back to a local starter plan ──────────────────
class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onStarter,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onStarter;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: p.warning.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.cloud_off_rounded, color: p.warning, size: 34),
        ),
        const SizedBox(height: 24),
        Text(
          'Couldn\'t build your plan',
          style: text.displayMedium?.copyWith(fontSize: 28),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          message,
          style: text.bodyMedium?.copyWith(color: p.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        AppButton(
          label: 'Try again',
          icon: Icons.refresh_rounded,
          onTap: onRetry,
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Continue with a starter plan',
          tonal: true,
          onTap: onStarter,
        ),
      ],
    );
  }
}
