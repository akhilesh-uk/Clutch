import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'claude.dart';
import '../engine/engine.dart';
import '../engine/format.dart';
import '../models/settings.dart';
import '../models/task.dart';
import '../state/app_state.dart';

/// Conversational agent: Gemini talks and decides which tool to call;
/// the deterministic engine in AppState does all ranking and scheduling.
class ClutchAgent {
  ClutchAgent._();
  static final ClutchAgent instance = ClutchAgent._();

  final AppState _state = AppState.instance;
  final List<Map<String, dynamic>> _history = [];

  final List<Map<String, dynamic>> _claudeHistory = [];

  /// Which model answered the last message: 'claude' or 'gemini'.
  String lastBrain = 'gemini';

  void resetConversation() {
    _history.clear();
    _claudeHistory.clear();
  }

  /// Rebuilds the Gemini history from a saved chat so it can be continued.
  void loadHistory(List<ChatMessage> messages) {
    _claudeHistory.clear();
    for (final m in messages) {
      if (m.role == ChatRole.system) continue;
      final role = m.role == ChatRole.user ? 'user' : 'assistant';
      if (_claudeHistory.isNotEmpty && _claudeHistory.last['role'] == role) {
        _claudeHistory.last['content'] = '${_claudeHistory.last['content']}\n${m.text}';
      } else {
        _claudeHistory.add({'role': role, 'content': m.text});
      }
    }
    while (_claudeHistory.isNotEmpty && _claudeHistory.first['role'] != 'user') {
      _claudeHistory.removeAt(0);
    }
    _history.clear();
    for (final m in messages) {
      if (m.role == ChatRole.system) continue;
      _history.add({
        'role': m.role == ChatRole.user ? 'user' : 'model',
        'parts': [
          {'text': m.text}
        ],
      });
    }
    // Gemini expects the conversation to start with the user.
    while (_history.isNotEmpty && _history.first['role'] != 'user') {
      _history.removeAt(0);
    }
  }

  /// Ultra Pro answers with Claude (falls back to Gemini if Claude fails);
  /// Free uses Gemini.
  Future<String> send(String userText) async {
    if (_state.settings.ultra && Config.hasClaude) {
      try {
        final r = await _sendClaude(userText);
        lastBrain = 'claude';
        return r;
      } catch (e) {
        if (!Config.hasGemini) rethrow;
        // Rebuild Gemini's view of the chat (without the new message), then retry.
        final past = _state.chat.toList();
        if (past.isNotEmpty && past.last.role == ChatRole.user) past.removeLast();
        loadHistory(past);
      }
    }
    lastBrain = 'gemini';
    return _sendGemini(userText);
  }

  Future<String> _sendClaude(String userText) async {
    final rollback = _claudeHistory.length;
    if (_claudeHistory.isNotEmpty && _claudeHistory.last['role'] == 'user') {
      _claudeHistory.removeLast(); // keep roles alternating
    }
    _claudeHistory.add({'role': 'user', 'content': userText});
    try {
      for (var step = 0; step < 6; step++) {
        final res = await Claude.messages(
          system: _systemPrompt(),
          messages: _claudeHistory,
          tools: _claudeTools,
          maxTokens: 800,
        );
        final content = (res['content'] as List?) ?? const [];
        _claudeHistory.add({'role': 'assistant', 'content': content});
        final uses = content.whereType<Map>().where((b) => b['type'] == 'tool_use').toList();
        if (uses.isEmpty || res['stop_reason'] != 'tool_use') {
          final text = Claude.joinText(content);
          _trimClaude();
          return text.isEmpty ? 'Done.' : text;
        }
        final results = <Map<String, dynamic>>[];
        for (final u in uses) {
          Map<String, dynamic> out;
          try {
            out = _execute(u['name'] as String,
                u['input'] == null ? <String, dynamic>{} : Map<String, dynamic>.from(u['input'] as Map));
          } catch (e) {
            out = {'error': e.toString()};
          }
          results.add({'type': 'tool_result', 'tool_use_id': u['id'], 'content': jsonEncode(out)});
        }
        _claudeHistory.add({'role': 'user', 'content': results});
      }
      return 'I got tangled up there. Say that again?';
    } catch (e) {
      if (_claudeHistory.length > rollback) _claudeHistory.removeRange(rollback, _claudeHistory.length);
      rethrow;
    }
  }

