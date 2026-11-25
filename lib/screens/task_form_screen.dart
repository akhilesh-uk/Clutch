import 'package:flutter/material.dart';

import '../engine/format.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme.dart';

void openTaskForm(BuildContext context, {Task? edit}) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskFormScreen(edit: edit)));
}

/// Add a task by hand, or edit an existing one.
class TaskFormScreen extends StatefulWidget {
  final Task? edit;
  const TaskFormScreen({super.key, this.edit});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _state = AppState.instance;
  late final _title = TextEditingController(text: widget.edit?.title ?? '');
  late final _subject = TextEditingController(text: widget.edit?.subject ?? '');
  late final _notes = TextEditingController(text: widget.edit?.notes ?? '');
  late TaskType _type = widget.edit?.type ?? TaskType.assignment;
  late DateTime _due = widget.edit?.dueAt ??
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 2, 23, 59);
  late double _hours = widget.edit?.estHours ?? 2;
  late int _importance = widget.edit?.importance ?? 3;
  String? _error;

  bool get _editing => widget.edit != null;

  static const _importanceLabels = ['Optional', 'Low', 'Normal', 'Graded', 'Critical'];

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _due.isBefore(now) ? now : _due,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (d == null) return;
    setState(() => _due = DateTime(d.year, d.month, d.day, _due.hour, _due.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_due));
    if (t == null) return;
    setState(() => _due = DateTime(_due.year, _due.month, _due.day, t.hour, t.minute));
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the task a title.');
      return;
    }
    final reason = _importanceLabels[_importance - 1];
    if (_editing) {
      _state.updateTask(
        widget.edit!.id,
        title: title,
        subject: _subject.text.trim(),
        notes: _notes.text.trim(),
        type: _type,
        dueAt: _due,
        estHours: _hours,
        importance: _importance,
        importanceReason: 'Set by you: $reason.',
      );
    } else {
      _state.addTasks([
        Task(
          id: _state.newId(),
          title: title,
          subject: _subject.text.trim().isEmpty ? null : _subject.text.trim(),
          notes: _notes.text.trim(),
          type: _type,
          dueAt: _due,
          estHours: _hours,
          importance: _importance,
          importanceReason: 'Set by you: $reason.',
        )
      ]);
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text(_editing ? 'Task updated. Plan rebalanced.' : '"$title" added. Plan rebalanced.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text(_editing ? 'Edit task' : 'New task', style: heading(20)),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save', style: TextStyle(color: C.accent, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _label('WHAT'),
          _field(_title, 'Task title, e.g. DBMS assignment 3'),
          const SizedBox(height: 10),
          _field(_subject, 'Subject (optional)'),
          const SizedBox(height: 10),
          _field(_notes, 'What is it about? (optional)', lines: 3),
          const SizedBox(height: 20),
          _label('TYPE'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in TaskType.values)
              ChoiceChip(
                label: Text(taskTypeLabel(t)),
                selected: _type == t,
                onSelected: (_) => setState(() => _type = t),
                selectedColor: C.accent,
                backgroundColor: C.surface,
                labelStyle: TextStyle(color: _type == t ? C.onAccent : C.text),
                side: BorderSide(color: _type == t ? C.accent : C.border),
                showCheckmark: false,
              ),
          ]),
          const SizedBox(height: 20),
          _label('DEADLINE'),
          Row(children: [
            Expanded(
              child: Panel(
                onTap: _pickDate,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(Icons.event, color: C.accent, size: 20),
                  const SizedBox(width: 10),
                  Text(dayLabel(_due, now) == 'Today' || dayLabel(_due, now) == 'Tomorrow'
                      ? '${dayLabel(_due, now)}, ${dateLabel(_due)}'
                      : dateLabel(_due)),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Panel(
              onTap: _pickTime,
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(Icons.schedule, color: C.accent, size: 20),
                const SizedBox(width: 10),
                Text(hm(_due)),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          _label('HOW LONG WILL IT TAKE'),
          Row(children: [
            Expanded(
              child: Slider(
                value: _hours,
                min: 0.5,
                max: 20,
                divisions: 39,
                activeColor: C.accent,
                onChanged: (v) => setState(() => _hours = v),
              ),
            ),
            SizedBox(width: 64, child: Text(fmtH(_hours), textAlign: TextAlign.right, style: heading(16))),
          ]),
          const SizedBox(height: 12),
          _label('HOW IMPORTANT'),
          Row(children: [
            for (var i = 1; i <= 5; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _importance = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 44,
                    decoration: BoxDecoration(
                      color: i <= _importance ? C.accent.withValues(alpha: 0.15 + 0.15 * i) : C.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: i <= _importance ? C.accent : C.border),
                    ),
                    child: Center(
                      child: Text('$i',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: i <= _importance ? C.text : C.muted)),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Text(_importanceLabels[_importance - 1], style: TextStyle(color: C.muted, fontSize: 13)),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: C.red)),
          ],
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: C.accent,
                foregroundColor: C.onAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _save,
              child: Text(_editing ? 'Save changes' : 'Add task',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: TextStyle(color: C.muted, fontSize: 12, letterSpacing: 1.2)),
      );

  Widget _field(TextEditingController c, String hint, {int lines = 1}) => TextField(
        controller: c,
        minLines: lines,
        maxLines: lines == 1 ? 1 : 6,
        style: TextStyle(color: C.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: C.muted),
          filled: true,
          fillColor: C.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.border)),
          enabledBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.border)),
          focusedBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.accent)),
        ),
      );
}
