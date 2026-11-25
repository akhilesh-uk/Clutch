import 'package:flutter/material.dart';

import '../engine/streaks.dart';
import '../state/app_state.dart';
import '../theme.dart';

const _weekLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

IconData badgeIcon(String id) => switch (id) {
      'first_win' => Icons.check_circle,
      'on_a_roll' => Icons.local_fire_department,
      'perfect_week' => Icons.emoji_events,
      'slayer' => Icons.military_tech,
      _ => Icons.star,
    };

Color _dotColor(DayStatus s) => switch (s) {
      DayStatus.green || DayStatus.todayGreen => C.green,
      DayStatus.red || DayStatus.todayRed => C.red,
      DayStatus.untracked || DayStatus.future => C.border,
    };

/// Compact card for the Survival screen: streak count + this week's dots.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppState.instance.stats;
    final onFire = st.current > 0;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StreakScreen())),
      child: Row(children: [
        Icon(Icons.local_fire_department, color: onFire ? C.accent : C.muted, size: 30),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${st.current}-day streak', style: heading(17)),
          Text('${st.greenThisWeek}/7 green this week', style: TextStyle(color: C.muted, fontSize: 12)),
        ]),
        const Spacer(),
        WeekDots(week: st.week, size: 12),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right, color: C.muted),
      ]),
    );
  }
}

class WeekDots extends StatelessWidget {
  final List<DayStatus> week;
  final double size;
  final bool labels;
  const WeekDots({super.key, required this.week, this.size = 12, this.labels = false});

  @override
  Widget build(BuildContext context) {
    if (labels) {
      // Big version: each day gets an equal share of the width.
      return LayoutBuilder(builder: (context, box) {
        final slot = box.maxWidth / week.length;
        final d = (slot * 0.78).clamp(18.0, size).toDouble();
        return Row(children: [
          for (var i = 0; i < week.length; i++) Expanded(child: Center(child: _dot(i, d))),
        ]);
      });
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < week.length; i++)
        Padding(padding: EdgeInsets.symmetric(horizontal: size * 0.2), child: _dot(i, size)),
    ]);
  }

  Widget _dot(int i, double size) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _dotColor(week[i]),
                border: (week[i] == DayStatus.todayGreen || week[i] == DayStatus.todayRed)
                    ? Border.all(color: C.text, width: size > 20 ? 2.5 : 1.5)
                    : null,
              ),
              child: size > 20 && (week[i] == DayStatus.green || week[i] == DayStatus.todayGreen)
                  ? Icon(Icons.check, color: Colors.white, size: size * 0.55)
                  : null,
            ),
            if (labels) ...[
              const SizedBox(height: 6),
              Text(_weekLetters[i], style: TextStyle(color: C.muted, fontSize: 12)),
            ],
          ]);
  }
}

class StreakScreen extends StatelessWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final st = state.stats;
        final weekDone = st.greenThisWeek;
        return Scaffold(
          backgroundColor: C.bg,
          appBar: AppBar(title: Text('Streaks & badges', style: heading(20))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Center(
                child: Column(children: [
                  Icon(Icons.local_fire_department, size: 72, color: st.current > 0 ? C.accent : C.muted),
                  Text('${st.current}', style: heading(56)),
                  Text('day streak', style: TextStyle(color: C.muted)),
                  const SizedBox(height: 4),
                  Text('Best: ${st.best} ${st.best == 1 ? 'day' : 'days'}', style: TextStyle(color: C.muted, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 28),
              Text('THIS WEEK', style: TextStyle(color: C.muted, fontSize: 12, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Panel(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                child: Column(children: [
                  Center(child: WeekDots(week: st.week, size: 34, labels: true)),
                  const SizedBox(height: 14),
                  Text(
                    st.week.contains(DayStatus.red) || st.week.contains(DayStatus.todayRed)
                        ? 'A red day broke this week. Next Monday is a fresh shot at Perfect Week.'
                        : 'Keep all 7 days green to earn Perfect Week. $weekDone done, ${7 - weekDone} to go.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: C.muted, height: 1.4),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Text(
                'A day stays green when you skip nothing and miss no deadline. Today counts once you get through it.',
                style: TextStyle(color: C.muted, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 28),
              Builder(builder: (context) {
                final earned = badgeDefs.where((b) => state.earnedBadges.contains(b.id)).toList();
                final next = badgeDefs.where((b) => !state.earnedBadges.contains(b.id)).toList();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('MY BADGES', style: TextStyle(color: C.muted, fontSize: 12, letterSpacing: 1.2)),
                    const SizedBox(width: 8),
                    Pill('${earned.length}', C.accent),
                  ]),
                  const SizedBox(height: 12),
                  if (earned.isEmpty)
                    Panel(
                      child: Row(children: [
                        Icon(Icons.emoji_events_outlined, color: C.muted, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('No badges yet. Finish a task or keep a day green to earn your first.',
                              style: TextStyle(color: C.muted, height: 1.4)),
                        ),
                      ]),
                    )
                  else
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.05,
                      children: [
                        for (final b in earned)
                          _badge(b, b.id == 'perfect_week' && st.perfectWeeks > 1 ? st.perfectWeeks : 1)
                      ],
                    ),
                  if (next.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Next up: ${next.first.title}. ${next.first.description}',
                        style: TextStyle(color: C.muted, fontSize: 13)),
                  ],
                ]);
              }),
              const SizedBox(height: 20),
              Center(
                child: Text('${st.totalDone} tasks finished · ${st.perfectWeeks} perfect weeks',
                    style: TextStyle(color: C.muted, fontSize: 13)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _badge(BadgeDef b, int count) {
    return Panel(
      borderColor: C.accent,
      borderWidth: 1.5,
      padding: const EdgeInsets.all(14),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(shape: BoxShape.circle, color: C.accent.withValues(alpha: 0.15)),
            child: Icon(badgeIcon(b.id), color: C.accent, size: 28),
          ),
          if (count > 1)
            Positioned(right: -8, top: -6, child: Pill('x$count', C.accent)),
        ]),
        const SizedBox(height: 10),
        Text(b.title, textAlign: TextAlign.center, style: TextStyle(color: C.text, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(b.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: C.muted, fontSize: 11, height: 1.3)),
      ]),
    );
  }
}
