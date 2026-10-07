import 'package:drift/drift.dart';

import '../../domain/models/task_item.dart';
import '../../domain/task_filters.dart';
import '../db/daos/tasks_dao.dart';
import '../db/database.dart' hide Subtask;
import '../db/mappers.dart';
import '../task_repository.dart';
import 'repository_writes.dart';

/// Drift-backed [TaskRepository] (Step 3).
///
/// Business rules live here; DAOs stay pure data operations:
/// - After any subtask change the parent is recomputed ([recomputeParent]);
///   with no subtasks left the parent is left unchanged (delete path).
/// - `createdAt` is set on insert and never changes; `updatedAt` on writes.
/// - New tasks/subtasks get `sortOrder = max + 1`; reorders rewrite `0..n-1`.
/// - Recurrence and the occurrence/timer tables are NOT used in this step.
///
/// Reads and helpers live here; the write operations live in the
/// [RepositoryWrites] mixin (same behavior, one transaction each).
class DriftTaskRepository with RepositoryWrites implements TaskRepository {
  DriftTaskRepository({
    required this.db,
    required this.clock,
    required this.newId,
  });

  @override
  final AppDatabase db;
  @override
  final DateTime Function() clock;
  @override
  final String Function() newId;

  @override
  DateTime get now => clock().toUtc();

  @override
  Stream<List<TaskItem>> watchAll() {
    return db.tasksDao.watchAllWithSubtasks().map(
      (List<TaskWithSubtasks> rows) => <TaskItem>[
        for (final TaskWithSubtasks e in rows)
          taskItemFromRows(e.task, e.subtasks),
      ],
    );
  }

  @override
  Stream<TaskItem?> watchById(String id) {
    return db.tasksDao.watchById(id).map(
      (TaskWithSubtasks? e) =>
          e == null ? null : taskItemFromRows(e.task, e.subtasks),
    );
  }

  @override
  Future<TaskItem?> getById(String id) async {
    final TaskWithSubtasks? e = await db.tasksDao.getById(id);
    return e == null ? null : taskItemFromRows(e.task, e.subtasks);
  }

  @override
  Future<void> deleteTask(String id) {
    return db.tasksDao.deleteTask(id);
  }

  @override
  Future<void> addTask(TaskItem draft) {
    return db.transaction(() async {
      final DateTime moment = now;
      final Task? last =
          await (db.select(db.tasks)
                ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
                ..limit(1))
              .getSingleOrNull();
      final String taskId = newId();
      final List<Subtask> subs = <Subtask>[
        for (int i = 0; i < draft.subtasks.length; i++)
          Subtask(
            id: newId(),
            title: draft.subtasks[i].title,
            durationMinutes: draft.subtasks[i].durationMinutes,
            isDone: draft.subtasks[i].isDone,
            sortOrder: i,
            completedAt: draft.subtasks[i].isDone ? moment : null,
            createdAt: moment,
            updatedAt: moment,
          ),
      ];
      final bool allDone =
          subs.isNotEmpty && subs.every((Subtask s) => s.isDone);
      final bool done = subs.isEmpty ? draft.isDone : allDone;
      await db.tasksDao.insertTaskWithSubtasks(
        taskCompanionFromDomain(
          TaskItem(
            id: taskId,
            title: draft.title,
            notes: draft.notes,
            date: draft.date,
            time: draft.time,
            recurrence: draft.recurrence,
            weekdays: draft.weekdays,
            durationMinutes: draft.durationMinutes,
            isDone: done,
            subtasks: subs,
            sortOrder: (last?.sortOrder ?? -1) + 1,
            completedAt: done ? moment : null,
            recurrenceInterval: draft.recurrenceInterval,
            recurrenceEndsOn: draft.recurrenceEndsOn,
            createdAt: moment,
            updatedAt: moment,
          ),
        ),
        <SubtasksCompanion>[
          for (final Subtask s in subs) subtaskCompanionFromDomain(s, taskId),
        ],
      );
    });
  }

  @override
  Future<void> updateTask(TaskItem task) {
    return db.transaction(() async {
      final DateTime moment = now;
      final TaskWithSubtasks? current = await db.tasksDao.getById(task.id);
      if (current == null) {
        throw StateError('Task not found: ${task.id}');
      }
      final Map<String, Subtask> prev = <String, Subtask>{
        for (final s in current.subtasks) s.id: subtaskFromRow(s),
      };
      final Set<String> incoming = <String>{
        for (final Subtask s in task.subtasks) s.id,
      };
      for (final String id in prev.keys) {
        if (!incoming.contains(id)) {
          await db.subtasksDao.deleteSubtask(id);
        }
      }
      final List<Subtask> synced = <Subtask>[];
      for (int i = 0; i < task.subtasks.length; i++) {
        final Subtask s = task.subtasks[i];
        final Subtask? old = prev[s.id];
        final bool newlyDone = s.isDone && !(old?.isDone ?? false);
        final Subtask row = s.copyWith(
          sortOrder: i,
          completedAt: newlyDone ? moment : s.completedAt,
          clearCompletedAt: !s.isDone,
          createdAt: old?.createdAt ?? moment,
          updatedAt: moment,
        );
        synced.add(row);
        final SubtasksCompanion entry =
            subtaskCompanionFromDomain(row, task.id);
        if (old == null) {
          await db.subtasksDao.insert(entry);
        } else {
          await db.subtasksDao.updateSubtask(entry);
        }
      }
      await writeParent(
        task.copyWith(
          subtasks: synced,
          sortOrder: current.task.sortOrder,
          createdAt: current.task.createdAt,
        ),
        moment,
      );
    });
  }

  @override
  Future<void> writeParent(
    TaskItem task,
    DateTime moment, {
    bool keepWhenEmpty = false,
  }) async {
    final TaskItem next =
        (keepWhenEmpty && task.subtasks.isEmpty)
            ? task
            : recomputeParent(task, moment);
    await db.tasksDao.updateTask(
      taskCompanionFromDomain(next.copyWith(updatedAt: moment)),
    );
  }

  @override
  Future<void> touchTask(String id, DateTime moment) {
    return (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(updatedAt: Value<DateTime>(moment)),
    );
  }

  @override
  Future<void> touchSubtask(String id, DateTime moment) {
    return (db.update(db.subtasks)..where((s) => s.id.equals(id))).write(
      SubtasksCompanion(updatedAt: Value<DateTime>(moment)),
    );
  }
}

void requireSameIds(Set<String> current, Set<String> next, String what) {
  if (current.length != next.length || !current.containsAll(next)) {
    throw ArgumentError('ordered ids do not match current $what');
  }
}
