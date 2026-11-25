import '../config.dart';
import '../engine/format.dart';
import '../models/task.dart';
import 'claude.dart';

class TaskAnalysis {
  final List<TaskStep> steps;
  final String summary;
  final String difficulty;
  final int? importance;
  final String importanceReason;
  TaskAnalysis(this.steps, this.summary, this.difficulty, this.importance, this.importanceReason);

  double get hours => steps.fold<int>(0, (a, s) => a + s.minutes) / 60.0;
}

/// Ultra Pro: Claude breaks a task into steps and estimates the real time.
class UltraAI {
  static const _analystSystem = '''
You are the task analyst inside CLUTCH, a deadline planner for Indian college students.
Given one task, work out what it really involves and how long an average student needs.
Reply with ONLY a JSON object, no prose, in this exact shape:
{"summary": "one sentence on what the task involves",
 "difficulty": "easy" | "medium" | "hard",
 "steps": [{"title": "short action, max 6 words", "minutes": 45}],
 "importance": 1-5,
 "importance_reason": "one short sentence"}
Rules: 2 to 6 steps, in the order they should be done. Minutes are multiples of 15, each step 15 to 180.
Be realistic: include reading, doing and checking time. Exams and internals are importance 5, graded work 4, optional or reading 2.''';

  static Future<TaskAnalysis?> analyze(Task t) async {
    if (!Config.hasClaude) return null;
    final prompt = '''
Task: ${t.title}
Type: ${t.type.name}
Subject: ${t.subject ?? 'not given'}
Details: ${t.notes.isEmpty ? 'none' : t.notes}
Deadline: ${dateLabel(t.dueAt)} ${hm(t.dueAt)}
Current estimate: ${t.estHours} hours''';
    final reply = await Claude.text(_analystSystem, prompt, model: Config.claudeFastModel, maxTokens: 600);
    final j = Claude.extractJson(reply);
    if (j == null) return null;
    final steps = <TaskStep>[];
    for (final raw in (j['steps'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final title = (raw['title'] ?? '').toString().trim();
      var minutes = ((raw['minutes'] ?? 30) as num).round();
      if (title.isEmpty) continue;
      minutes = minutes.clamp(15, 240).toInt();
      steps.add(TaskStep(title, minutes));
    }
    if (steps.isEmpty) return null;
    final imp = j['importance'];
    return TaskAnalysis(
      steps.take(8).toList(),
      (j['summary'] ?? '').toString(),
      (j['difficulty'] ?? '').toString(),
      imp is num ? imp.round().clamp(1, 5).toInt() : null,
      (j['importance_reason'] ?? '').toString(),
    );
  }

  /// A short spoken-style summary of today's schedule.
  static Future<String?> dayPlan({
    required String name,
    required String tone,
    required String schedule,
    required String week,
  }) async {
    if (!Config.hasClaude) return null;
    final system = '''
You are CLUTCH, a deadline coach. $tone
Write today's plan for $name in 2 or 3 short sentences, under 60 words. No lists, no markdown, no emojis.
Mention what to start with and why, and one tip for the riskiest deadline. Use only the facts given.''';
    final reply = await Claude.text(system, 'Today\'s schedule:\n$schedule\n\nThis week:\n$week',
        model: Config.claudeFastModel, maxTokens: 300);
    return reply.isEmpty ? null : reply;
  }
}
