import 'package:flutter/material.dart';

import '../models/task.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// The three task actions used on the Now card and the task detail page:
/// today's share done, whole task done, or missed today.
class TaskActions extends StatelessWidget {
  final Task task;
  const TaskActions({super.key, required this.task});

  void _show(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Row(children: [
      Expanded(
        child: _ActionButton(
          icon: Icons.today,
          label: "Today's part\ndone",
          color: C.accent,
          filled: true,
          onTap: () => _show(context, state.completeToday(task.id)),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _ActionButton(
          icon: Icons.task_alt,
          label: 'Task\ncomplete',
          color: C.green,
          filled: false,
          onTap: () {
            state.markDone(task.id);
            _show(context, '${task.title} complete. Nice work.');
          },
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _ActionButton(
          icon: Icons.close,
          label: 'Missed\ntoday',
          color: C.red,
          filled: false,
          onTap: () => _show(context, 'Skipped today. ${state.markMissed(task.id)}'),
        ),
      ),
    ]);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon, required this.label, required this.color, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = filled ? C.onAccent : color;
    return Material(
      color: filled ? color : color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: filled ? color : color.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700, height: 1.2)),
          ]),
        ),
      ),
    );
  }
}
