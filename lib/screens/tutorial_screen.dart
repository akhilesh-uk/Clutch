import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'calendar_screen.dart';
import 'streak_screen.dart';
import 'survival_screen.dart';
import 'tasks_screen.dart';

void openTutorial(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TutorialScreen()));
}

class _Step {
  final String title;
  final String body;
  final Widget Function() preview;
  _Step(this.title, this.body, this.preview);
}

/// Guided tour on a demo week. The user's own data is set aside and
/// restored when the tour ends (even if the app is closed mid-tour).
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _state = AppState.instance;
  bool _ready = false;
  int _i = 0;

  late final List<_Step> _steps = [
    _Step(
      'Welcome to the tour',
      'We loaded a demo student week so you can see CLUTCH in action. Your own tasks are safe and come back when the tour ends.',
      () => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClutchLogo(width: 170),
          const SizedBox(height: 20),
          ClutchWordmark(size: 28),
        ]),
      ),
    ),
    _Step(
      'Survival Mode',
      'Your plan for today. CLUTCH ranks tasks by deadline, effort and importance, and every block says why. Tap any task for its full details.',
      () => const SurvivalScreen(),
    ),
    _Step(
      'Streaks and badges',
      'A day stays green when you skip nothing and miss no deadline. Keep a whole week green to earn Perfect Week.',
      () => const StreakScreen(),
    ),
    _Step(
      'Your week at a glance',
      'Green is smooth, yellow is hectic, red is out of control. Skipped work carries forward and turns later days red.',
      () => const CalendarScreen(),
    ),
    _Step(
      'Tasks',
      'Every task with its slack bar. Use + to add one by hand. On each task: Today\'s part done, Task done, or Missed.',
      () => const TasksScreen(),
    ),
    _Step(
      'Talk to CLUTCH',
      'Tap the orange mic anywhere. Your words appear as you speak, then send. CLUTCH answers out loud.',
      () => _talkPreview(),
    ),
    _Step(
      'You are ready',
      'That is CLUTCH. Tap below to go back to your own week and start planning.',
      () => Center(child: Icon(Icons.rocket_launch, size: 96, color: C.accent)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _state.startTutorial();
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    // Leaving the tour any way (back button too) restores the user's data.
    if (_state.inTutorial) Future.microtask(_state.endTutorial);
    super.dispose();
  }

  Future<void> _finish() async {
    await _state.endTutorial();
    if (mounted) Navigator.of(context).pop();
  }

  static Widget _talkPreview() {
    Widget bubble(String text, bool mine) => Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: mine ? C.accent : C.surface,
              borderRadius: BorderRadius.circular(16),
              border: mine ? null : Border.all(color: C.border),
            ),
            child: Text(text, style: TextStyle(color: mine ? C.onAccent : C.text, height: 1.4)),
          ),
        );
    return ListView(padding: const EdgeInsets.all(16), children: [
      bubble('I have a DBMS assignment due Friday and an OS internal tomorrow morning.', true),
      bubble('Got it. OS internal first, it is due in 15 hours. DBMS gets two sessions on Thursday.', false),
      bubble('I am exhausted, can I skip OS prep tonight?', true),
      bubble('You can, but tomorrow goes red. Do just 45 minutes now and it stays yellow. Deal?', false),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_i];
    final last = _i == _steps.length - 1;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('Tour · ${_i + 1} of ${_steps.length}', style: heading(18)),
        actions: [
          TextButton(onPressed: _finish, child: Text('Exit', style: TextStyle(color: C.muted))),
        ],
      ),
      body: !_ready
          ? Center(child: CircularProgressIndicator(color: C.accent))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: C.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: C.accent.withValues(alpha: 0.5)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(step.title, style: heading(20)),
                    const SizedBox(height: 6),
                    Text(step.body, style: TextStyle(color: C.text, height: 1.45)),
                  ]),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: C.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: KeyedSubtree(key: ValueKey(_i), child: step.preview()),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(children: [
                    if (_i > 0)
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: C.text,
                              side: BorderSide(color: C.border),
                              padding: const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: () => setState(() => _i--),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_i > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: C.accent,
                            foregroundColor: C.onAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: last ? _finish : () => setState(() => _i++),
                        child: Text(last ? 'Start using CLUTCH' : 'Next',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }
}
