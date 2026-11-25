import 'dart:math';

import '../models/settings.dart';
import '../models/task.dart';
import 'format.dart';

/// Pure, deterministic planning engine. Gemini never ranks or schedules:
/// it only understands input and explains these results.

class PlanBlock {
  final String taskId;
  final DateTime start;
  final DateTime end;
  final String reason;
  final String? step; // AI step worked on in this block (Ultra Pro)
  PlanBlock(this.taskId, this.start, this.end, this.reason, {this.step});
  double get hours => end.difference(start).inMinutes / 60.0;
}

enum DayLevel { free, smooth, hectic, critical }

class DayLoad {
  final DateTime date;
  final double planned;
  final double carried; // planned hours of tasks the user already skipped
  final double overflow; // work that cannot fit before a deadline on this day
  final double capacity;
  DayLoad(this.date, this.planned, this.carried, this.overflow, this.capacity);

  double get pressure =>
      capacity <= 0 ? 0 : (planned + carried + overflow) / capacity;

  DayLevel get level {
    if (overflow > 0.01 || pressure > 1.0 || carried >= 2) return DayLevel.critical;
    if (pressure >= 0.65) return DayLevel.hectic;
    if (planned > 0.01) return DayLevel.smooth;
    return DayLevel.free;
  }
}

String levelName(DayLevel l) => switch (l) {
      DayLevel.free => 'Free',
      DayLevel.smooth => 'Smooth',
      DayLevel.hectic => 'Hectic',
      DayLevel.critical => 'Out of control',
    };

class TaskInsight {
  final double remaining, available, slack, priority, overflow;
  final bool overdue;
  TaskInsight(this.remaining, this.available, this.slack, this.priority,
      this.overflow, this.overdue);
  bool get atRisk => overdue || slack < 0 || overflow > 0.01;
}

class PlanResult {
  final DateTime computedAt;
  final List<PlanBlock> blocks;
  final List<DayLoad> days; // index 0 = today
  final Map<String, TaskInsight> insights;
  PlanResult(this.computedAt, this.blocks, this.days, this.insights);

  factory PlanResult.empty() => PlanResult(DateTime.now(), [], [], {});

  List<PlanBlock> blocksOn(DateTime day) {
    final d = dayOf(day);
    return blocks.where((b) => dayOf(b.start) == d).toList();
  }

  DayLoad? loadOn(DateTime day) {
    final d = dayOf(day);
    for (final l in days) {
      if (l.date == d) return l;
    }
    return null;
  }
}

class Engine {
  final AppSettings s;
  static const horizonDays = 21;
  Engine(this.s);

  (DateTime, DateTime) window(DateTime day) {
    final d = dayOf(day);
    return (
      DateTime(d.year, d.month, d.day, s.workStartHour),
      DateTime(d.year, d.month, d.day, s.workEndHour),
    );
  }

  static double hoursBetween(DateTime a, DateTime b) =>
      b.difference(a).inMinutes / 60.0;

  /// Focus hours the student realistically has between [from] and [to].
  double focusHours(DateTime from, DateTime to) {
    if (!to.isAfter(from)) return 0;
    var total = 0.0;
    var day = dayOf(from);
    while (day.isBefore(to)) {
      final (ws, we) = window(day);
      final a = from.isAfter(ws) ? from : ws;
      final b = to.isBefore(we) ? to : we;
      if (b.isAfter(a)) total += min(hoursBetween(a, b), s.dailyCapacity);
      day = addDays(day, 1);
    }
    return total;
  }

  double priority(Task t, DateTime at, double remaining) {
    final slack = focusHours(at, t.dueAt) - remaining;
    final urgency = slack <= 0 ? 1.0 : 1 / (1 + slack / s.dailyCapacity);
    return 0.50 * urgency +
        0.35 * (t.importance.clamp(1, 5) / 5) +
        0.15 * min(remaining / 8, 1.0) +
        min(0.1 * t.missedCount, 0.2);
  }

  String reason(Task t, DateTime at, double remaining) {
    final slack = focusHours(at, t.dueAt) - remaining;
    final due = dueLabel(t.dueAt, at);
    if (slack <= 0) {
      return 'Due $due and needs ${fmtH(remaining)}. You are already behind, start now.';
    }
    if (t.missedCount >= 2) return 'Skipped ${t.missedCount} times. Not today.';
    if (t.missedCount == 1) return 'You skipped this once. Getting it back on track.';
    if (slack < s.dailyCapacity) {
      return 'Due $due, only ${fmtH(slack)} of slack left.';
    }
    if (t.importance >= 5) {
      final why = t.importanceReason.isNotEmpty ? t.importanceReason : 'Highest stakes.';
      return '$why Due $due.';
    }
    return 'Due $due, ${fmtH(remaining)} left. Plenty of room, chip away at it.';
  }

