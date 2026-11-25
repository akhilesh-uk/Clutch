import '../models/task.dart';

/// A realistic, slightly overloaded student week, relative to [now].
List<Task> demoTasks(DateTime now, String Function() id) {
  DateTime at(int days, int hour, [int minute = 0]) =>
      DateTime(now.year, now.month, now.day + days, hour, minute);

  return [
    Task(
      id: id(),
      title: 'OS internal exam prep',
      subject: 'Operating Systems',
      type: TaskType.exam,
      dueAt: at(1, 9),
      estHours: 3,
      importance: 5,
      importanceReason: 'Graded internal, highest stakes.',
    ),
    Task(
      id: id(),
      title: 'ML lab record',
      subject: 'Machine Learning',
      type: TaskType.lab,
      dueAt: at(2, 23, 59),
      estHours: 2.5,
      importance: 4,
      importanceReason: 'Graded lab record, checked by the faculty.',
    ),
    Task(
      id: id(),
      title: 'DBMS assignment 3',
      subject: 'DBMS',
      type: TaskType.assignment,
      dueAt: at(3, 23, 59),
      estHours: 4,
      importance: 4,
      importanceReason: 'Graded assignment.',
    ),
    Task(
      id: id(),
      title: 'Mini project report',
      subject: 'Project',
      type: TaskType.project,
      dueAt: at(4, 17),
      estHours: 5,
      importance: 4,
      importanceReason: 'Counts toward the project review.',
    ),
    Task(
      id: id(),
      title: 'CN textbook, 50 pages',
      subject: 'Computer Networks',
      type: TaskType.reading,
      dueAt: at(6, 23, 59),
      estHours: 3,
      importance: 2,
      importanceReason: 'Ungraded reading.',
    ),
  ];
}
