/// Per-occurrence state for recurring tasks (Step 2 domain types).
///
/// The database owns one [TaskOccurrence] row per date a recurring task is
/// acted on, plus one [OccurrenceSubtaskState] per subtask. This is what lets
/// subtask checks reset each occurrence. No Drift imports here.
enum OccurrenceStatus { pending, done, skipped }

/// One acted-on date of a (usually recurring) task.
class TaskOccurrence {
  const TaskOccurrence({
    required this.id,
    required this.taskId,
    required this.date,
    this.status = OccurrenceStatus.pending,
    this.completedAt,
  });

  final String id;
  final String taskId;

  /// Wall-clock day this occurrence belongs to (local midnight).
  final DateTime date;
  final OccurrenceStatus status;

  /// UTC instant the occurrence was completed, if any.
  final DateTime? completedAt;

  TaskOccurrence copyWith({
    String? taskId,
    DateTime? date,
    OccurrenceStatus? status,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return TaskOccurrence(
      id: id,
      taskId: taskId ?? this.taskId,
      date: date ?? this.date,
      status: status ?? this.status,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}

/// Checked state of one subtask within one occurrence.
class OccurrenceSubtaskState {
  const OccurrenceSubtaskState({
    required this.occurrenceId,
    required this.subtaskId,
    this.isDone = false,
    this.completedAt,
  });

  final String occurrenceId;
  final String subtaskId;
  final bool isDone;

  /// UTC instant the subtask was checked in this occurrence, if any.
  final DateTime? completedAt;

  OccurrenceSubtaskState copyWith({
    bool? isDone,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return OccurrenceSubtaskState(
      occurrenceId: occurrenceId,
      subtaskId: subtaskId,
      isDone: isDone ?? this.isDone,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}
