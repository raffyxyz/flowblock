import 'package:intl/intl.dart';

import '../../domain/models/task_item.dart';

/// Centralized display formatting so feature widgets never hard-code formats.
String formatScreenDate(DateTime day) {
  return DateFormat('EEEE, MMMM d').format(day);
}

String formatShortDay(DateTime day) {
  return DateFormat('EEE, MMM d').format(day);
}

String formatClock(DateTime time) {
  return DateFormat.jm().format(time);
}

/// Formats a countdown as mm:ss.
String formatCountdown(int totalSeconds) {
  final int seconds = totalSeconds.clamp(0, 5999);
  final String minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  final String rest = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}

String recurrenceLabel(TaskItem task) {
  switch (task.recurrence) {
    case RecurrenceType.once:
      return 'Once';
    case RecurrenceType.daily:
      return 'Daily';
    case RecurrenceType.weekly:
      if (task.weekdays.isEmpty) {
        return 'Weekly';
      }
      const List<String> names = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      final List<int> days = List<int>.from(task.weekdays)..sort();
      return 'Weekly · ${days.map((int d) => names[d - 1]).join(' ')}';
    case RecurrenceType.monthly:
      return 'Monthly';
  }
}
