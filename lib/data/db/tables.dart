import 'package:drift/drift.dart';

import '../../domain/models/task_item.dart';
import '../../domain/models/task_occurrence.dart';
import '../../domain/models/timer_session.dart';

/// Drift table definitions (Step 2). Time rules:
/// - Instants (createdAt, updatedAt, startedAt, endedAt, completedAt) are UTC.
/// - Scheduling is wall-clock local time: `scheduledDate` as 'yyyy-MM-dd'
///   text plus `scheduledMinutes` (minutes since midnight). Never UTC, so DST
///   cannot shift it.
/// - Enums are stored as text by name via `textEnum`.
@TableIndex(name: 'tasks_scheduled_date', columns: {#scheduledDate})
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  IntColumn get sortOrder => integer()();
  BoolColumn get isDone =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get estimatedSeconds => integer().nullable()();
  TextColumn get scheduledDate => text().nullable()();
  IntColumn get scheduledMinutes => integer().nullable()();
  TextColumn get recurrenceType =>
      textEnum<RecurrenceType>().withDefault(const Constant('once'))();
  IntColumn get recurrenceInterval =>
      integer().withDefault(const Constant(1))();
  IntColumn get recurrenceWeekdays =>
      integer().withDefault(const Constant(0))();
  TextColumn get recurrenceEndsOn => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'subtasks_task_order', columns: {#taskId, #sortOrder})
class Subtasks extends Table {
  TextColumn get id => text()();
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  IntColumn get sortOrder => integer()();
  BoolColumn get isDone =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'occurrences_date', columns: {#date})
@TableIndex(
  name: 'occurrence_task_date',
  columns: {#taskId, #date},
  unique: true,
)
class TaskOccurrences extends Table {
  TextColumn get id => text()();
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get date => text()();
  TextColumn get status =>
      textEnum<OccurrenceStatus>().withDefault(const Constant('pending'))();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class OccurrenceSubtaskStates extends Table {
  TextColumn get occurrenceId => text().references(
    TaskOccurrences,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get subtaskId => text().references(
    Subtasks,
    #id,
    onDelete: KeyAction.cascade,
  )();
  BoolColumn get isDone =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {occurrenceId, subtaskId};
}

@TableIndex(name: 'timer_sessions_task', columns: {#taskId})
@TableIndex(name: 'timer_sessions_started', columns: {#startedAt})
class TimerSessions extends Table {
  TextColumn get id => text()();
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get subtaskId => text()
      .nullable()
      .references(Subtasks, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get plannedSeconds => integer()();
  IntColumn get elapsedSeconds =>
      integer().withDefault(const Constant(0))();
  TextColumn get mode =>
      textEnum<TimerMode>().withDefault(const Constant('countdown'))();
  TextColumn get endReason => textEnum<TimerEndReason>().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
