import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../application/auth_providers.dart';
import '../../domain/auth_account.dart';
import '../widgets/google_logo.dart';

// ═══════════════════════════════════════════════════════════════════════════
// WelcomeScreen — the front door. One branded hero, three reasons to be here,
// and a single way in: Continue with Google. The actual sign-in is delegated to
// AuthService (mocked today), so this screen never changes when real auth lands.
// On success it hands the account up; the onboarding flow takes it from there.
// ═══════════════════════════════════════════════════════════════════════════
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key, required this.onSignedIn});

  /// Called with the freshly signed-in account once Google sign-in succeeds.
  final ValueChanged<AuthAccount> onSignedIn;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _signingIn = false;

  Future<void> _continueWithGoogle() async {
    if (_signingIn) return;
    setState(() => _signingIn = true);
    try {
      final account = await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted) return;
      if (account != null) {
        widget.onSignedIn(account);
      } else {
        // User dismissed the consent sheet — just reset the button.
        setState(() => _signingIn = false);
      }
    } catch (e, st) {
      // TEMP: surface the real error while debugging Google sign-in setup.
      debugPrint('Google sign-in failed: $e\n$st');
      if (!mounted) return;
      setState(() => _signingIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sign-in error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const Center(child: _HeroOrb()),
                    const SizedBox(height: 36),
                    StaggeredEntrance(
                      index: 1,
                      child: Text('ACELY',
                          style: text.displayMedium?.copyWith(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          )),
                    ),
                    const SizedBox(height: 10),
                    StaggeredEntrance(
                      index: 2,
                      child: Text(
                        'Your exam, planned week by week — and a coach that grows with you.',
                        style: text.bodyLarge?.copyWith(
                          color: p.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    const _ValueProp(
                      index: 3,
                      icon: Icons.event_available_rounded,
                      title: 'A plan shaped around your date',
                      subtitle: 'We count back from exam day and pace every week.',
                    ),
                    const SizedBox(height: 18),
                    const _ValueProp(
                      index: 4,
                      icon: Icons.center_focus_strong_rounded,
                      title: 'Practice that targets weak spots',
                      subtitle: 'Mock results decide what next week drills.',
                    ),
                    const SizedBox(height: 18),
                    const _ValueProp(
                      index: 5,
                      icon: Icons.sports_score_rounded,
                      title: 'Every week, toward the finish line',
                      subtitle: 'See momentum build all the way to D-day.',
                    ),
                  ],
                ),
              ),
            ),
            _Footer(signingIn: _signingIn, onContinue: _continueWithGoogle),
          ],
        ),
      ),
    );
  }
}

// ─── Hero orb: a soft, breathing gradient mark ────────────────────────────────
class _HeroOrb extends StatefulWidget {
  const _HeroOrb();

  @override
  State<_HeroOrb> createState() => _HeroOrbState();
}

class _HeroOrbState extends State<_HeroOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        final scale = 0.97 + 0.06 * t;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [p.orbCore, p.orbGlow],
                center: const Alignment(-0.3, -0.4),
                radius: 0.95,
              ),
              boxShadow: [
                BoxShadow(
                  color: p.orbGlow.withValues(alpha: 0.30 + 0.18 * t),
                  blurRadius: 36 + 12 * t,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 44),
    );
  }
}

// ─── A single "why you're here" row ───────────────────────────────────────────
class _ValueProp extends StatelessWidget {
  const _ValueProp({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final int index;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return StaggeredEntrance(
      index: index,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.accentSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 21, color: p.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: text.labelMedium
                        ?.copyWith(color: p.textTertiary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Footer: the Continue with Google button + fine print ─────────────────────
class _Footer extends StatelessWidget {
  const _Footer({required this.signingIn, required this.onContinue});

  final bool signingIn;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
      child: Column(
        children: [
          Pressable(
            onTap: signingIn ? null : onContinue,
            enabled: !signingIn,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.hairline, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2A2150).withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (signingIn) ...[
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(p.accent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Signing you in…',
                        style: text.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ] else ...[
                    const GoogleLogo(size: 20),
                    const SizedBox(width: 12),
                    Text('Continue with Google',
                        style: text.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'By continuing you agree to our Terms & Privacy Policy.',
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(color: p.textTertiary),
          ),
        ],
      ),
    );
  }
}