  PlanResult compute(List<Task> all, DateTime now) {
    final open = all.where((t) => !t.isDone && t.remaining > 0.01).toList();
    final rem = {for (final t in open) t.id: t.remaining};
    final worked = {for (final t in open) t.id: t.doneHours}; // progress through the task
    final blocks = <PlanBlock>[];
    final today = dayOf(now);

    for (var d = 0; d < horizonDays; d++) {
      final day = addDays(today, d);
      final key = dayKey(day);
      final (ws, we) = window(day);
      var cursor = (d == 0 && now.isAfter(ws)) ? _roundUp5(now) : ws;
      if (!cursor.isBefore(we)) continue;
      var cap = min(s.dailyCapacity, hoursBetween(cursor, we));
      final usedToday = <String, double>{};
      final blocked = <String>{};
      var plannedToday = 0.0;
      // Past a comfortable load, only tasks that cannot afford to wait get more time.
      final comfortable = s.dailyCapacity * 0.5;

      while (cap >= 0.25 && cursor.isBefore(we)) {
        double limitLeft(Task t) {
          if (t.limitDate != key) return double.infinity;
          return t.limitMinutes / 60.0 - (usedToday[t.id] ?? 0);
        }

        final candidates = open
            .where((t) =>
                !blocked.contains(t.id) &&
                rem[t.id]! > 0.01 &&
                t.dueAt.isAfter(cursor) &&
                limitLeft(t) > 0.01 &&
                (plannedToday < comfortable ||
                    focusHours(cursor, t.dueAt) - rem[t.id]! < s.dailyCapacity))
            .toList();
        if (candidates.isEmpty) break;

        Task best = candidates.first;
        var bestScore = -1.0;
        for (final t in candidates) {
          final p = priority(t, cursor, rem[t.id]!);
          if (p > bestScore) {
            bestScore = p;
            best = t;
          }
        }

        var h = [
          s.blockMaxMinutes / 60.0,
          rem[best.id]!,
          cap,
          hoursBetween(cursor, we),
          hoursBetween(cursor, best.dueAt),
          limitLeft(best),
        ].reduce(min);
        // With AI steps, end the block at the current step's boundary.
        final stepInfo = _stepAt(best, worked[best.id]!);
        if (stepInfo != null && stepInfo.$2 * 60 >= 10) h = min(h, stepInfo.$2);
        var minutes = (h * 60).floor();
        if (rem[best.id]! * 60 > minutes) minutes -= minutes % 5; // neat times
        if (minutes < 10) {
          blocked.add(best.id);
          continue;
        }
        h = minutes / 60.0;
        final end = cursor.add(Duration(minutes: minutes));
        blocks.add(PlanBlock(best.id, cursor, end, reason(best, cursor, rem[best.id]!), step: stepInfo?.$1));
        rem[best.id] = rem[best.id]! - h;
        worked[best.id] = worked[best.id]! + h;
        usedToday[best.id] = (usedToday[best.id] ?? 0) + h;
        cap -= h;
        plannedToday += h;
        cursor = end.add(Duration(minutes: s.breakMinutes));
      }
    }

    // Work that never fit before its deadline lands on the due day (or today if overdue).
    final overflowByDay = <DateTime, double>{};
    final overflowByTask = <String, double>{};
    for (final t in open) {
      final left = rem[t.id]!;
      if (left <= 0.01) continue;
      // Beyond the planning horizon it is simply not planned yet, not overflow.
      if (!t.dueAt.isBefore(addDays(today, horizonDays))) continue;
      overflowByTask[t.id] = left;
      var dd = dayOf(t.dueAt);
      if (dd.isBefore(today)) dd = today;
      overflowByDay[dd] = (overflowByDay[dd] ?? 0) + left;
    }

    final missed = {for (final t in open) if (t.missedCount > 0) t.id};
    final days = <DayLoad>[];
    for (var d = 0; d < horizonDays; d++) {
      final day = addDays(today, d);
      var planned = 0.0, carried = 0.0;
      for (final b in blocks) {
        if (dayOf(b.start) != day) continue;
        planned += b.hours;
        if (missed.contains(b.taskId)) carried += b.hours;
      }
      days.add(DayLoad(day, planned, carried, overflowByDay[day] ?? 0, s.dailyCapacity));
    }

    final insights = <String, TaskInsight>{};
    for (final t in open) {
      final available = focusHours(now, t.dueAt);
      insights[t.id] = TaskInsight(
        t.remaining,
        available,
        available - t.remaining,
        priority(t, now, t.remaining),
        overflowByTask[t.id] ?? 0,
        !t.dueAt.isAfter(now),
      );
    }
    return PlanResult(now, blocks, days, insights);
  }

  /// The AI step at [progressHours] into the task, and hours left in it.
  static (String, double)? _stepAt(Task t, double progressHours) {
    if (t.aiSteps.isEmpty) return null;
    // Scale step lengths to the task's current estimate.
    final total = t.aiSteps.fold<int>(0, (a, s) => a + s.minutes) / 60.0;
    if (total <= 0) return null;
    final scale = t.estHours / total;
    var cum = 0.0;
    for (final s in t.aiSteps) {
      cum += s.minutes / 60.0 * scale;
      if (progressHours < cum - 1e-6) return (s.title, cum - progressHours);
    }
    return (t.aiSteps.last.title, 0.0);
  }

  static DateTime _roundUp5(DateTime t) {
    final base = DateTime(t.year, t.month, t.day, t.hour, t.minute);
    final add = (5 - base.minute % 5) % 5;
    return base.add(Duration(minutes: add == 0 && t.second > 0 ? 5 : add));
  }

  /// Plain-language summary of what changed between two plans.
  static String describeImpact(PlanResult before, PlanResult after, DateTime now) {
    DayLoad? worst;
    var worstDelta = 0.0;
    for (final a in after.days) {
      final b = before.loadOn(a.date);
      if (b == null) continue;
      final delta = a.pressure - b.pressure;
      final levelUp = a.level.index > b.level.index;
      if (delta > worstDelta + 0.001 || (levelUp && (worst == null || a.level.index > worst.level.index))) {
        worst = a;
        worstDelta = max(delta, worstDelta);
      }
    }
    if (worst == null) return 'Plan rebalanced. No day got worse.';
    final name = dayLabel(worst.date, now);
    final pct = (worst.pressure * 100).round();
    return '$name is now ${levelName(worst.level)} ($pct% load).';
  }
}
