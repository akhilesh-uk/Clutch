import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'voice_picker_screen.dart';

void openPlans(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlansScreen()));
}

class UltraBadge extends StatelessWidget {
  final double size;
  const UltraBadge({super.key, this.size = 11});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.8, vertical: size * 0.3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [C.accent, C.accent.withValues(alpha: 0.6)]),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.auto_awesome, color: C.onAccent, size: size + 2),
        const SizedBox(width: 4),
        Text('ULTRA PRO',
            style: TextStyle(
                color: C.onAccent, fontSize: size, fontWeight: FontWeight.w800, letterSpacing: 1)),
      ]),
    );
  }
}

/// Free vs Ultra Pro. No payment is taken yet: Ultra Pro activates in demo mode.
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final ultra = state.settings.ultra;
        return Scaffold(
          backgroundColor: C.bg,
          appBar: AppBar(title: Text('Plans', style: heading(20))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Text('Choose how hard CLUTCH works for you.', style: TextStyle(color: C.muted)),
              const SizedBox(height: 16),
              _planCard(
                context,
                title: 'Free',
                subtitle: 'Everything you need to beat deadlines',
                current: !ultra,
                highlight: false,
                features: const [
                  ('AI voice and chat assistant', Icons.chat_bubble_outline),
                  ('Smart priority and Survival Mode plan', Icons.bolt),
                  ('Workload calendar, streaks and badges', Icons.calendar_month),
                  ('Phone voice for replies', Icons.record_voice_over_outlined),
                ],
                button: null,
                comingSoon: false,
                onTap: () {},
              ),
              const SizedBox(height: 16),
              _planCard(
                context,
                title: 'Ultra Pro',
                subtitle: 'Your personal AI planner',
                current: ultra,
                highlight: true,
                features: const [
                  ('A faster, more personal AI brain', Icons.psychology_alt_outlined),
                  ('AI breaks every task into steps and estimates the real time', Icons.account_tree_outlined),
                  ('AI day plan that rewrites itself when new tasks arrive', Icons.auto_awesome),
                  ('Pick your own premium voice for CLUTCH', Icons.graphic_eq),
                ],
                button: 'Coming in the next update',
                comingSoon: true,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Ultra Pro is coming in the next update. Stay tuned!'),
                    )),
              ),
              if (ultra) ...[
                const SizedBox(height: 16),
                Panel(
                  onTap: () => openVoicePicker(context),
                  child: Row(children: [
                    Icon(Icons.graphic_eq, color: C.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('CLUTCH voice', style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
                        Text(state.settings.voiceName ?? 'Default voice',
                            style: TextStyle(color: C.muted, fontSize: 13)),
                      ]),
                    ),
                    Icon(Icons.chevron_right, color: C.muted),
                  ]),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Ultra Pro is not available yet. It arrives in the next CLUTCH update.',
                textAlign: TextAlign.center,
                style: TextStyle(color: C.muted, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _planCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool current,
    required bool highlight,
    required List<(String, IconData)> features,
    required String? button,
    required bool comingSoon,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: highlight ? C.accent.withValues(alpha: 0.08) : C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: highlight || current ? C.accent : C.border, width: highlight ? 1.8 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (highlight) const UltraBadge(size: 12) else Text(title, style: heading(22)),
          const Spacer(),
          if (current) Pill('Current plan', C.green),
          if (comingSoon) Pill('Coming soon', C.accent),
        ]),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(color: C.muted)),
        const SizedBox(height: 14),
        for (final f in features)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(f.$2, color: highlight ? C.accent : C.muted, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(f.$1, style: TextStyle(color: C.text, height: 1.3))),
            ]),
          ),
        if (button != null) ...[
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: highlight
                ? FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: comingSoon ? C.accent.withValues(alpha: 0.35) : C.accent,
                        foregroundColor: C.onAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: onTap,
                    child: Text(button, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: C.text,
                        side: BorderSide(color: C.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: onTap,
                    child: Text(button),
                  ),
          ),
        ],
      ]),
    );
  }
}
