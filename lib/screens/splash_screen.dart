import 'package:flutter/material.dart';

import '../main.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart';

/// Animated start-up: the logo swings in, the wordmark rises, then the app
/// routes to onboarding, sign-in or the main screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  late final Animation<double> _logoScale = Tween(begin: 0.4, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack)));
  late final Animation<double> _logoFade =
      CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.3, curve: Curves.easeOut));
  late final Animation<double> _logoTurn = Tween(begin: -0.12, end: 0.0)
      .animate(CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)));
  late final Animation<double> _wordFade =
      CurvedAnimation(parent: _c, curve: const Interval(0.4, 0.7, curve: Curves.easeOut));
  late final Animation<Offset> _wordSlide = Tween(begin: const Offset(0, 0.6), end: Offset.zero)
      .animate(CurvedAnimation(parent: _c, curve: const Interval(0.4, 0.75, curve: Curves.easeOutCubic)));
  late final Animation<double> _tagFade =
      CurvedAnimation(parent: _c, curve: const Interval(0.65, 0.9, curve: Curves.easeOut));
  late final Animation<double> _glow =
      CurvedAnimation(parent: _c, curve: const Interval(0.3, 1.0, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(_route);
  }

  void _route() {
    if (!mounted) return;
    final state = AppState.instance;
    final Widget next;
    if (!state.onboarded) {
      next = const OnboardingScreen();
    } else if (!state.signedIn) {
      next = const AuthScreen();
    } else {
      next = Shell();
    }
    Navigator.of(context).pushReplacement(fadeRoute(next));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: C.accent.withValues(alpha: 0.25 * _glow.value),
                    blurRadius: 80,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Opacity(
                opacity: _logoFade.value,
                child: Transform.rotate(
                  angle: _logoTurn.value,
                  child: Transform.scale(scale: _logoScale.value, child: ClutchLogo(width: 190)),
                ),
              ),
            ),
            const SizedBox(height: 28),
            FadeTransition(
              opacity: _wordFade,
              child: SlideTransition(position: _wordSlide, child: ClutchWordmark(size: 34)),
            ),
            const SizedBox(height: 14),
            FadeTransition(
              opacity: _tagFade,
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'YOUR '),
                  TextSpan(text: 'DEADLINE', style: TextStyle(color: C.accent)),
                  const TextSpan(text: ' SURVIVAL AGENT'),
                ]),
                style: TextStyle(color: C.muted, fontSize: 12, letterSpacing: 3, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

PageRouteBuilder<void> fadeRoute(Widget page) => PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    );
