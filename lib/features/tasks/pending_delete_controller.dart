import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final Map<String, Timer> _pendingTimers = <String, Timer>{};
  final Map<String, Future<void> Function()> _pendingCommits =
      <String, Future<void> Function()>{};

  @override
  PendingDeleteState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      commitAll();
    });
    return const PendingDeleteState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      commitAll();
    }
  }

  void _stopTimerIfAffected(dynamic ref, String taskId, [String? subtaskId]) {
    final ActiveTimer? timer = ref.read(timerControllerProvider);
    if (timer != null && timer.taskId == taskId) {
      if (subtaskId == null || timer.subtaskId == subtaskId) {
        ref.read(timerControllerProvider.notifier).stop();
      }
    }
  }

  void _cancelPendingKey(String key) {
    _pendingTimers.remove(key)?.cancel();
    _pendingCommits.remove(key);
  }

  /// Stages a subtask deletion. Disappears from UI immediately.
  /// Commits after 4 seconds or on pause/dispose. Undo cancels the delete.
  void stageSubtaskDelete({
    required BuildContext context,
    required dynamic ref,
    required String taskId,
    required String subtaskId,
  }) {
    _stopTimerIfAffected(ref, taskId, subtaskId);

    final String key = 'subtask_${taskId}_$subtaskId';
    _cancelPendingKey(key);

    final Set<String> currentSubs =
        Set<String>.from(state.pendingSubtasks[taskId] ?? <String>{});
    currentSubs.add(subtaskId);

    final Map<String, Set<String>> nextMap =
        Map<String, Set<String>>.from(state.pendingSubtasks);
    nextMap[taskId] = currentSubs;
    state = state.copyWith(pendingSubtasks: nextMap);

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    Future<void> commit() async {
      _cancelPendingKey(key);
      _removePendingSubtask(taskId, subtaskId);
      await ref.read(taskRepositoryProvider).deleteSubtask(taskId, subtaskId);
    }

    _pendingCommits[key] = commit;

    final Timer timer = Timer(const Duration(seconds: 4), () async {
      messenger.hideCurrentSnackBar();
      await commit();
    });
    _pendingTimers[key] = timer;

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: const Text('Subtask deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            _cancelPendingKey(key);
            _removePendingSubtask(taskId, subtaskId);
            messenger.hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Stages a task deletion. Disappears from UI immediately.
  /// Commits after 4 seconds or on pause/dispose. Undo cancels the delete.
  void stageTaskDelete({
    required BuildContext context,
    required dynamic ref,
    required String taskId,
  }) {
    _stopTimerIfAffected(ref, taskId);

    final String key = 'task_$taskId';
    _cancelPendingKey(key);

    final Set<String> nextTasks = Set<String>.from(state.pendingTaskIds)
      ..add(taskId);
    state = state.copyWith(pendingTaskIds: nextTasks);

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    Future<void> commit() async {
      _cancelPendingKey(key);
      _removePendingTask(taskId);
      await ref.read(taskRepositoryProvider).deleteTask(taskId);
    }

    _pendingCommits[key] = commit;

    final Timer timer = Timer(const Duration(seconds: 4), () async {
      messenger.hideCurrentSnackBar();
      await commit();
    });
    _pendingTimers[key] = timer;

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: const Text('Task deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            _cancelPendingKey(key);
            _removePendingTask(taskId);
            messenger.hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _removePendingSubtask(String taskId, String subtaskId) {
    final Set<String> currentSubs =
        Set<String>.from(state.pendingSubtasks[taskId] ?? <String>{});
    currentSubs.remove(subtaskId);

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
    final Set<String> nextTasks = Set<String>.from(state.pendingTaskIds)
      ..remove(taskId);
    state = state.copyWith(pendingTaskIds: nextTasks);
  }

  /// Immediately commits all pending deletes (e.g. app backgrounded or screen disposed).
  void commitAll() {
    final List<Timer> timers = _pendingTimers.values.toList();
    _pendingTimers.clear();
    for (final Timer t in timers) {
      t.cancel();
    }
    final List<Future<void> Function()> callbacks =
        _pendingCommits.values.toList();
    _pendingCommits.clear();
    for (final Future<void> Function() cb in callbacks) {
      cb();
    }
  }

  /// Filters a single task, hiding pending deleted subtasks and recomputing parent state.
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
