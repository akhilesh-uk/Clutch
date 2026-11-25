import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../engine/format.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'survival_screen.dart';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int n) => setState(() => _month = DateTime(_month.year, _month.month + n));

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return SafeArea(
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final now = DateTime.now();
          final first = DateTime(_month.year, _month.month, 1);
          final leading = first.weekday - 1; // Monday first
          final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
          final cells = leading + daysInMonth;
          final rows = (cells / 7).ceil();

          return ListView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              Text('Workload', style: heading(28)),
              SizedBox(height: 4),
              Text('Tap a day to open its Survival Mode plan.', style: TextStyle(color: C.muted)),
              SizedBox(height: 20),
              Row(children: [
                Text('${_months[_month.month - 1]} ${_month.year}', style: heading(18)),
                Spacer(),
                IconButton(onPressed: () => _shift(-1), icon: Icon(Icons.chevron_left)),
                IconButton(onPressed: () => _shift(1), icon: Icon(Icons.chevron_right)),
              ]),
              SizedBox(height: 8),
              Row(
                children: [
                  for (final w in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(
                      child: Center(
                          child: Text(w, style: TextStyle(color: C.muted, fontSize: 12))),
                    ),
                ],
              ),
              SizedBox(height: 8),
              for (var r = 0; r < rows; r++)
                Row(
                  children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(child: _cell(context, r * 7 + c - leading + 1, daysInMonth, now)),
                  ],
                ),
              SizedBox(height: 20),
              Wrap(spacing: 16, runSpacing: 8, children: [
                for (final l in [DayLevel.smooth, DayLevel.hectic, DayLevel.critical])
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: C.level(l), shape: BoxShape.circle)),
                    SizedBox(width: 6),
                    Text(levelName(l), style: TextStyle(color: C.muted, fontSize: 13)),
                  ]),
              ]),
              SizedBox(height: 24),
              Text('NEXT 7 DAYS', style: TextStyle(color: C.muted, fontSize: 12, letterSpacing: 1.2)),
              SizedBox(height: 8),
              for (final d in state.plan.days.take(7)) _dayRow(context, d, now),
            ],
          );
        },
      ),
    );
  }

  Widget _cell(BuildContext context, int dayNum, int daysInMonth, DateTime now) {
    if (dayNum < 1 || dayNum > daysInMonth) return SizedBox(height: 52);
    final date = DateTime(_month.year, _month.month, dayNum);
    final load = AppState.instance.plan.loadOn(date);
    final isToday = date == dayOf(now);
    final color = load == null || load.level == DayLevel.free ? null : C.level(load.level);

    return Padding(
      padding: EdgeInsets.all(3),
      child: GestureDetector(
        onTap: () => _open(context, date),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 450),
          height: 46,
          decoration: BoxDecoration(
            color: color?.withValues(alpha: 0.22) ?? C.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isToday ? C.accent : (color?.withValues(alpha: 0.7) ?? C.border),
              width: isToday ? 1.6 : 1,
            ),
          ),
          child: Center(
            child: Text('$dayNum',
                style: TextStyle(
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: date.isBefore(dayOf(now)) ? C.muted : C.text)),
          ),
        ),
      ),
    );
  }

  Widget _dayRow(BuildContext context, DayLoad d, DateTime now) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () => _open(context, d.date),
        child: Row(children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: C.level(d.level), shape: BoxShape.circle)),
          SizedBox(width: 12),
          SizedBox(width: 92, child: Text(dayLabel(d.date, now), style: TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: d.pressure.clamp(0.0, 1.0).toDouble(),
                minHeight: 6,
                color: C.level(d.level),
                backgroundColor: C.border,
              ),
            ),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 44,
            child: Text('${(d.pressure * 100).round()}%',
                textAlign: TextAlign.right, style: TextStyle(color: C.muted)),
          ),
        ]),
      ),
    );
  }

  void _open(BuildContext context, DateTime date) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SurvivalScreen(day: date)));
  }
}