  void _trimClaude() {
    while (_claudeHistory.length > 40) {
      _claudeHistory.removeAt(0);
      while (_claudeHistory.isNotEmpty &&
          !(_claudeHistory.first['role'] == 'user' && _claudeHistory.first['content'] is String)) {
        _claudeHistory.removeAt(0);
      }
    }
  }

  static List<Map<String, dynamic>> get _claudeTools => [
        for (final t in _tools)
          {
            'name': t['name'],
            'description': t['description'],
            'input_schema': t['parameters'] ?? {'type': 'object', 'properties': <String, dynamic>{}},
          }
      ];

  Future<String> _sendGemini(String userText) async {
    if (!Config.hasGemini) {
      return "I can't connect right now. Please try again in a moment.";
    }
    final rollback = _history.length;
    _history.add({
      'role': 'user',
      'parts': [
        {'text': userText}
      ]
    });
    try {
      for (var step = 0; step < 6; step++) {
        final content = await _generate();
        _history.add(content);
        final parts = (content['parts'] as List?) ?? const [];
        final calls = parts
            .whereType<Map>()
            .where((p) => p['functionCall'] != null)
            .map((p) => Map<String, dynamic>.from(p['functionCall'] as Map))
            .toList();

        if (calls.isEmpty) {
          final text = parts
              .whereType<Map>()
              .where((p) => p['text'] != null && p['thought'] != true)
              .map((p) => p['text'] as String)
              .join(' ')
              .trim();
          _trimHistory();
          return text.isEmpty ? 'Done.' : text;
        }

        final responses = <Map<String, dynamic>>[];
        for (final call in calls) {
          final name = call['name'] as String;
          final args = call['args'] == null
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(call['args'] as Map);
          Map<String, dynamic> result;
          try {
            result = _execute(name, args);
          } catch (e) {
            result = {'error': e.toString()};
          }
          responses.add({
            'functionResponse': {
              if (call['id'] != null) 'id': call['id'],
              'name': name,
              'response': result,
            }
          });
        }
        _history.add({'role': 'user', 'parts': responses});
      }
      return 'I got tangled up there. Say that again?';
    } catch (e) {
      _history.removeRange(rollback, _history.length);
      rethrow;
    }
  }

  void _trimHistory() {
    // Keep the conversation short; only cut at a plain user text turn so
    // function calls and their responses always stay paired.
    while (_history.length > 30) {
      _history.removeAt(0);
      while (_history.isNotEmpty && !_isUserText(_history.first)) {
        _history.removeAt(0);
      }
    }
  }

  bool _isUserText(Map<String, dynamic> c) {
    if (c['role'] != 'user') return false;
    final parts = (c['parts'] as List?) ?? const [];
    return parts.whereType<Map>().any((p) => p['text'] != null);
  }

  /// Model that answered last. Fallbacks kick in when Google reports the
  /// model as overloaded (503), rate limited (429) or unavailable (404).
  String? _activeModel;
  static const _fallbackModels = ['gemini-flash-latest', 'gemini-flash-lite-latest'];

  /// Set when the model rejects the thinkingConfig field (older models).
  bool _noThinkingConfig = false;

