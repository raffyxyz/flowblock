import 'package:drift/drift.dart';

import '../../domain/models/task_item.dart';
import '../../domain/models/task_occurrence.dart' as domain_occurrence;
import '../../domain/models/timer_session.dart' as domain_timer;
import 'database.dart' as db;

/// Converts between Drift rows and domain models (both directions).
///
/// The domain layer never imports drift; only this file (and DAOs) know the
/// row types. Time rules live here:
/// - Instants are stored UTC (`toUtc()` on write).
/// - Scheduling is wall-clock local: `scheduledDate` 'yyyy-MM-dd' plus
///   `scheduledMinutes` (minutes since midnight). Never UTC.
/// - Enums map by name via `textEnum` (see `tables.dart`).
/// - Estimates: domain uses minutes, rows use seconds (`* 60` / `~/ 60`).
/// - Weekdays: domain uses ISO-8601 (Mon = 1); rows use a bitmask with
///   bit 0 = Monday ... bit 6 = Sunday.

String formatDay(DateTime day) {
  final String y = day.year.toString().padLeft(4, '0');
  final String m = day.month.toString().padLeft(2, '0');
  final String d = day.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime parseDay(String ymd) {
  final List<String> parts = ymd.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

int weekdaysToBitmask(List<int> weekdays) {
  int mask = 0;
  for (final int day in weekdays) {
    if (day >= 1 && day <= 7) {
      mask |= 1 << (day - 1);
    }
  }
  return mask;
}

List<int> bitmaskToWeekdays(int mask) {
  final List<int> days = <int>[];
  for (int i = 0; i < 7; i++) {
    if ((mask & (1 << i)) != 0) {
      days.add(i + 1);
    }
  }
  return days;
}

int? minutesToSeconds(int? minutes) =>
    minutes == null ? null : minutes * 60;

int? secondsToMinutes(int? seconds) =>
    seconds == null ? null : seconds ~/ 60;

db.TasksCompanion taskCompanionFromDomain(TaskItem item) {
  final DateTime now = DateTime.now().toUtc();
  return db.TasksCompanion(
    id: Value<String>(item.id),
    title: Value<String>(item.title),
    notes: Value<String?>(
      item.notes.isEmpty ? null : item.notes,
    ),
    sortOrder: Value<int>(item.sortOrder),
    isDone: Value<bool>(item.isDone),
    completedAt: Value<DateTime?>(item.completedAt?.toUtc()),
    estimatedSeconds: Value<int?>(
      minutesToSeconds(item.durationMinutes),
    ),
    scheduledDate: Value<String?>(formatDay(item.date)),
    scheduledMinutes: Value<int?>(
      item.time == null
          ? null
          : item.time!.hour * 60 + item.time!.minute,
    ),
    recurrenceType: Value<RecurrenceType>(item.recurrence),
    recurrenceInterval: Value<int>(item.recurrenceInterval),
    recurrenceWeekdays: Value<int>(
      weekdaysToBitmask(item.weekdays),
    ),
    recurrenceEndsOn: Value<String?>(
      item.recurrenceEndsOn == null
          ? null
          : formatDay(item.recurrenceEndsOn!),
    ),
    createdAt: Value<DateTime>(
      (item.createdAt ?? now).toUtc(),
    ),
    updatedAt: Value<DateTime>(
      (item.updatedAt ?? now).toUtc(),
    ),
  );
}

Subtask subtaskFromRow(db.Subtask row) {
  return Subtask(
    id: row.id,
    title: row.title,
    durationMinutes: secondsToMinutes(row.durationSeconds),
    isDone: row.isDone,
    sortOrder: row.sortOrder,
    completedAt: row.completedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}

db.SubtasksCompanion subtaskCompanionFromDomain(
  Subtask item,
  String taskId,
) {
  final DateTime now = DateTime.now().toUtc();
  return db.SubtasksCompanion(
    id: Value<String>(item.id),
    taskId: Value<String>(taskId),
    title: Value<String>(item.title),
    sortOrder: Value<int>(item.sortOrder),
    isDone: Value<bool>(item.isDone),
    completedAt: Value<DateTime?>(item.completedAt?.toUtc()),
    durationSeconds: Value<int?>(
      minutesToSeconds(item.durationMinutes),
    ),
    createdAt: Value<DateTime>((item.createdAt ?? now).toUtc()),
    updatedAt: Value<DateTime>((item.updatedAt ?? now).toUtc()),
  );
}

TaskItem taskItemFromRows(db.Task task, List<db.Subtask> rows) {
  final DateTime date = task.scheduledDate == null
      ? DateTime.now()
      : parseDay(task.scheduledDate!);
  final DateTime day = DateTime(date.year, date.month, date.day);
  final int? minutes = task.scheduledMinutes;
  final List<Subtask> subs =
      rows.map(subtaskFromRow).toList()
        ..sort(
          (Subtask a, Subtask b) => a.sortOrder.compareTo(b.sortOrder),
        );
  return TaskItem(
    id: task.id,
    title: task.title,
    notes: task.notes ?? '',
    date: day,
    time: minutes == null
        ? null
        : DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60),
    recurrence: task.recurrenceType,
    weekdays: bitmaskToWeekdays(task.recurrenceWeekdays),
    durationMinutes: secondsToMinutes(task.estimatedSeconds),
    isDone: task.isDone,
    subtasks: subs,
    sortOrder: task.sortOrder,
    completedAt: task.completedAt,
    recurrenceInterval: task.recurrenceInterval,
    recurrenceEndsOn: task.recurrenceEndsOn == null
        ? null
        : parseDay(task.recurrenceEndsOn!),
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
  );
}

domain_occurrence.TaskOccurrence occurrenceFromRow(db.TaskOccurrence row) {
  return domain_occurrence.TaskOccurrence(
    id: row.id,
    taskId: row.taskId,
    date: parseDay(row.date),
    status: row.status,
    completedAt: row.completedAt,
  );
}

db.TaskOccurrencesCompanion occurrenceCompanionFromDomain(
  domain_occurrence.TaskOccurrence item,
) {
  return db.TaskOccurrencesCompanion(
    id: Value<String>(item.id),
    taskId: Value<String>(item.taskId),
    date: Value<String>(formatDay(item.date)),
    status: Value<domain_occurrence.OccurrenceStatus>(item.status),
    completedAt: Value<DateTime?>(item.completedAt?.toUtc()),
  );
}

domain_occurrence.OccurrenceSubtaskState occurrenceStateFromRow(
  db.OccurrenceSubtaskState row,
) {
  return domain_occurrence.OccurrenceSubtaskState(
    occurrenceId: row.occurrenceId,
    subtaskId: row.subtaskId,
    isDone: row.isDone,
    completedAt: row.completedAt,
  );
}

domain_timer.TimerSession timerSessionFromRow(db.TimerSession row) {
  return domain_timer.TimerSession(
    id: row.id,
    taskId: row.taskId,
    subtaskId: row.subtaskId,
    startedAt: row.startedAt,
    endedAt: row.endedAt,
    plannedSeconds: row.plannedSeconds,
    elapsedSeconds: row.elapsedSeconds,
    mode: row.mode,
    endReason: row.endReason,
  );
}

db.TimerSessionsCompanion timerCompanionFromDomain(
  domain_timer.TimerSession item,
) {
  return db.TimerSessionsCompanion(
    id: Value<String>(item.id),
    taskId: Value<String>(item.taskId),
    subtaskId: Value<String?>(item.subtaskId),
    startedAt: Value<DateTime>(item.startedAt.toUtc()),
    endedAt: Value<DateTime?>(item.endedAt?.toUtc()),
    plannedSeconds: Value<int>(item.plannedSeconds),
    elapsedSeconds: Value<int>(item.elapsedSeconds),
    mode: Value<domain_timer.TimerMode>(item.mode),
    endReason: Value<domain_timer.TimerEndReason?>(item.endReason),
  );
}
