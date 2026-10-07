import 'models/task_item.dart';

/// Pure scheduling helpers (Step 3).
///
/// [tasksForDate] reproduces the exact mock behavior used since Step 1: a
/// task appears on a date when its wall-clock day matches. Real recurrence
/// expansion (daily/weekly/monthly occurrences) arrives in Step 5.
// TODO(step5): replace same-day matching with recurrence expansion.
List<TaskItem> tasksForDate(List<TaskItem> tasks, DateTime day) {
  return tasks.where((TaskItem task) => sameDay(task.date, day)).toList();
}

/// Nullable lookup by id (avoids adding a collection dependency).
TaskItem? findTask(List<TaskItem> tasks, String id) {
  for (final TaskItem task in tasks) {
    if (task.id == id) {
      return task;
    }
  }
  return null;
}

/// Nullable subtask lookup within [task].
Subtask? findSubtask(TaskItem task, String subtaskId) {
  for (final Subtask s in task.subtasks) {
    if (s.id == subtaskId) {
      return s;
    }
  }
  return null;
}

/// Parent recompute rule (Step 3 business rule, pure and unit-tested):
/// no subtasks -> unchanged; otherwise done iff all subtasks are done,
/// stamping [completedAt] on false->true transitions and clearing it
/// whenever the parent is open.
TaskItem recomputeParent(TaskItem task, DateTime now) {
  if (task.subtasks.isEmpty) {
    return task;
  }
  final bool allDone = task.subtasks.every((Subtask s) => s.isDone);
  if (!allDone) {
    return task.copyWith(isDone: false, clearCompletedAt: true);
  }
  if (task.isDone) {
    return task;
  }
  return task.copyWith(isDone: true, completedAt: now);
}
