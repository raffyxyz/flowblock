import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/task_item.dart';
import 'task_repository.dart';

/// Write path for widgets (Step 3).
///
/// Widgets never touch the database or DAOs; they call these methods and
/// show a `SnackBar` when one throws. Reads stay on `taskListProvider` /
/// `taskProvider` streams.
class TaskActions {
  TaskActions(this._ref);

  final Ref _ref;

  TaskRepository get _repo => _ref.read(taskRepositoryProvider);

  Future<void> addTask(TaskItem draft) => _repo.addTask(draft);

  Future<void> updateTask(TaskItem task) => _repo.updateTask(task);

  Future<void> deleteTask(String id) => _repo.deleteTask(id);

  Future<void> setTaskDone(String id, bool isDone) =>
      _repo.setTaskDone(id, isDone);

  Future<void> toggleTask(TaskItem task) =>
      _repo.setTaskDone(task.id, !task.isDone);

  Future<void> setSubtaskDone(
    String taskId,
    String subtaskId,
    bool isDone,
  ) => _repo.setSubtaskDone(taskId, subtaskId, isDone);

  Future<void> toggleSubtask(TaskItem task, String subtaskId) {
    final Subtask sub = task.subtasks.firstWhere(
      (Subtask s) => s.id == subtaskId,
    );
    return _repo.setSubtaskDone(task.id, subtaskId, !sub.isDone);
  }

  Future<void> addSubtask(
    String taskId, {
    required String title,
    int? durationMinutes,
  }) => _repo.addSubtask(
    taskId,
    title: title,
    durationMinutes: durationMinutes,
  );

  Future<void> deleteSubtask(String taskId, String subtaskId) =>
      _repo.deleteSubtask(taskId, subtaskId);

  Future<void> reorderSubtasks(String taskId, List<String> orderedIds) =>
      _repo.reorderSubtasks(taskId, orderedIds);

  Future<void> reorderTasks(List<String> orderedIds) =>
      _repo.reorderTasks(orderedIds);
}

final Provider<TaskActions> taskActionsProvider = Provider<TaskActions>(
  (Ref ref) => TaskActions(ref),
);
