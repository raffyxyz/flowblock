/// Plain immutable domain models for Step 1 (UI only, no persistence).
enum RecurrenceType { once, daily, weekly, monthly }

/// A single checkable step inside a [TaskItem].
class Subtask {
  const Subtask({
    required this.id,
    required this.title,
    this.durationMinutes,
    this.isDone = false,
  });

  final String id;
  final String title;
  final int? durationMinutes;
  final bool isDone;

  Subtask copyWith({String? title, int? durationMinutes, bool? isDone}) {
    return Subtask(
      id: id,
      title: title ?? this.title,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isDone: isDone ?? this.isDone,
    );
  }
}

/// A task scheduled on a given day, optionally with subtasks and recurrence.
class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.date,
    this.notes = '',
    this.time,
    this.recurrence = RecurrenceType.once,
    this.weekdays = const <int>[],
    this.durationMinutes,
    this.isDone = false,
    this.subtasks = const <Subtask>[],
  });

  final String id;
  final String title;
  final String notes;
  final DateTime date;
  final DateTime? time;
  final RecurrenceType recurrence;

  /// ISO-8601 weekdays (Monday = 1) used when [recurrence] is weekly.
  final List<int> weekdays;
  final int? durationMinutes;
  final bool isDone;
  final List<Subtask> subtasks;

  int get doneSubtasks => subtasks.where((Subtask s) => s.isDone).length;

  /// True when the task owns at least one subtask.
  bool get hasSubtasks => subtasks.isNotEmpty;

  /// A task with subtasks has no timer of its own; timers live on subtasks.
  /// Adding the first subtask flips this to false; removing the last flips
  /// it back to true. Widgets must use this, not their own checks.
  bool get canRunOwnTimer => subtasks.isEmpty;

  /// Sum of known subtask durations, or null when no subtask has one.
  int? get rolledUpEstimate {
    int total = 0;
    bool any = false;
    for (final Subtask s in subtasks) {
      final int? minutes = s.durationMinutes;
      if (minutes != null) {
        total += minutes;
        any = true;
      }
    }
    return any ? total : null;
  }

  /// Estimate shown in cards and headers: the rolled-up subtask sum when the
  /// task has subtasks, otherwise the task's own estimate.
  int? get displayEstimate =>
      hasSubtasks ? rolledUpEstimate : durationMinutes;

  TaskItem copyWith({
    String? title,
    String? notes,
    DateTime? date,
    DateTime? time,
    bool clearTime = false,
    RecurrenceType? recurrence,
    List<int>? weekdays,
    int? durationMinutes,
    bool? isDone,
    List<Subtask>? subtasks,
  }) {
    return TaskItem(
      id: id,
      title: title ?? this.title,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      time: clearTime ? null : (time ?? this.time),
      recurrence: recurrence ?? this.recurrence,
      weekdays: weekdays ?? this.weekdays,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isDone: isDone ?? this.isDone,
      subtasks: subtasks ?? this.subtasks,
    );
  }
}

/// Day-level equality used to group tasks on the Today/Upcoming screens.
bool sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
