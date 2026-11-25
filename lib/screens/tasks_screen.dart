import 'package:flutter/material.dart';

import '../engine/format.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'survival_screen.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return SafeArea(
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final now = DateTime.now();
          final open = state.openTasks;
          final done = state.tasks.where((t) => t.isDone).toList();
          return ListView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              Row(children: [
                Expanded(child: Text('Tasks', style: heading(28))),
                IconButton(
                  tooltip: 'Add task',
                  onPressed: () => openTaskForm(context),
                  icon: Icon(Icons.add_circle, color: C.accent, size: 32),
                ),
              ]),
              SizedBox(height: 4),
              Text('Ranked by priority. The bar shows hours needed against hours you have.',
                  style: TextStyle(color: C.muted)),
              SizedBox(height: 16),
              if (open.isEmpty)
                Panel(child: Text('Nothing pending.', style: TextStyle(color: C.muted))),
              for (final t in open) _TaskCard(task: t, now: now),
              if (done.isNotEmpty) ...[
                SizedBox(height: 20),
                Text('DONE', style: TextStyle(color: C.muted, fontSize: 12, letterSpacing: 1.2)),
                SizedBox(height: 8),
                for (final t in done)
                  ListTile(
                    onTap: () => openTaskDetail(context, t.id),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.check_circle, color: C.green),
                    title: Text(t.title,
                        style: TextStyle(
                            color: C.muted, decoration: TextDecoration.lineThrough)),
                    trailing: TextButton(
                        onPressed: () => state.reopen(t.id), child: Text('Undo')),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final DateTime now;
  const _TaskCard({required this.task, required this.now});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final ins = state.plan.insights[task.id];
    final need = task.remaining;
    final have = ins?.available ?? 0;
    final ratio = have <= 0 ? 1.0 : (need / have).clamp(0.0, 1.0).toDouble();
    final risky = ins?.atRisk ?? false;
    final barColor = risky ? C.red : (ratio > 0.6 ? C.yellow : C.green);

    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Panel(
        onTap: () => openTaskDetail(context, task.id),
        borderColor: risky ? C.red.withValues(alpha: 0.6) : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(task.title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            if (ins != null) PriorityChip(ins.priority),
            PopupMenuButton<String>(
              color: C.surface2,
              icon: Icon(Icons.more_vert, color: C.muted),
              onSelected: (v) {
                if (v == 'today') {
                  showImpact(context, state.completeToday(task.id));
                } else if (v == 'done') {
                  state.markDone(task.id);
                  showImpact(context, '${task.title} done.');
                } else if (v == 'missed') {
                  showImpact(context, 'Skipped today. ${state.markMissed(task.id)}');
                } else if (v == 'edit') {
                  openTaskForm(context, edit: task);
                } else if (v == 'delete') {
                  state.deleteTask(task.id);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'today', child: Text("Today's part done")),
                PopupMenuItem(value: 'done', child: Text('Task complete')),
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'missed', child: Text('Missed today')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ]),
          Text(
            '${task.type.name[0].toUpperCase()}${task.type.name.substring(1)} · due ${dueLabel(task.dueAt, now)}'
            '${task.missedCount > 0 ? ' · skipped ${task.missedCount}x' : ''}',
            style: TextStyle(color: C.muted, fontSize: 13),
          ),
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: ratio, minHeight: 6, color: barColor, backgroundColor: C.border),
          ),
          SizedBox(height: 6),
          Text(
            risky
                ? 'Needs ${fmtH(need)}, only ${fmtH(have)} left before the deadline.'
                : 'Needs ${fmtH(need)} · ${fmtH(have)} available · ${fmtH(ins?.slack ?? 0)} slack',
            style: TextStyle(color: risky ? C.red : C.muted, fontSize: 12),
          ),
          if (task.importanceReason.isNotEmpty) ...[
            SizedBox(height: 6),
            Text('Importance ${task.importance}/5 · ${task.importanceReason}',
                style: TextStyle(color: C.muted, fontSize: 12)),
          ],
        ]),
      ),
    );
  }
}
