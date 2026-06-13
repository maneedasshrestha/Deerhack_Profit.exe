import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../application/auth_providers.dart';
import '../../domain/auth_account.dart';
import '../widgets/google_logo.dart';

// ═══════════════════════════════════════════════════════════════════════════
// WelcomeScreen — the front door. A friendly mascot greets you, the brand and
// its promise sit just below, three reasons to be here, and a single way in:
// Continue with Google. The actual sign-in is delegated to AuthService (mocked
// today), so this screen never changes when real auth lands. On success it
// hands the account up; the onboarding flow takes it from there.
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
      body: Stack(
        children: [
          // Ambient backdrop — two soft accent washes that bleed in from the
          // top corners, giving the flat background gentle depth.
          const Positioned.fill(child: _AmbientGlow()),
          SafeArea(
            child: Column(
              children: [
                // The hero block, vertically centered in the space above the
                // footer — mascot, brand, and promise as one balanced unit.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _MascotHero(),
                        const SizedBox(height: 24),
                        StaggeredEntrance(
                          index: 1,
                          child: Text(
                            'नित्यम्',
                            textAlign: TextAlign.center,
                            style: text.displayMedium?.copyWith(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        StaggeredEntrance(
                          index: 2,
                          child: Text(
                            'Your exam, planned week by week —\nand a coach that grows with you.',
                            textAlign: TextAlign.center,
                            style: text.bodyLarge?.copyWith(
                              color: p.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _Footer(signingIn: _signingIn, onContinue: _continueWithGoogle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ambient glow: soft accent washes anchored to the top of the screen ───────
class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            p.accent.withValues(alpha: 0.10),
            p.bg.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.42],
        ),
      ),
    );
  }
}

// ─── Mascot hero: the seal, floating over a soft breathing halo ───────────────
class _MascotHero extends StatefulWidget {
  const _MascotHero();

  @override
  State<_MascotHero> createState() => _MascotHeroState();
}

class _MascotHeroState extends State<_MascotHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: 260,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_c.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              // Breathing halo behind the mascot.
              Transform.scale(
                scale: 0.96 + 0.06 * t,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        p.accent.withValues(alpha: 0.22 + 0.06 * t),
                        p.accent.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.72],
                    ),
                  ),
                ),
              ),
              // The mascot, drifting gently up and down.
              Transform.translate(
                offset: Offset(0, -6 * t),
                child: child,
              ),
            ],
          );
        },
        child: Image.asset(
          'lib/assets/mascot/onboarding.png',
          width: 230,
          height: 230,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
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
