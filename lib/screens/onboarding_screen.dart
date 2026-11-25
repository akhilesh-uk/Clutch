import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'auth_screen.dart';
import 'splash_screen.dart';

class _Page {
  final IconData icon;
  final String title;
  final String body;
  const _Page(this.icon, this.title, this.body);
}

const _pages = [
  _Page(Icons.mic_rounded, 'Speak your week',
      'Tell CLUTCH what is due, the way you would tell a friend. No forms, no tagging, no fuss.'),
  _Page(Icons.bolt_rounded, 'It plans like a pro',
      'CLUTCH estimates how long each task really takes and what to do first, with a reason for every block.'),
  _Page(Icons.calendar_month_rounded, 'Pressure before panic',
      'Your week turns green, yellow or red. Skip something and you see the cost before it becomes a crisis.'),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  bool get _last => _index == _pages.length - 1;

  Future<void> _finish() async {
    await AppState.instance.finishOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(fadeRoute(const AuthScreen()));
  }

  void _next() {
    if (_last) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(children: [
              ClutchWordmark(size: 18),
              const Spacer(),
              if (!_last)
                TextButton(onPressed: _finish, child: Text('Skip', style: TextStyle(color: C.muted))),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _pageView(_pages[i], i),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _pages.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index ? C.accent : C.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: C.accent,
                  foregroundColor: C.onAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _next,
                child: Text(_last ? 'Get started' : 'Next',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pageView(_Page p, int i) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (i == 0) ...[
          ClutchLogo(width: 170),
          const SizedBox(height: 36),
        ] else ...[
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: C.accent.withValues(alpha: 0.12),
              border: Border.all(color: C.accent.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Icon(p.icon, size: 56, color: C.accent),
          ),
          const SizedBox(height: 40),
        ],
        Text(p.title, textAlign: TextAlign.center, style: heading(30)),
        const SizedBox(height: 14),
        Text(p.body,
            textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 16, height: 1.5)),
      ]),
    );
  }
}
