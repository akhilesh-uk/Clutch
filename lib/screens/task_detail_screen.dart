import 'package:flutter/material.dart';

import '../engine/format.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'plans_screen.dart';
import 'task_actions.dart';
import 'task_form_screen.dart';

void openTaskDetail(BuildContext context, String taskId) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: taskId)));
}

/// Everything about one task: what it is, deadline, effort, risk and its
/// planned sessions.
class TaskDetailScreen extends StatelessWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final t = state.byId(taskId);
        if (t == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('This task was deleted.', style: TextStyle(color: C.muted))),
          );
        }
        final now = DateTime.now();
        final ins = state.plan.insights[t.id];
        final sessions = state.plan.blocks.where((b) => b.taskId == t.id).toList();
        final progress = t.estHours <= 0 ? 0.0 : (t.doneHours / t.estHours).clamp(0.0, 1.0).toDouble();
        final risky = ins?.atRisk ?? false;
        final left = t.dueAt.difference(now);

        return Scaffold(
          backgroundColor: C.bg,
          appBar: AppBar(
            actions: [
              IconButton(
                tooltip: 'Edit',
                icon: Icon(Icons.edit_outlined, color: C.text),
                onPressed: () => openTaskForm(context, edit: t),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, color: C.red),
                onPressed: () => _confirmDelete(context, t),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                Pill(taskTypeLabel(t.type), C.accent),
                if (t.subject != null && t.subject!.isNotEmpty) Pill(t.subject!, C.muted),
                if (t.isDone) Pill('Done', C.green),
                if (!t.isDone && risky) Pill('At risk', C.red),
                if (!t.isDone && ins != null) PriorityChip(ins.priority),
              ]),
              const SizedBox(height: 14),
              Text(t.title, style: heading(28)),
              const SizedBox(height: 10),
              Text(
                t.notes.isNotEmpty ? t.notes : 'No description yet. Tap edit to add what this task is about.',
                style: TextStyle(color: t.notes.isNotEmpty ? C.text : C.muted, height: 1.5, fontSize: 15),
              ),
              const SizedBox(height: 20),

              // Ultra Pro AI analysis
              _aiSection(context, t, state),
              const SizedBox(height: 16),

              // deadline hero
              Panel(
                borderColor: risky && !t.isDone ? C.red.withValues(alpha: 0.6) : null,
                child: Row(children: [
                  Icon(Icons.flag_outlined, color: risky && !t.isDone ? C.red : C.accent, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Deadline', style: TextStyle(color: C.muted, fontSize: 12)),
                      Text('${dayLabel(t.dueAt, now)}, ${dateLabel(t.dueAt)} · ${hm(t.dueAt)}',
                          style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 16)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(left.isNegative ? 'Overdue' : _countdown(left),
                        style: heading(18, color: left.isNegative ? C.red : C.accent)),
                    Text(left.isNegative ? '' : 'left', style: TextStyle(color: C.muted, fontSize: 12)),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),

              // stats grid
              Row(children: [
                Expanded(child: _stat('Estimated', fmtH(t.estHours), Icons.timer_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _stat('Remaining', fmtH(t.remaining), Icons.hourglass_bottom)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _stat('Time available', ins == null ? '-' : fmtH(ins.available), Icons.event_available)),
                const SizedBox(width: 10),
                Expanded(
                  child: _stat(
                    'Slack',
                    ins == null ? '-' : (ins.slack < 0 ? '-${fmtH(-ins.slack)}' : fmtH(ins.slack)),
                    Icons.speed,
                    color: ins != null && ins.slack < 0 ? C.red : null,
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              // progress
              _label('PROGRESS'),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: progress, minHeight: 10, color: C.accent, backgroundColor: C.border),
              ),
              const SizedBox(height: 6),
              Text('${fmtH(t.doneHours)} of ${fmtH(t.estHours)} done',
                  style: TextStyle(color: C.muted, fontSize: 13)),
              if (!t.isDone)
                Slider(
                  value: t.doneHours.clamp(0, t.estHours).toDouble(),
                  min: 0,
                  max: t.estHours,
                  divisions: (t.estHours * 2).round().clamp(1, 80).toInt(),
                  activeColor: C.accent,
                  label: fmtH(t.doneHours),
                  onChanged: (v) => state.updateTask(t.id, doneHours: v),
                ),
              const SizedBox(height: 12),

              // importance
              _label('IMPORTANCE'),
              Row(children: [
                for (var i = 1; i <= 5; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(i <= t.importance ? Icons.circle : Icons.circle_outlined,
                        size: 14, color: i <= t.importance ? C.accent : C.border),
                  ),
                const SizedBox(width: 8),
                Text('${t.importance}/5', style: TextStyle(color: C.text, fontWeight: FontWeight.w700)),
              ]),
              if (t.importanceReason.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(t.importanceReason, style: TextStyle(color: C.muted)),
              ],
              if (t.missedCount > 0) ...[
                const SizedBox(height: 8),
                Text('Skipped ${t.missedCount} time${t.missedCount == 1 ? '' : 's'} so far.',
                    style: const TextStyle(color: C.yellow)),
              ],
              const SizedBox(height: 20),

              // planned sessions
              if (!t.isDone) ...[
                _label('PLANNED SESSIONS'),
                if (sessions.isEmpty)
                  Text(
                    risky ? 'No time left before the deadline. Talk to CLUTCH to rethink it.' : 'Nothing scheduled yet.',
                    style: TextStyle(color: risky ? C.red : C.muted),
                  ),
                for (final b in sessions.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Panel(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(children: [
                        SizedBox(
                          width: 90,
                          child: Text(dayLabel(b.start, now),
                              style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                            child: Text('${hm(b.start)} – ${hm(b.end)}', style: TextStyle(color: C.muted))),
                        Text(fmtH(b.hours), style: TextStyle(color: C.accent, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                if (sessions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(sessions.first.reason, style: TextStyle(color: C.muted, fontSize: 13, height: 1.4)),
                ],
                const SizedBox(height: 24),
              ],

              // actions
              if (!t.isDone)
                TaskActions(task: t)
              else
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: C.accent, side: BorderSide(color: C.border)),
                  onPressed: () => state.reopen(t.id),
                  child: const Text('Mark as not done'),
                ),
              const SizedBox(height: 16),
              Text('Added ${dateLabel(t.createdAt)}', style: TextStyle(color: C.muted, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _aiSection(BuildContext context, Task t, AppState state) {
    if (!state.settings.ultra) {
      return Panel(
        onTap: () => openPlans(context),
        child: Row(children: [
          Icon(Icons.auto_awesome, color: C.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Coming soon in Ultra Pro: AI breaks this task into steps and estimates the real time it needs.',
                style: TextStyle(color: C.muted, height: 1.4)),
          ),
          Pill('Soon', C.accent),
        ]),
      );
    }
    final total = t.aiSteps.fold<int>(0, (a, s) => a + s.minutes);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.accent.withValues(alpha: 0.45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_awesome, color: C.accent, size: 18),
          const SizedBox(width: 8),
          Text('AI ANALYSIS', style: TextStyle(color: C.accent, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (t.aiDifficulty.isNotEmpty) Pill(t.aiDifficulty, C.accent),
        ]),
        const SizedBox(height: 10),
        if (t.aiAnalyzing)
          Row(children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: C.accent)),
            const SizedBox(width: 10),
            Text('Analysing this task…', style: TextStyle(color: C.muted)),
          ])
        else if (!t.aiAnalyzed)
          Text('Not analysed yet.', style: TextStyle(color: C.muted))
        else ...[
          Text('${t.aiSteps.length} steps · about ${fmtH(total / 60.0)} in total',
              style: TextStyle(color: C.text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (var i = 0; i < t.aiSteps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: C.accent.withValues(alpha: 0.2)),
                  child: Text('${i + 1}', style: TextStyle(color: C.accent, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(t.aiSteps[i].title, style: TextStyle(color: C.text))),
                Text('${t.aiSteps[i].minutes} min', style: TextStyle(color: C.muted, fontSize: 13)),
              ]),
            ),
        ],
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: t.aiAnalyzing ? null : () => state.analyzeTask(t.id),
            icon: Icon(Icons.refresh, color: C.accent, size: 18),
            label: Text(t.aiAnalyzed ? 'Re-analyse' : 'Analyse now', style: TextStyle(color: C.accent)),
          ),
        ),
      ]),
    );
  }

  static String _countdown(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: TextStyle(color: C.muted, fontSize: 12, letterSpacing: 1.2)),
      );

  Widget _stat(String label, String value, IconData icon, {Color? color}) => Panel(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(icon, color: color ?? C.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: C.muted, fontSize: 12)),
              Text(value, style: heading(18, color: color)),
            ]),
          ),
        ]),
      );

  Future<void> _confirmDelete(BuildContext context, Task t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        title: Text('Delete task?', style: heading(20)),
        content: Text('"${t.title}" will be removed and your plan rebalanced.', style: TextStyle(color: C.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: C.muted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: C.red))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      Navigator.of(context).pop();
      AppState.instance.deleteTask(t.id);
    }
  }
}