  Future<Map<String, dynamic>> _generate() async {
    final system = _systemPrompt();
    String makeBody() => jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': system}
            ]
          },
          'contents': _history,
          'tools': [
            {'functionDeclarations': _tools}
          ],
          'generationConfig': {
            'temperature': 0.4,
            // Low thinking = much faster replies for chat and simple tool use.
            if (!_noThinkingConfig) 'thinkingConfig': {'thinkingLevel': 'low'},
          },
        });
    var body = makeBody();

    final models = <String>[
      _activeModel ?? Config.geminiModel,
      Config.geminiModel,
      ..._fallbackModels,
    ].toSet().toList();

    var lastStatus = 0;
    var lastBody = '';
    for (final model in models) {
      final isFirst = model == models.first;
      // Retry the main model with a short backoff; try each fallback once.
      for (var attempt = 0; attempt < (isFirst ? 2 : 1); attempt++) {
        if (attempt > 0) await Future<void>.delayed(const Duration(milliseconds: 600));
        http.Response res;
        try {
          res = await http
              .post(
                Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
                headers: {'Content-Type': 'application/json', 'x-goog-api-key': Config.geminiKey},
                body: body,
              )
              .timeout(const Duration(seconds: 25));
        } catch (e) {
          lastStatus = -1;
          lastBody = e.toString();
          continue;
        }
        if (res.statusCode == 200) {
          _activeModel = model;
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final candidates = (json['candidates'] as List?) ?? const [];
          if (candidates.isEmpty || (candidates.first as Map)['content'] == null) {
            throw Exception("I didn't catch that. Try saying it another way.");
          }
          final content = Map<String, dynamic>.from((candidates.first as Map)['content'] as Map);
          content['role'] = 'model';
          content['parts'] ??= <dynamic>[];
          return content;
        }
        lastStatus = res.statusCode;
        lastBody = res.body;
        // Model does not know thinkingLevel: drop it and retry once.
        if (res.statusCode == 400 && !_noThinkingConfig && res.body.toLowerCase().contains('think')) {
          _noThinkingConfig = true;
          body = makeBody();
          attempt--;
          continue;
        }
        // Bad key or bad request: switching models will not help.
        if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
          throw Exception(_friendly(res.statusCode, res.body));
        }
        if (res.statusCode == 404) break; // model not available: next model
      }
    }
    throw Exception(_friendly(lastStatus, lastBody));
  }

  static String _friendly(int status, String body) {
    String detail = body;
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      detail = ((j['error'] as Map?)?['message'] ?? body).toString();
    } catch (_) {}
    if (detail.length > 160) detail = '${detail.substring(0, 160)}...';
    return switch (status) {
      503 || 429 => 'CLUTCH is a little busy right now. Try again in a few seconds.',
      -1 => 'No internet connection. Check your connection and try again.',
      _ => 'Something went wrong. Please try again.',
    };
  }

  String _systemPrompt() {
    final now = DateTime.now();
    final s = _state.settings;
    final p = _state.profile;
    final who = p == null
        ? ''
        : 'You are talking to ${p.firstName}${p.college.isEmpty ? '' : ', a student at ${p.college}'}. Use their first name now and then, not in every reply.\n';
    final tone = switch (s.personality) {
      Personality.witty =>
        'Sound like a sharp, slightly witty coach who is on the student\'s side. Firm about deadlines, never preachy.',
      Personality.calm =>
        'Sound like a calm, gentle mentor. Reassuring and steady, never harsh, but still honest about deadlines.',
      Personality.strict =>
        'Sound like a strict, no-nonsense trainer. Blunt and direct, zero excuses, but never insulting.',
    };
    final ultra = s.ultra && Config.hasClaude;
    final st = _state.stats;
    final ultraLines = !ultra
        ? ''
        : '''
Ultra Pro mode: be noticeably more personal and specific. Refer to their streak (${st.current} green days, best ${st.best}),
tasks they keep skipping, and the AI step names in the plan (for example "start with the ER diagram step").
When a task has AI steps, tell them the exact next step, not just the task.
''';
    return '''
You are CLUTCH, a deadline survival agent for Indian college students. Your replies are spoken aloud, so:
- Reply in at most ${ultra ? '3 short sentences, under 60 words' : '2 short sentences, under 45 words'}. No markdown, no lists, no emojis, no ids.
- $tone
$who$ultraLines
Current local time: ${now.toIso8601String()} (${weekdayShort(now)}), India time (+05:30).
The student's free study window is ${s.workStartHour}:00 to ${s.workEndHour}:00, about ${fmtH(s.dailyCapacity)} of focus a day.

Rules:
- The CURRENT STATE below is fresh. Answer questions about the plan, workload or tasks straight from it, without calling get_overview. Tools that change things return the updated plan.
- Use only numbers and times from tool results. Never invent tasks, times or hours.
- When the user mentions new work, call add_tasks. Resolve relative dates from the current time. No time given: 23:59. "Morning": 09:00. Exams with no time: 09:00. Estimate realistic hours for an average student (lab record about 2-3, assignment about 3-6, exam prep about 4-6, mini project about 8). Infer importance 1-5 yourself (exams and internals 5; graded assignments, labs and projects 4; optional work and reading 2; errands 1-2). Never ask the user to rate importance.
- When the user wants to skip or cut work today, first call preview_today_limit with minutes 0. Tell them the consequence (which day goes red and why) and offer a smaller session as a compromise, previewing it too. Only commit with set_today_limit or mark_missed after they agree.
- When they finish something, call mark_done and react in a few words.
- For a briefing, cover from CURRENT STATE: today's load, what to do first and why, and the riskiest deadline.

CURRENT STATE (JSON, refreshed every message):
${jsonEncode(_overview(_state.plan, now))}
''';
  }

  // ---------------- tools ----------------

  static final List<Map<String, dynamic>> _tools = [
    {
      'name': 'get_overview',
      'description':
          'Current tasks with priority, slack and risk, today\'s plan, and the workload level of the next 7 days.',
    },
    {
      'name': 'add_tasks',
      'description': 'Add one or more tasks the user mentioned. Returns the new plan summary.',
      'parameters': {
        'type': 'object',
        'properties': {
          'tasks': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'title': {'type': 'string', 'description': 'Short title, max 6 words'},
                'subject': {'type': 'string'},
                'notes': {
                  'type': 'string',
                  'description': 'One or two sentences on what the task involves, from what the user said'
                },
                'type': {
                  'type': 'string',
                  'enum': ['assignment', 'exam', 'lab', 'project', 'reading', 'other']
                },
                'due_at': {
                  'type': 'string',
                  'description': 'ISO 8601 local date-time, e.g. 2026-11-27T23:59:00'
                },
                'est_hours': {'type': 'number'},
                'importance': {'type': 'integer', 'description': '1 to 5'},
                'importance_reason': {'type': 'string', 'description': 'One short sentence'},
              },
              'required': ['title', 'type', 'due_at', 'est_hours', 'importance', 'importance_reason'],
            },
          },
        },
        'required': ['tasks'],
      },
    },
    {
      'name': 'update_task',
      'description': 'Change a task\'s title, due date, estimated hours, importance or hours already done.',
      'parameters': {
        'type': 'object',
        'properties': {
          'task_id': {'type': 'string'},
          'title': {'type': 'string'},
          'due_at': {'type': 'string'},
          'est_hours': {'type': 'number'},
          'importance': {'type': 'integer'},
          'done_hours': {'type': 'number'},
        },
        'required': ['task_id'],
      },
    },
    {
      'name': 'mark_done',
      'description': 'Mark a task as finished.',
      'parameters': {
        'type': 'object',
        'properties': {
          'task_id': {'type': 'string'}
        },
        'required': ['task_id'],
      },
    },
    {
      'name': 'mark_missed',
      'description': 'The user skips this task for the rest of today. Commits and replans.',
      'parameters': {
        'type': 'object',
        'properties': {
          'task_id': {'type': 'string'}
        },
        'required': ['task_id'],
      },
    },
    {
      'name': 'preview_today_limit',
      'description':
          'What-if, nothing is saved: limit today\'s work on a task to N minutes (0 = skip) and show how the next days change.',
      'parameters': {
        'type': 'object',
        'properties': {
          'task_id': {'type': 'string'},
          'minutes': {'type': 'integer'},
        },
        'required': ['task_id', 'minutes'],
      },
    },
    {
      'name': 'set_today_limit',
      'description': 'Commit: limit today\'s work on a task to N minutes, after the user agreed.',
      'parameters': {
        'type': 'object',
        'properties': {
          'task_id': {'type': 'string'},
          'minutes': {'type': 'integer'},
        },
        'required': ['task_id', 'minutes'],
      },
    },
    {
      'name': 'delete_task',
      'description': 'Remove a task the user no longer needs to do.',
      'parameters': {
        'type': 'object',
        'properties': {
          'task_id': {'type': 'string'}
        },
        'required': ['task_id'],
      },
    },
  ];

  Map<String, dynamic> _execute(String name, Map<String, dynamic> a) {
    final now = DateTime.now();
    switch (name) {
      case 'get_overview': {
        return _overview(_state.plan, now);

      }
      case 'add_tasks': {
        final raw = (a['tasks'] as List?) ?? const [];
        final created = <Task>[];
        for (final item in raw.whereType<Map>()) {
          final m = Map<String, dynamic>.from(item);
          final due = _parseDate(m['due_at']) ?? DateTime(now.year, now.month, now.day + 3, 23, 59);
          created.add(Task(
            id: _state.newId(),
            title: (m['title'] ?? 'Untitled task').toString(),
            subject: m['subject']?.toString(),
            notes: (m['notes'] ?? '').toString(),
            type: taskTypeFrom(m['type']?.toString()),
            dueAt: due,
            estHours: _num(m['est_hours'], 2).clamp(0.25, 40).toDouble(),
            importance: _num(m['importance'], 3).round().clamp(1, 5).toInt(),
            importanceReason: (m['importance_reason'] ?? '').toString(),
          ));
        }
        _state.addTasks(created);
        return {
          'added': [
            for (final t in created)
              {'id': t.id, 'title': t.title, 'due': '${dateLabel(t.dueAt)} ${hm(t.dueAt)}', 'est_hours': t.estHours}
          ],
          'overview': _overview(_state.plan, now),
        };

      }
      case 'update_task': {
        final id = _taskId(a);
        _state.updateTask(
          id,
          title: a['title']?.toString(),
          dueAt: _parseDate(a['due_at']),
          estHours: a['est_hours'] == null ? null : _num(a['est_hours'], 1).toDouble(),
          importance: a['importance'] == null ? null : _num(a['importance'], 3).round(),
          doneHours: a['done_hours'] == null ? null : _num(a['done_hours'], 0).toDouble(),
        );
        return {'ok': true, 'overview': _overview(_state.plan, now)};

      }
      case 'mark_done': {
        final id = _taskId(a);
        _state.markDone(id);
        return {'ok': true, 'overview': _overview(_state.plan, now)};

      }
      case 'mark_missed': {
        final id = _taskId(a);
        final impact = _state.markMissed(id);
        return {'ok': true, 'impact': impact, 'week': _week(_state.plan, now)};

      }
      case 'preview_today_limit': {
        final id = _taskId(a);
        final minutes = _num(a['minutes'], 0).round();
        final after = _state.previewLimit(id, minutes);
        return {
          'saved': false,
          'impact': Engine.describeImpact(_state.plan, after, now),
          'week_before': _week(_state.plan, now),
          'week_after': _week(after, now),
        };

      }
      case 'set_today_limit': {
        final id = _taskId(a);
        final impact = _state.limitToday(id, _num(a['minutes'], 0).round());
        return {'ok': true, 'impact': impact, 'today_plan': _todayPlan(_state.plan, now)};

      }
      case 'delete_task': {
        final id = _taskId(a);
        _state.deleteTask(id);
        return {'ok': true};
      }
    }
    return {'error': 'Unknown tool $name'};
  }

  String _taskId(Map<String, dynamic> a) {
    final id = (a['task_id'] ?? '').toString();
    if (_state.byId(id) != null) return id;
    // Be forgiving if the model passes a title instead of an id.
    final q = id.toLowerCase();
    for (final t in _state.tasks) {
      if (t.title.toLowerCase().contains(q) || q.contains(t.title.toLowerCase())) return t.id;
    }
    throw Exception('No task with id "$id". Call get_overview for valid ids.');
  }

  static num _num(dynamic v, num fallback) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? fallback;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final d = DateTime.tryParse(v.toString());
    return d?.toLocal();
  }

  Map<String, dynamic> _overview(PlanResult p, DateTime now) {
    final open = _state.openTasks;
    return {
      'now': '${dateLabel(now)} ${hm(now)}',
      'tasks': [
        for (final t in open)
          {
            'id': t.id,
            'title': t.title,
            'type': t.type.name,
            'due': '${dueLabel(t.dueAt, now)} (${dateLabel(t.dueAt)} ${hm(t.dueAt)})',
            'remaining_hours': double.parse(t.remaining.toStringAsFixed(1)),
            'importance': t.importance,
            'priority': double.parse((p.insights[t.id]?.priority ?? 0).toStringAsFixed(2)),
            'slack_hours': double.parse((p.insights[t.id]?.slack ?? 0).toStringAsFixed(1)),
            'at_risk': p.insights[t.id]?.atRisk ?? false,
            'times_skipped': t.missedCount,
            if (t.aiSteps.isNotEmpty) 'ai_steps': [for (final x in t.aiSteps) '${x.title} (${x.minutes} min)'],
          }
      ],
      'today_plan': _todayPlan(p, now),
      'week': _week(p, now),
    };
  }

  List<Map<String, dynamic>> _todayPlan(PlanResult p, DateTime now) => [
        for (final b in p.blocksOn(now))
          {
            'task': _state.byId(b.taskId)?.title ?? '?',
            'start': hm(b.start),
            'end': hm(b.end),
            'why': b.reason,
            if (b.step != null) 'step': b.step,
          }
      ];

  List<Map<String, dynamic>> _week(PlanResult p, DateTime now) => [
        for (final d in p.days.take(7))
          {
            'day': '${dayLabel(d.date, now)} (${dateLabel(d.date)})',
            'level': levelName(d.level),
            'load_percent': (d.pressure * 100).round(),
            'planned_hours': double.parse(d.planned.toStringAsFixed(1)),
            if (d.overflow > 0.01) 'cannot_fit_hours': double.parse(d.overflow.toStringAsFixed(1)),
          }
      ];
}
