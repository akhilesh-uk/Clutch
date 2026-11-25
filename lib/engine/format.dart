const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mo = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String weekdayShort(DateTime d) => _wd[d.weekday - 1];

String monthShort(int m) => _mo[m - 1];

String hm(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

String dateLabel(DateTime d) => '${weekdayShort(d)} ${d.day} ${monthShort(d.month)}';

String dayLabel(DateTime d, DateTime now) {
  final diff = dayOf(d).difference(dayOf(now)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff > 1 && diff < 7) return weekdayShort(d);
  return dateLabel(d);
}

String fmtH(double h) {
  if (h < 1) return '${(h * 60).round()} min';
  final r = (h * 2).round() / 2; // nearest half hour
  return r == r.roundToDouble() ? '${r.toInt()} h' : '${r.toStringAsFixed(1)} h';
}

String dueLabel(DateTime due, DateTime now) {
  if (!due.isAfter(now)) return 'overdue';
  final hours = due.difference(now).inMinutes / 60.0;
  if (hours < 12) return 'in ${fmtH(hours)}';
  return '${dayLabel(due, now)} ${hm(due)}';
}
