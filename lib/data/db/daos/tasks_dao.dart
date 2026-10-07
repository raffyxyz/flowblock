import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'tasks_dao.g.dart';

/// One task row plus its ordered subtask rows.
class TaskWithSubtasks {
  const TaskWithSubtasks({required this.task, required this.subtasks});

  final Task task;
  final List<Subtask> subtasks;
}

/// Pure data operations for tasks (no business rules: no auto-complete,
/// no recurrence math, no timer rules).
@DriftAccessor(tables: [Tasks, Subtasks])
class TasksDao extends DatabaseAccessor<AppDatabase>
    with _$TasksDaoMixin {
  TasksDao(super.db);

  Stream<List<TaskWithSubtasks>> watchAllWithSubtasks() {
    final SimpleSelectStatement<$TasksTable, Task> query =
        select(tasks)
          ..orderBy(<OrderClauseGenerator<$TasksTable>>[
            (Tasks t) => OrderingTerm.asc(t.sortOrder),
          ]);
    return query.watch().asyncMap((List<Task> rows) async {
      final List<TaskWithSubtasks> out = <TaskWithSubtasks>[];
      for (final Task task in rows) {
        final List<Subtask> subs =
            await (select(subtasks)
                  ..where((Subtasks s) => s.taskId.equals(task.id))
                  ..orderBy(<OrderClauseGenerator<$SubtasksTable>>[
                    (Subtasks s) => OrderingTerm.asc(s.sortOrder),
                  ]))
                .get();
        out.add(TaskWithSubtasks(task: task, subtasks: subs));
      }
      return out;
    });
  }

  Stream<TaskWithSubtasks?> watchById(String id) {
    return (select(tasks)..where((Tasks t) => t.id.equals(id)))
        .watchSingleOrNull()
        .asyncMap((Task? task) async {
          if (task == null) {
            return null;
          }
          final List<Subtask> subs =
              await (select(subtasks)
                    ..where((Subtasks s) => s.taskId.equals(task.id))
                    ..orderBy(<OrderClauseGenerator<$SubtasksTable>>[
                      (Subtasks s) => OrderingTerm.asc(s.sortOrder),
                    ]))
                  .get();
          return TaskWithSubtasks(task: task, subtasks: subs);
        });
  }

  Future<TaskWithSubtasks?> getById(String id) async {
    final Task? task =
        await (select(tasks)..where((Tasks t) => t.id.equals(id)))
            .getSingleOrNull();
    if (task == null) {
      return null;
    }
    final List<Subtask> subs =
        await (select(subtasks)
              ..where((Subtasks s) => s.taskId.equals(task.id))
              ..orderBy(<OrderClauseGenerator<$SubtasksTable>>[
                (Subtasks s) => OrderingTerm.asc(s.sortOrder),
              ]))
            .get();
    return TaskWithSubtasks(task: task, subtasks: subs);
  }

  Future<void> insertTaskWithSubtasks(
    TasksCompanion task,
    List<SubtasksCompanion> subs,
  ) {
    return transaction(() async {
      await into(tasks).insert(task);
      for (final SubtasksCompanion entry in subs) {
        await into(subtasks).insert(entry);
      }
    });
  }

  Future<bool> updateTask(TasksCompanion entry) {
    return update(tasks).replace(entry);
  }

  Future<int> deleteTask(String id) {
    return (delete(tasks)..where((Tasks t) => t.id.equals(id))).go();
  }

  Future<void> reorderTasks(List<String> orderedIds) {
    return transaction(() async {
      for (int i = 0; i < orderedIds.length; i++) {
        await (update(tasks)
              ..where((Tasks t) => t.id.equals(orderedIds[i])))
            .write(TasksCompanion(sortOrder: Value<int>(i)));
      }
    });
  }
}
