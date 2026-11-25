import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../engine/format.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'plans_screen.dart';
import 'streak_screen.dart';
import 'talk_screen.dart';
import 'tutorial_screen.dart';
import 'task_detail_screen.dart';
import 'task_actions.dart';
import 'task_form_screen.dart';

/// Hour-by-hour plan for one day. Today by default; the calendar opens it
/// for other days.
class SurvivalScreen extends StatelessWidget {
  final DateTime? day;
  const SurvivalScreen({super.key, this.day});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final now = DateTime.now();
        final d = day ?? now;
        final isToday = dayOf(d) == dayOf(now);
        final plan = state.plan;
        final blocks = plan.blocksOn(d);
        final load = plan.loadOn(d);
        final atRisk = state.openTasks.where((t) => plan.insights[t.id]?.atRisk ?? false).toList();

        final body = ListView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            if (day == null)
              Row(children: [
                ClutchWordmark(),
                if (state.settings.ultra) ...[SizedBox(width: 8), UltraBadge(size: 9)],
                Spacer(),
                TextButton.icon(
                  onPressed: () => openTalk(context, initialText: 'Give me my briefing for today.'),
                  icon: Icon(Icons.graphic_eq, color: C.accent),
                  label: Text('Brief me', style: TextStyle(color: C.accent)),
                ),
                IconButton(
                  tooltip: 'Add task',
                  onPressed: () => openTaskForm(context),
                  icon: Icon(Icons.add_circle, color: C.accent, size: 30),
                ),
              ]),
            SizedBox(height: 16),
            Text('${isToday ? 'Today' : dayLabel(d, now)} · ${dateLabel(d)}',
                style: TextStyle(color: C.muted)),
            SizedBox(height: 4),
            Row(children: [
              Expanded(child: Text('Survival Mode', style: heading(28))),
              if (load != null)
                Pill('${levelName(load.level)} · ${(load.pressure * 100).round()}%', C.level(load.level)),
            ]),
            SizedBox(height: 16),
            if (day == null) ...[
              if (state.settings.ultra) ...[
                _AiDayPlanCard(),
                SizedBox(height: 12),
              ],
              StreakCard(),
              SizedBox(height: 12),
            ],
            if (isToday && atRisk.isNotEmpty) ...[
              _RiskBanner(titles: atRisk.map((t) => t.title).toList()),
              SizedBox(height: 16),
            ],
            if (state.tasks.isEmpty)
              _Empty(onDemo: () => openTutorial(context))
            else if (blocks.isEmpty)
              Panel(
                child: Text(
                  isToday
                      ? 'Nothing planned for the rest of today. Suspiciously calm.'
                      : 'Nothing planned on this day.',
                  style: TextStyle(color: C.muted),
                ),
              )
            else ...[
              if (isToday) _NowCard(block: blocks.first),
              if (isToday) SizedBox(height: 20),
              Text(isToday ? 'REST OF TODAY' : 'PLAN',
                  style: TextStyle(color: C.muted, fontSize: 12, letterSpacing: 1.2)),
              SizedBox(height: 8),
              for (final b in (isToday ? blocks.skip(1) : blocks)) _BlockTile(block: b),
              if (isToday && blocks.length == 1)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('That is the last block today.', style: TextStyle(color: C.muted)),
                ),
            ],
            if (load != null && load.overflow > 0.01) ...[
              SizedBox(height: 12),
              Text('${fmtH(load.overflow)} of work due ${isToday ? 'today' : 'this day'} cannot fit before its deadline.',
                  style: TextStyle(color: C.red)),
            ],
          ],
        );

        if (day == null) return SafeArea(child: body);
        return Scaffold(
          appBar: AppBar(backgroundColor: C.bg, title: Text(dateLabel(d), style: heading(18))),
          body: body,
        );
      },
    );
  }
}

