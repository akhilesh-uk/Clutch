enum TaskType { assignment, exam, lab, project, reading, other }

enum TaskStatus { pending, done }

/// One step of a task, from the Ultra Pro AI analysis.
class TaskStep {
  final String title;
  final int minutes;
  TaskStep(this.title, this.minutes);
  Map<String, dynamic> toJson() => {'title': title, 'minutes': minutes};
  factory TaskStep.fromJson(Map<String, dynamic> j) =>
      TaskStep((j['title'] ?? '') as String, ((j['minutes'] ?? 30) as num).toInt());
}

TaskType taskTypeFrom(String? s) => TaskType.values.firstWhere(
      (e) => e.name == (s ?? '').toLowerCase().trim(),
      orElse: () => TaskType.other,
    );

class Task {
  final String id;
  String title;
  String? subject;
  String notes; // what the task is about
  TaskType type;
  DateTime dueAt;
  double estHours;
  double doneHours;
  int importance; // 1..5, inferred by Gemini
  String importanceReason;
  TaskStatus status;
  int missedCount;

  /// Cap on how much of this task may be planned on [limitDate] (yyyy-mm-dd).
  /// 0 minutes = skipped that day.
  String? limitDate;
  int limitMinutes;
  final DateTime createdAt;

  // Ultra Pro AI analysis
  List<TaskStep> aiSteps;
  String aiSummary;
  String aiDifficulty;
  bool aiAnalyzing;

  Task({
    required this.id,
    required this.title,
    this.subject,
    this.notes = '',
    this.type = TaskType.other,
    required this.dueAt,
    required this.estHours,
    this.doneHours = 0,
    this.importance = 3,
    this.importanceReason = '',
    this.status = TaskStatus.pending,
    this.missedCount = 0,
    this.limitDate,
    this.limitMinutes = 0,
    DateTime? createdAt,
    List<TaskStep>? aiSteps,
    this.aiSummary = '',
    this.aiDifficulty = '',
    this.aiAnalyzing = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        aiSteps = aiSteps ?? [];

  bool get aiAnalyzed => aiSteps.isNotEmpty;

  double get remaining {
    final r = estHours - doneHours;
    return r < 0 ? 0 : r;
  }

  bool get isDone => status == TaskStatus.done;

  Task copy() => Task.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'notes': notes,
        'type': type.name,
        'dueAt': dueAt.toIso8601String(),
        'estHours': estHours,
        'doneHours': doneHours,
        'importance': importance,
        'importanceReason': importanceReason,
        'status': status.name,
        'missedCount': missedCount,
        'limitDate': limitDate,
        'limitMinutes': limitMinutes,
        'createdAt': createdAt.toIso8601String(),
        'aiSteps': aiSteps.map((x) => x.toJson()).toList(),
        'aiSummary': aiSummary,
        'aiDifficulty': aiDifficulty,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        subject: j['subject'] as String?,
        notes: (j['notes'] ?? '') as String,
        type: taskTypeFrom(j['type'] as String?),
        dueAt: DateTime.parse(j['dueAt'] as String),
        estHours: (j['estHours'] as num).toDouble(),
        doneHours: ((j['doneHours'] ?? 0) as num).toDouble(),
        importance: ((j['importance'] ?? 3) as num).toInt(),
        importanceReason: (j['importanceReason'] ?? '') as String,
        status: (j['status'] == 'done') ? TaskStatus.done : TaskStatus.pending,
        missedCount: ((j['missedCount'] ?? 0) as num).toInt(),
        limitDate: j['limitDate'] as String?,
        limitMinutes: ((j['limitMinutes'] ?? 0) as num).toInt(),
        createdAt: j['createdAt'] == null
            ? null
            : DateTime.tryParse(j['createdAt'] as String),
        aiSteps: ((j['aiSteps'] as List?) ?? const [])
            .map((x) => TaskStep.fromJson(Map<String, dynamic>.from(x as Map)))
            .toList(),
        aiSummary: (j['aiSummary'] ?? '') as String,
        aiDifficulty: (j['aiDifficulty'] ?? '') as String,
      );
}

String taskTypeLabel(TaskType t) => switch (t) {
      TaskType.assignment => 'Assignment',
      TaskType.exam => 'Exam',
      TaskType.lab => 'Lab',
      TaskType.project => 'Project',
      TaskType.reading => 'Reading',
      TaskType.other => 'Other',
    };
