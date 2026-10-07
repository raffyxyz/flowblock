import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/task_item.dart';
import '../domain/task_filters.dart';
import 'db/provider.dart';
import 'repositories/drift_task_repository.dart';

/// The only task store widgets and providers depend on (Step 3).
///
/// Reads are [Stream]s; writes are [Future]s. Implemented by
/// [DriftTaskRepository]; business rules (parent recompute, timestamps,
/// sort orders) live there, each write in one transaction.
abstract class TaskRepository {
  Stream<List<TaskItem>> watchAll();
  Stream<TaskItem?> watchById(String id);
  Future<TaskItem?> getById(String id);
  Future<void> addTask(TaskItem draft);
  Future<void> updateTask(TaskItem task);
  Future<void> deleteTask(String id);
  Future<void> setTaskDone(String id, bool isDone);
  Future<void> setSubtaskDone(String taskId, String subtaskId, bool isDone);
  Future<void> addSubtask(
    String taskId, {
    required String title,
    int? durationMinutes,
  });
  Future<void> updateSubtask(String taskId, Subtask subtask);
  Future<void> deleteSubtask(String taskId, String subtaskId);
  Future<void> reorderSubtasks(String taskId, List<String> orderedIds);
  Future<void> reorderTasks(List<String> orderedIds);
}

/// UTC clock, injected so repository tests are deterministic.
final Provider<DateTime Function()> clockProvider =
    Provider<DateTime Function()>((Ref ref) => () => DateTime.now().toUtc());

/// Id generator, injected so repository tests are deterministic.
final Provider<String Function()> idGeneratorProvider =
    Provider<String Function()>((Ref ref) {
      final Uuid uuid = Uuid();
      return uuid.v4;
    });

final Provider<TaskRepository> taskRepositoryProvider =
    Provider<TaskRepository>(
      (Ref ref) => DriftTaskRepository(
        db: ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
        newId: ref.watch(idGeneratorProvider),
      ),
    );

/// All tasks, ordered by `sortOrder`.
final StreamProvider<List<TaskItem>> taskListProvider =
    StreamProvider<List<TaskItem>>(
      (Ref ref) => ref.watch(taskRepositoryProvider).watchAll(),
    );

/// One task by id (`null` when deleted).
final taskProvider = StreamProvider.family<TaskItem?, String>(
  (Ref ref, String id) => ref.watch(taskRepositoryProvider).watchById(id),
);

/// Tasks scheduled for the current day (same-day match; Step 5 expands this).
final Provider<AsyncValue<List<TaskItem>>> todayTasksProvider =
    Provider<AsyncValue<List<TaskItem>>>(
      (Ref ref) => ref
          .watch(taskListProvider)
          .whenData(
            (List<TaskItem> tasks) => tasksForDate(tasks, DateTime.now()),
          ),
    );