void showImpact(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _NowCard extends StatelessWidget {
  final PlanBlock block;
  const _NowCard({required this.block});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final task = state.byId(block.taskId);
    if (task == null) return SizedBox.shrink();
    final now = DateTime.now();
    final live = !now.isBefore(block.start) && now.isBefore(block.end);
    final progress = live
        ? now.difference(block.start).inSeconds / block.end.difference(block.start).inSeconds
        : 0.0;
    final insight = state.plan.insights[task.id];

    return Panel(
      onTap: () => openTaskDetail(context, task.id),
      borderColor: C.accent,
      borderWidth: 1.5,
      padding: EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Pill(live ? 'NOW' : 'UP NEXT · ${hm(block.start)}', C.accent),
          Spacer(),
          if (insight != null) PriorityChip(insight.priority),
        ]),
        SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task.title, style: heading(22)),
              if (block.step != null) ...[
                SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.subdirectory_arrow_right, size: 16, color: C.accent),
                  SizedBox(width: 4),
                  Flexible(
                      child: Text('Step: ${block.step}',
                          style: TextStyle(color: C.accent, fontWeight: FontWeight.w600))),
                ]),
              ],
              SizedBox(height: 4),
              Text('${hm(block.start)} – ${hm(block.end)} · ${fmtH(block.hours)}',
                  style: TextStyle(color: C.muted)),
            ]),
          ),
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              value: live ? progress.clamp(0.0, 1.0).toDouble() : 0.0,
              strokeWidth: 5,
              color: C.accent,
              backgroundColor: C.border,
            ),
          ),
        ]),
        SizedBox(height: 12),
        Text(block.reason, style: TextStyle(color: C.muted, height: 1.35)),
        SizedBox(height: 16),
        TaskActions(task: task),
      ]),
    );
  }
}

class _BlockTile extends StatelessWidget {
  final PlanBlock block;
  const _BlockTile({required this.block});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final task = state.byId(block.taskId);
    if (task == null) return SizedBox.shrink();
    final insight = state.plan.insights[task.id];
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Panel(
        onTap: () => openTaskDetail(context, task.id),
        padding: EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 64,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hm(block.start), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(fmtH(block.hours), style: TextStyle(color: C.muted, fontSize: 12)),
            ]),
          ),
          Container(width: 2, height: 44, color: C.border, margin: EdgeInsets.only(right: 12)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(task.title,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                if (insight != null) PriorityChip(insight.priority),
              ]),
              if (block.step != null)
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text('Step: ${block.step}',
                      style: TextStyle(color: C.accent, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              SizedBox(height: 4),
              Text(block.reason, style: TextStyle(color: C.muted, fontSize: 13, height: 1.3)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _AiDayPlanCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final text = state.aiDayPlan;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.accent.withValues(alpha: 0.18), C.accent.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.accent.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_awesome, color: C.accent, size: 18),
          SizedBox(width: 8),
          Text('AI DAY PLAN', style: TextStyle(color: C.accent, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          Spacer(),
          if (state.aiDayPlanLoading)
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: C.accent)),
        ]),
        SizedBox(height: 8),
        Text(
          text ?? (state.aiDayPlanLoading ? 'Planning your day…' : 'Your AI day plan appears here once you have tasks.'),
          style: TextStyle(color: text == null ? C.muted : C.text, height: 1.45, fontSize: 14.5),
        ),
      ]),
    );
  }
}

class _RiskBanner extends StatelessWidget {
  final List<String> titles;
  const _RiskBanner({required this.titles});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.red.withValues(alpha: 0.6)),
      ),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, color: C.red),
        SizedBox(width: 10),
        Expanded(
          child: Text('AT RISK: ${titles.join(', ')}',
              style: TextStyle(color: C.red, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onDemo;
  const _Empty({required this.onDemo});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('No deadlines yet.', style: heading(20)),
        SizedBox(height: 6),
        Text('Tap the mic and tell CLUTCH what is due this week, the way you would tell a friend.',
            style: TextStyle(color: C.muted, height: 1.4)),
        SizedBox(height: 16),
        Row(children: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.accent, foregroundColor: C.onAccent),
            onPressed: () => openTalk(context, autoListen: true),
            child: Text('Talk to CLUTCH'),
          ),
          SizedBox(width: 12),
          TextButton(onPressed: onDemo, child: Text('Take the tour')),
        ]),
      ]),
    );
  }
}
