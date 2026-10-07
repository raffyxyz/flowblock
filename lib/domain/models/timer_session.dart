/// Persisted timer history (Step 2 domain types, no Drift imports).
enum TimerMode { countdown, stopwatch }

enum TimerEndReason { completed, stopped, skipped }

/// One timer run against a task (or one of its subtasks).
class TimerSession {
  const TimerSession({
    required this.id,
    required this.taskId,
    this.subtaskId,
    required this.startedAt,
    this.endedAt,
    required this.plannedSeconds,
    this.elapsedSeconds = 0,
    this.mode = TimerMode.countdown,
    this.endReason,
  });

  final String id;
  final String taskId;

  /// Null means a task-level timer.
  final String? subtaskId;

  /// UTC instants.
  final DateTime startedAt;
  final DateTime? endedAt;
  final int plannedSeconds;

  /// Active time excluding pauses.
  final int elapsedSeconds;
  final TimerMode mode;
  final TimerEndReason? endReason;

  /// True while the session is still open (no [endedAt] yet).
  bool get isOpen => endedAt == null;

  TimerSession copyWith({
    String? subtaskId,
    bool clearSubtaskId = false,
    DateTime? startedAt,
    DateTime? endedAt,
    bool clearEndedAt = false,
    int? plannedSeconds,
    int? elapsedSeconds,
    TimerMode? mode,
    TimerEndReason? endReason,
    bool clearEndReason = false,
  }) {
    return TimerSession(
      id: id,
      taskId: taskId,
      subtaskId:
          clearSubtaskId ? null : (subtaskId ?? this.subtaskId),
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      plannedSeconds: plannedSeconds ?? this.plannedSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      mode: mode ?? this.mode,
      endReason: clearEndReason ? null : (endReason ?? this.endReason),
    );
  }
}
