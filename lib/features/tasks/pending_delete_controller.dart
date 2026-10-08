import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/root_messenger.dart';
import '../../data/task_repository.dart';
import '../../domain/models/task_item.dart';
import '../../domain/task_filters.dart';
import '../timer/timer_controller.dart';

class PendingDeleteState {
  const PendingDeleteState({
    this.pendingTaskIds = const <String>{},
    this.pendingSubtasks = const <String, Set<String>>{},
  });

  final Set<String> pendingTaskIds;
  final Map<String, Set<String>> pendingSubtasks;

  PendingDeleteState copyWith({
    Set<String>? pendingTaskIds,
    Map<String, Set<String>>? pendingSubtasks,
  }) {
    return PendingDeleteState(
      pendingTaskIds: pendingTaskIds ?? this.pendingTaskIds,
      pendingSubtasks: pendingSubtasks ?? this.pendingSubtasks,
    );
  }
}

class PendingDeleteController extends Notifier<PendingDeleteState>
    with WidgetsBindingObserver {
  final Map<String, Future<void> Function()> _pendingCommits =
      <String, Future<void> Function()>{};

  @override
  PendingDeleteState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
    });
    return const PendingDeleteState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      commitAll();
    }
  }

  ScaffoldMessengerState _messenger(BuildContext context) {
    return rootScaffoldMessengerKey.currentState ??
        ScaffoldMessenger.of(context);
  }

  void _stopTimerIfAffected(dynamic ref, String taskId, [String? subtaskId]) {
    final ActiveTimer? timer = ref.read(timerControllerProvider);
    if (timer != null && timer.taskId == taskId) {
      if (subtaskId == null || timer.subtaskId == subtaskId) {
        ref.read(timerControllerProvider.notifier).stop();
      }
    }
  }

  void _commitKey(String key) {
    final Future<void> Function()? fn = _pendingCommits[key];
    if (fn != null) {
      fn();
    }
  }

  void _commitAllExcept(String exceptKey) {
    final List<String> keys = _pendingCommits.keys
        .where((String k) => k != exceptKey)
        .toList();
    for (final String k in keys) {
      _commitKey(k);
    }
  }

  /// Stages a subtask deletion. Disappears from UI immediately.
  /// Commits when its SnackBar closes without Undo, on paused/detached,
  /// or when another delete starts. Never on dispose/inactive/hidden.
  void stageSubtaskDelete({
    required BuildContext context,
    required dynamic ref,
    required String taskId,
    required String subtaskId,
  }) {
    _stopTimerIfAffected(ref, taskId, subtaskId);

    final String key = 'subtask_${taskId}_$subtaskId';
    _commitAllExcept(key);
    _pendingCommits.remove(key);

    final Set<String> currentSubs =
        Set<String>.from(state.pendingSubtasks[taskId] ?? <String>{});
    currentSubs.add(subtaskId);
    final Map<String, Set<String>> nextMap =
        Map<String, Set<String>>.from(state.pendingSubtasks);
    nextMap[taskId] = currentSubs;
    state = state.copyWith(pendingSubtasks: nextMap);

    final ScaffoldMessengerState messenger = _messenger(context);

    Future<void> commit() async {
      if (!_pendingCommits.containsKey(key)) {
        return;
      }
      _pendingCommits.remove(key);
      _removePendingSubtask(taskId, subtaskId);
      try {
        await this.ref.read(taskRepositoryProvider).deleteSubtask(
          taskId,
          subtaskId,
        );
      } catch (_) {
        // Already gone (race with Undo/commit): safe no-op.
      }
    }

    _pendingCommits[key] = commit;

    final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> handle =
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            persist: false,
            content: const Text('Subtask deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                undoSubtaskDelete(taskId, subtaskId);
                messenger.hideCurrentSnackBar(
                  reason: SnackBarClosedReason.action,
                );
              },
            ),
          ),
        );
    handle.closed.then((SnackBarClosedReason reason) {
      if (reason != SnackBarClosedReason.action) {
        _commitKey(key);
      }
    });
  }

  /// Stages a task deletion. Disappears from UI immediately.
  /// Same commit rules as [stageSubtaskDelete].
  void stageTaskDelete({
    required BuildContext context,
    required dynamic ref,
    required String taskId,
  }) {
    _stopTimerIfAffected(ref, taskId);

    final String key = 'task_$taskId';
    _commitAllExcept(key);
    _pendingCommits.remove(key);

    final Set<String> nextTasks = Set<String>.from(state.pendingTaskIds)
      ..add(taskId);
    state = state.copyWith(pendingTaskIds: nextTasks);

    final ScaffoldMessengerState messenger = _messenger(context);

    Future<void> commit() async {
      if (!_pendingCommits.containsKey(key)) {
        return;
      }
      _pendingCommits.remove(key);
      _removePendingTask(taskId);
      try {
        await this.ref.read(taskRepositoryProvider).deleteTask(taskId);
      } catch (_) {
        // Already gone (race with Undo/commit): safe no-op.
      }
    }

    _pendingCommits[key] = commit;

    final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> handle =
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            persist: false,
            content: const Text('Task deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                undoTaskDelete(taskId);
                messenger.hideCurrentSnackBar(
                  reason: SnackBarClosedReason.action,
                );
              },
            ),
          ),
        );
    handle.closed.then((SnackBarClosedReason reason) {
      if (reason != SnackBarClosedReason.action) {
        _commitKey(key);
      }
    });
  }

  /// Cancels a pending task delete. Zero database calls; safe after commit.
  void undoTaskDelete(String taskId) {
    _pendingCommits.remove('task_$taskId');
    _removePendingTask(taskId);
  }

  /// Cancels a pending subtask delete. Zero database calls; safe after commit.
  void undoSubtaskDelete(String taskId, String subtaskId) {
    _pendingCommits.remove('subtask_${taskId}_$subtaskId');
    _removePendingSubtask(taskId, subtaskId);
  }

  void _removePendingSubtask(String taskId, String subtaskId) {
    final Set<String> currentSubs =
        Set<String>.from(state.pendingSubtasks[taskId] ?? <String>{});
    if (!currentSubs.remove(subtaskId)) {
      return;
    }
    final Map<String, Set<String>> nextMap =
        Map<String, Set<String>>.from(state.pendingSubtasks);
    if (currentSubs.isEmpty) {
      nextMap.remove(taskId);
    } else {
      nextMap[taskId] = currentSubs;
    }
    state = state.copyWith(pendingSubtasks: nextMap);
  }

  void _removePendingTask(String taskId) {
    if (!state.pendingTaskIds.contains(taskId)) {
      return;
    }
    final Set<String> nextTasks = Set<String>.from(state.pendingTaskIds)
      ..remove(taskId);
    state = state.copyWith(pendingTaskIds: nextTasks);
  }

  /// Commits all pending deletes (paused/detached or superseded).
  void commitAll() {
    final List<String> keys = _pendingCommits.keys.toList();
    for (final String k in keys) {
      _commitKey(k);
    }
  }

  /// Filters a single task, hiding pending deleted subtasks and recomputing.
  /// Returns null if the task itself is pending deleted.
  TaskItem? filterTask(TaskItem? task) {
    if (task == null || state.pendingTaskIds.contains(task.id)) {
      return null;
    }
    final Set<String>? pendingSubs = state.pendingSubtasks[task.id];
    if (pendingSubs == null || pendingSubs.isEmpty) {
      return task;
    }
    final List<Subtask> remaining =
        task.subtasks.where((Subtask s) => !pendingSubs.contains(s.id)).toList();
    return recomputeParent(task.copyWith(subtasks: remaining), DateTime.now());
  }

  /// Filters a list of tasks.
  List<TaskItem> filterTaskList(List<TaskItem> tasks) {
    final List<TaskItem> result = <TaskItem>[];
    for (final TaskItem t in tasks) {
      final TaskItem? filtered = filterTask(t);
      if (filtered != null) {
        result.add(filtered);
      }
    }
    return result;
  }
}

final pendingDeleteControllerProvider =
    NotifierProvider<PendingDeleteController, PendingDeleteState>(
      PendingDeleteController.new,
    );
