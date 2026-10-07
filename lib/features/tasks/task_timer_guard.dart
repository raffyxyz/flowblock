import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/task_item.dart';
import '../timer/timer_controller.dart';

/// Guard for the moment a task gains its first subtask.
///
/// Returns true when the caller may proceed. If a task-level timer is
/// currently running for [task], shows a confirm dialog and stops the timer
/// on confirm; returns false when the user cancels. Used by the detail
/// screen's inline add and by the form sheet's save.
Future<bool> confirmStopTaskTimer(
  BuildContext context,
  WidgetRef ref,
  TaskItem task,
) async {
  final ActiveTimer? timer = ref.read(timerControllerProvider);
  if (timer == null ||
      timer.taskId != task.id ||
      timer.subtaskId != null) {
    return true;
  }
  final bool? stop = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Stop current timer?'),
        content: const Text("Adding subtasks will stop this task's timer."),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Stop timer'),
          ),
        ],
      );
    },
  );
  if (stop == true) {
    ref.read(timerControllerProvider.notifier).stop();
    return true;
  }
  return false;
}
