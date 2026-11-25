import 'format.dart';

/// What happened on one day. A day is "green" when nothing was skipped and
/// no deadline was missed.
class DayRecord {
  int done;
  int skipped;
  int overdue;
  DayRecord({this.done = 0, this.skipped = 0, this.overdue = 0});

  bool get green => skipped == 0 && overdue == 0;

  Map<String, dynamic> toJson() => {'done': done, 'skipped': skipped, 'overdue': overdue};

  factory DayRecord.fromJson(Map<String, dynamic> j) => DayRecord(
        done: ((j['done'] ?? 0) as num).toInt(),
        skipped: ((j['skipped'] ?? 0) as num).toInt(),
        overdue: ((j['overdue'] ?? 0) as num).toInt(),
      );
}

enum DayStatus { untracked, future, green, red, todayGreen, todayRed }

class BadgeDef {
  final String id;
  final String title;
  final String description;
  const BadgeDef(this.id, this.title, this.description);
}

const badgeDefs = [
  BadgeDef('first_win', 'First Win', 'Finish your first task.'),
  BadgeDef('on_a_roll', 'On a Roll', 'Stay green 3 days in a row.'),
  BadgeDef('perfect_week', 'Perfect Week', 'Keep a full Monday to Sunday week green.'),
  BadgeDef('slayer', 'Deadline Slayer', 'Finish 10 tasks.'),
];

class StreakStats {
  final int current;
  final int best;
  final int perfectWeeks;
  final int totalDone;
  final List<DayStatus> week; // Monday..Sunday of the current week
  StreakStats(this.current, this.best, this.perfectWeeks, this.totalDone, this.week);

  Set<String> get earned => {
        if (totalDone >= 1) 'first_win',
        if (best >= 3) 'on_a_roll',
        if (perfectWeeks >= 1) 'perfect_week',
        if (totalDone >= 10) 'slayer',
      };

  int get greenThisWeek =>
      week.where((d) => d == DayStatus.green || d == DayStatus.todayGreen).length;
}

DateTime mondayOf(DateTime d) => addDays(dayOf(d), -(d.weekday - 1));

DayStatus dayStatus(DateTime day, DateTime now, DateTime since, Map<String, DayRecord> log) {
  final d = dayOf(day);
  final today = dayOf(now);
  if (d.isBefore(dayOf(since))) return DayStatus.untracked;
  if (d.isAfter(today)) return DayStatus.future;
  final green = log[dayKey(d)]?.green ?? true;
  if (d == today) return green ? DayStatus.todayGreen : DayStatus.todayRed;
  return green ? DayStatus.green : DayStatus.red;
}

StreakStats computeStreaks(DateTime now, DateTime since, Map<String, DayRecord> log) {
  final today = dayOf(now);
  final start = dayOf(since);

  // Current streak: today (if still green) plus the green days before it.
  var current = 0;
  for (var d = today; !d.isBefore(start); d = addDays(d, -1)) {
    final s = dayStatus(d, now, since, log);
    if (s == DayStatus.green || s == DayStatus.todayGreen) {
      current++;
    } else {
      break;
    }
  }

  // Best streak across all tracked days.
  var best = 0, run = 0;
  for (var d = start; !d.isAfter(today); d = addDays(d, 1)) {
    final s = dayStatus(d, now, since, log);
    if (s == DayStatus.green || s == DayStatus.todayGreen) {
      run++;
      if (run > best) best = run;
    } else {
      run = 0;
    }
  }

  // Perfect weeks: finished Monday..Sunday weeks, fully tracked and all green.
  var perfect = 0;
  for (var m = mondayOf(start); addDays(m, 6).isBefore(today); m = addDays(m, 7)) {
    var ok = true;
    for (var i = 0; i < 7; i++) {
      if (dayStatus(addDays(m, i), now, since, log) != DayStatus.green) {
        ok = false;
        break;
      }
    }
    if (ok) perfect++;
  }

  var totalDone = 0;
  for (final r in log.values) {
    totalDone += r.done;
  }

  final monday = mondayOf(today);
  final week = [for (var i = 0; i < 7; i++) dayStatus(addDays(monday, i), now, since, log)];
  return StreakStats(current, best, perfect, totalDone, week);
}
