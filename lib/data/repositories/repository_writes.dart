import '../../domain/models/task_item.dart';
import '../../domain/task_filters.dart';
import '../../domain/task_validator.dart';
import '../../domain/validation_exception.dart';
import '../db/database.dart' hide Subtask;
import '../db/mappers.dart';
import '../task_repository.dart';
import 'drift_task_repository.dart' show requireSameIds;

/// Write operations for [DriftTaskRepository].
///
/// A mixin (not an extension) so its methods count toward the
/// [TaskRepository] interface. Each operation runs in exactly one
/// `db.transaction`, reusing the shared helpers ([writeParent], [touchTask],
/// [touchSubtask], [getById]) implemented by the repository class.
mixin RepositoryWrites implements TaskRepository {
  AppDatabase get db;
  DateTime Function() get clock;
  String Function() get newId;
  DateTime get now;

  Future<void> writeParent(
    TaskItem task,
    DateTime moment, {
    bool keepWhenEmpty = false,
  });
  Future<void> touchTask(String id, DateTime moment);
  Future<void> touchSubtask(String id, DateTime moment);

  @override
  Future<void> setTaskDone(String id, bool isDone) {
    return db.transaction(() async {
      final DateTime moment = now;
      final TaskItem? current = await getById(id);
      if (current == null) {
        throw StateError('Task not found: $id');
      }
      await db.tasksDao.updateTask(
        taskCompanionFromDomain(
          current.copyWith(
            isDone: isDone,
            completedAt: isDone ? moment : null,
            clearCompletedAt: !isDone,
            updatedAt: moment,
          ),
        ),
      );
      for (final Subtask s in current.subtasks) {
        await db.subtasksDao.updateSubtask(
          subtaskCompanionFromDomain(
            s.copyWith(
              isDone: isDone,
              completedAt: isDone ? moment : null,
              clearCompletedAt: !isDone,
              updatedAt: moment,
            ),
            id,
          ),
        );
      }
    });
  }

  @override
  Future<void> toggleTaskDone(String id) {
    return db.transaction(() async {
      final DateTime moment = now;
      final TaskItem? current = await getById(id);
      if (current == null) {
        throw StateError('Task not found: $id');
      }
      if (current.hasSubtasks) {
        final bool allDone = current.subtasks.every((Subtask s) => s.isDone);
        final bool targetDone = !allDone;
        await db.tasksDao.updateTask(
          taskCompanionFromDomain(
            current.copyWith(
              isDone: targetDone,
              completedAt: targetDone ? moment : null,
              clearCompletedAt: !targetDone,
              updatedAt: moment,
            ),
          ),
        );
        for (final Subtask s in current.subtasks) {
          await db.subtasksDao.updateSubtask(
            subtaskCompanionFromDomain(
              s.copyWith(
                isDone: targetDone,
                completedAt: targetDone ? moment : null,
                clearCompletedAt: !targetDone,
                updatedAt: moment,
              ),
              id,
            ),
          );
        }
      } else {
        final bool targetDone = !current.isDone;
        await db.tasksDao.updateTask(
          taskCompanionFromDomain(
            current.copyWith(
              isDone: targetDone,
              completedAt: targetDone ? moment : null,
              clearCompletedAt: !targetDone,
              updatedAt: moment,
            ),
          ),
        );
      }
    });
  }

  @override
  Future<void> setSubtaskDone(
    String taskId,
    String subtaskId,
    bool isDone,
  ) {
    return db.transaction(() async {
      final DateTime moment = now;
      final TaskItem? current = await getById(taskId);
      if (current == null) {
        throw StateError('Task not found: $taskId');
      }
      if (current.subtasks.every((Subtask s) => s.id != subtaskId)) {
        throw StateError('Subtask not found: $subtaskId');
      }
      final List<Subtask> subs = <Subtask>[
        for (final Subtask s in current.subtasks)
          if (s.id == subtaskId)
            s.copyWith(
              isDone: isDone,
              completedAt: isDone ? moment : null,
              clearCompletedAt: !isDone,
              updatedAt: moment,
            )
          else
            s,
      ];
      await db.subtasksDao.updateSubtask(
        subtaskCompanionFromDomain(
          subs.firstWhere((Subtask s) => s.id == subtaskId),
          taskId,
        ),
      );
      await writeParent(current.copyWith(subtasks: subs), moment);
    });
  }

  @override
  Future<void> addSubtask(
    String taskId, {
    required String title,
    int? durationMinutes,
  }) async {
    validateSubtaskTitle(title);
    validateDuration(durationMinutes, 'Subtask duration');
    return db.transaction(() async {
      final DateTime moment = now;
      final TaskItem? current = await getById(taskId);
      if (current == null) {
        throw StateError('Task not found: $taskId');
      }
      if (current.subtasks.length >= 50) {
        throw ValidationException('A task cannot have more than 50 subtasks');
      }
      int order = -1;
      for (final Subtask s in current.subtasks) {
        if (s.sortOrder > order) {
          order = s.sortOrder;
        }
      }
      final Subtask sub = Subtask(
        id: newId(),
        title: title,
        durationMinutes: durationMinutes,
        sortOrder: order + 1,
        createdAt: moment,
        updatedAt: moment,
      );
      await db.subtasksDao.insert(subtaskCompanionFromDomain(sub, taskId));
      await writeParent(
        current.copyWith(subtasks: <Subtask>[...current.subtasks, sub]),
        moment,
      );
    });
  }

  @override
  Future<void> updateSubtask(String taskId, Subtask subtask) async {
    validateSubtaskTitle(subtask.title);
    validateDuration(subtask.durationMinutes, 'Subtask duration');
    return db.transaction(() async {
      final DateTime moment = now;
      final TaskItem? current = await getById(taskId);
      if (current == null) {
        throw StateError('Task not found: $taskId');
      }
      final Subtask? old = findSubtask(current, subtask.id);
      if (old == null) {
        throw StateError('Subtask not found: ${subtask.id}');
      }
      await db.subtasksDao.updateSubtask(
        subtaskCompanionFromDomain(
          old.copyWith(
            title: subtask.title,
            durationMinutes: subtask.durationMinutes,
            clearDurationMinutes: subtask.durationMinutes == null,
            updatedAt: moment,
          ),
          taskId,
        ),
      );
      await touchTask(taskId, moment);
    });
  }

  @override
  Future<void> deleteSubtask(String taskId, String subtaskId) {
    return db.transaction(() async {
      final DateTime moment = now;
      final TaskItem? current = await getById(taskId);
      if (current == null) {
        throw StateError('Task not found: $taskId');
      }
      await db.subtasksDao.deleteSubtask(subtaskId);
      await writeParent(
        current.copyWith(
          subtasks: <Subtask>[
            for (final Subtask s in current.subtasks)
              if (s.id != subtaskId) s,
          ],
        ),
        moment,
        keepWhenEmpty: true,
      );
    });
  }

  @override
  Future<void> reorderSubtasks(String taskId, List<String> orderedIds) {
    return db.transaction(() async {
      final DateTime moment = now;
      final TaskItem? current = await getById(taskId);
      if (current == null) {
        throw StateError('Task not found: $taskId');
      }
      requireSameIds(
        <String>{for (final Subtask s in current.subtasks) s.id},
        orderedIds.toSet(),
        'subtasks',
      );
      await db.subtasksDao.reorder(taskId, orderedIds);
      for (final Subtask s in current.subtasks) {
        await touchSubtask(s.id, moment);
      }
      await touchTask(taskId, moment);
    });
  }

  @override
  Future<void> reorderTasks(List<String> orderedIds) {
    return db.transaction(() async {
      final DateTime moment = now;
      await db.tasksDao.reorderTasks(orderedIds);
      for (final String id in orderedIds) {
        await touchTask(id, moment);
      }
    });
  }
}
