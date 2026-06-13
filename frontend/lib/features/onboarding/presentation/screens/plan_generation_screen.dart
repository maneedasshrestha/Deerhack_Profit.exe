import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        const _PulseLoader(size: 132),
        const SizedBox(height: 40),
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

// ─── A self-contained pulsing-ring loader in the brand accent ────────────────
class _PulseLoader extends StatefulWidget {
  const _PulseLoader({required this.size});
  final double size;

  @override
  State<_PulseLoader> createState() => _PulseLoaderState();
}

class _PulseLoaderState extends State<_PulseLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = reduceMotion ? 0.0 : _c.value;
          return CustomPaint(
            painter: _PulsePainter(
              t: t,
              core: p.accent,
              glow: p.accentSoft,
            ),
          );
        },
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.t, required this.core, required this.glow});

  final double t;
  final Color core;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;

    // Two expanding, fading rings staggered by half a cycle.
    for (final phase in [0.0, 0.5]) {
      final v = (t + phase) % 1.0;
      final r = maxR * (0.42 + v * 0.58);
      final alpha = (1.0 - v) * 0.5;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = core.withValues(alpha: alpha);
      canvas.drawCircle(center, r, ring);
    }

    // Soft glow halo.
    canvas.drawCircle(
      center,
      maxR * 0.46,
      Paint()..color = glow.withValues(alpha: 0.6),
    );

    // Solid breathing core.
    final pulse = 0.40 + 0.06 * (1 + math.sin(t * 2 * math.pi));
    canvas.drawCircle(center, maxR * pulse, Paint()..color = core);
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t;
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
