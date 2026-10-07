/// Plain immutable domain models (no Drift imports; see lib/data/db/mappers.dart
/// for row conversions).
enum RecurrenceType { once, daily, weekly, monthly }

/// A single checkable step inside a [TaskItem].
class Subtask {
  const Subtask({
    required this.id,
    required this.title,
    this.durationMinutes,
    this.isDone = false,
    this.sortOrder = 0,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final int? durationMinutes;
  final bool isDone;

  /// Position within its parent task (DB `sortOrder`).
  final int sortOrder;

  /// UTC instant the subtask was completed, if any.
  final DateTime? completedAt;

  /// UTC audit instants. Null for in-memory objects created before Step 2;
  /// the database layer defaults them to now on insert.
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Subtask copyWith({
    String? title,
    int? durationMinutes,
    bool clearDurationMinutes = false,
    bool? isDone,
    int? sortOrder,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subtask(
      id: id,
      title: title ?? this.title,
      durationMinutes: clearDurationMinutes
          ? null
          : (durationMinutes ?? this.durationMinutes),
      isDone: isDone ?? this.isDone,
      sortOrder: sortOrder ?? this.sortOrder,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    this.sortOrder = 0,
    this.completedAt,
    this.recurrenceInterval = 1,
    this.recurrenceEndsOn,
    this.createdAt,
    this.updatedAt,
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

  /// Position in the manual order (DB `sortOrder`).
  final int sortOrder;

  /// UTC instant the task was completed, if any.
  final DateTime? completedAt;

  /// Repeat-every-N for daily/weekly/monthly (DB `recurrenceInterval`).
  final int recurrenceInterval;

  /// Wall-clock last date of a recurrence, if bounded (DB `recurrenceEndsOn`).
  final DateTime? recurrenceEndsOn;

  /// UTC audit instants. Null for in-memory objects created before Step 2;
  /// the database layer defaults them to now on insert.
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    bool clearDurationMinutes = false,
    bool? isDone,
    List<Subtask>? subtasks,
    int? sortOrder,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    int? recurrenceInterval,
    DateTime? recurrenceEndsOn,
    bool clearRecurrenceEndsOn = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskItem(
      id: id,
      title: title ?? this.title,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      time: clearTime ? null : (time ?? this.time),
      recurrence: recurrence ?? this.recurrence,
      weekdays: weekdays ?? this.weekdays,
      durationMinutes: clearDurationMinutes
          ? null
          : (durationMinutes ?? this.durationMinutes),
      isDone: isDone ?? this.isDone,
      subtasks: subtasks ?? this.subtasks,
      sortOrder: sortOrder ?? this.sortOrder,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceEndsOn: clearRecurrenceEndsOn
          ? null
          : (recurrenceEndsOn ?? this.recurrenceEndsOn),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Day-level equality used to group tasks on the Today/Upcoming screens.
bool sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
