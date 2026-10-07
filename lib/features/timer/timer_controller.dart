import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../data/task_repository.dart';
import '../../domain/models/task_item.dart';
import '../settings/settings_providers.dart';

/// Snapshot of the currently running focus session.
///
/// Step 1 placeholder: the countdown is a plain in-memory [Timer] owned by
/// [TimerController]. A later step replaces this file with persisted timer
/// logic; widgets only read [timerControllerProvider] and call
/// start/toggle/stop/skipNext, so they will not need changes.
@immutable
class ActiveTimer {
  const ActiveTimer({
    required this.taskId,
    this.subtaskId,
    required this.title,
    required this.parentTitle,
    required this.totalSeconds,
    required this.remainingSeconds,
    required this.isRunning,
  });

  final String taskId;
  final String? subtaskId;
  final String title;
  final String parentTitle;
  final int totalSeconds;
  final int remainingSeconds;
  final bool isRunning;

  /// Fraction of time remaining, 1.0 at start and 0.0 when finished.
  double get progress {
    if (totalSeconds <= 0) {
      return 0;
    }
    return (remainingSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  ActiveTimer copyWith({int? remainingSeconds, bool? isRunning}) {
    return ActiveTimer(
      taskId: taskId,
      subtaskId: subtaskId,
      title: title,
      parentTitle: parentTitle,
      totalSeconds: totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

class TimerController extends Notifier<ActiveTimer?> {
  Timer? _ticker;

  @override
  ActiveTimer? build() {
    ref.onDispose(() => _ticker?.cancel());
    return null;
  }

  /// Starts (or restarts) a session for [task], or for [subtask] within it.
  /// A task-level start is refused when the task has subtasks: timers live
  /// on the subtasks. UI gates this too; this is the mock-layer backstop.
  void start({required TaskItem task, Subtask? subtask}) {
    if (subtask == null && task.hasSubtasks) {
      return;
    }
    final int minutes = subtask?.durationMinutes ??
        task.durationMinutes ??
        ref.read(defaultDurationProvider);
    final int total = (minutes * 60).clamp(60, 5999 * 60);
    _ticker?.cancel();
    state = ActiveTimer(
      taskId: task.id,
      subtaskId: subtask?.id,
      title: subtask?.title ?? task.title,
      parentTitle:
          subtask == null ? formatShortDay(task.date) : task.title,
      totalSeconds: total,
      remainingSeconds: total,
      isRunning: true,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final ActiveTimer? current = state;
    if (current == null || !current.isRunning) {
      return;
    }
    if (current.remainingSeconds <= 1) {
      _ticker?.cancel();
      state = current.copyWith(remainingSeconds: 0, isRunning: false);
      return;
    }
    state = current.copyWith(remainingSeconds: current.remainingSeconds - 1);
  }

  void toggle() {
    final ActiveTimer? current = state;
    if (current == null) {
      return;
    }
    if (current.isRunning) {
      _ticker?.cancel();
      state = current.copyWith(isRunning: false);
    } else {
      if (current.remainingSeconds <= 0) {
        return;
      }
      state = current.copyWith(isRunning: true);
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  /// Stops the session and clears the mini timer bar.
  void stop() {
    _ticker?.cancel();
    state = null;
  }

  /// Jumps to the next open subtask of the same parent, if there is one.
  void skipNext() {
    final ActiveTimer? current = state;
    if (current == null) {
      return;
    }
    final TaskItem? task =
        findTask(ref.read(taskListProvider), current.taskId);
    if (task == null) {
      stop();
      return;
    }
    final int index =
        task.subtasks.indexWhere((Subtask s) => s.id == current.subtaskId);
    for (int i = index + 1; i < task.subtasks.length; i++) {
      if (!task.subtasks[i].isDone) {
        start(task: task, subtask: task.subtasks[i]);
        return;
      }
    }
    stop();
  }
}

final timerControllerProvider =
    NotifierProvider<TimerController, ActiveTimer?>(TimerController.new);

/// Whether a further open subtask exists after the currently timed one.
bool timerHasNext(ActiveTimer timer, List<TaskItem> tasks) {
  final TaskItem? task = findTask(tasks, timer.taskId);
  if (task == null || task.subtasks.isEmpty) {
    return false;
  }
  final int index =
      task.subtasks.indexWhere((Subtask s) => s.id == timer.subtaskId);
  for (int i = index + 1; i < task.subtasks.length; i++) {
    if (!task.subtasks[i].isDone) {
      return true;
    }
  }
  return false;
}
