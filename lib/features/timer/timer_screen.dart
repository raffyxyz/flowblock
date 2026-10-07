import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/circular_timer_ring.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/subtask_tile.dart';
import '../../../data/task_repository.dart';
import '../../../domain/models/task_item.dart';
import 'timer_controller.dart';

/// Full-screen minimal focus timer. The countdown itself is owned by
/// [TimerController] (isolated placeholder); this screen only renders state.
///
/// [taskId]/[subtaskId] come from the route. Opening the route for a task
/// that has subtasks without a subtask id shows a safe fallback instead of
/// a ring (a task-level timer cannot exist for such tasks).
class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key, this.taskId, this.subtaskId});

  final String? taskId;
  final String? subtaskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ActiveTimer? timer = ref.watch(timerControllerProvider);
    final List<TaskItem> tasks = ref.watch(taskListProvider);
    final String? routeId = taskId;
    final TaskItem? routeTask =
        routeId == null ? null : findTask(tasks, routeId);
    if (routeTask != null &&
        routeTask.hasSubtasks &&
        (subtaskId == null ||
            routeTask.subtasks.every(
              (Subtask s) => s.id != subtaskId,
            ))) {
      return Scaffold(
        appBar: AppBar(title: const Text('Timer')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppSpace.contentMax),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                EmptyState(
                  icon: Icons.timer_off_outlined,
                  title: 'Timers live on subtasks',
                  subtitle:
                      '“${routeTask.title}” has subtasks. Start a timer '
                      'from one of its subtasks instead.',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.x5,
                  ),
                  child: PrimaryButton(
                    label: 'Go back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final TaskItem? task =
        timer == null ? null : findTask(tasks, timer.taskId);

    return Scaffold(
      appBar: AppBar(title: const Text('Timer')),
      body: timer == null
          ? const EmptyState(
              icon: Icons.timer_outlined,
              title: 'No active timer',
              subtitle:
                  'Start a timer from any task or subtask to begin a focus session.',
            )
          : _RunningTimer(timer: timer, task: task),
    );
  }
}

class _RunningTimer extends ConsumerWidget {
  const _RunningTimer({required this.timer, required this.task});

  final ActiveTimer timer;
  final TaskItem? task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TimerController controller =
        ref.read(timerControllerProvider.notifier);
    final TaskItem? current = task;
    final bool hasNext = current != null &&
        timerHasNext(timer, ref.watch(taskListProvider));
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpace.contentMax),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.x5,
            AppSpace.x2,
            AppSpace.x5,
            AppSpace.x8,
          ),
          children: <Widget>[
            Text(
              timer.parentTitle,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.muted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.x1),
            Text(
              timer.title,
              style: context.text.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.x6),
            Center(
              child: CircularTimerRing(
                progress: timer.progress,
                child: Text(
                  formatCountdown(timer.remainingSeconds),
                  style: context.text.displaySmall,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.x6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _TimerControl(
                  icon: Icons.stop,
                  label: 'Stop timer',
                  onPressed: () {
                    controller.stop();
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(width: AppSpace.x5),
                _TimerControl(
                  icon: timer.isRunning ? Icons.pause : Icons.play_arrow,
                  label: timer.isRunning ? 'Pause timer' : 'Resume timer',
                  primary: true,
                  onPressed: controller.toggle,
                ),
                const SizedBox(width: AppSpace.x5),
                _TimerControl(
                  icon: Icons.skip_next,
                  label: 'Skip to next subtask',
                  onPressed: hasNext ? controller.skipNext : null,
                ),
              ],
            ),
            if (current != null && current.subtasks.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpace.x8),
              const SectionHeader(title: 'Subtasks'),
              const SizedBox(height: AppSpace.x2),
              for (final Subtask subtask in current.subtasks)
                SubtaskTile(
                  key: ValueKey<String>(subtask.id),
                  subtask: subtask,
                  highlighted: subtask.id == timer.subtaskId,
                  onToggled: (_) => ref
                      .read(taskListProvider.notifier)
                      .toggleSubtask(current.id, subtask.id),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimerControl extends StatelessWidget {
  const _TimerControl({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final double size = primary ? 76 : 60;
    final Widget button = primary
        ? FilledButton(
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            onPressed: onPressed,
            child: Icon(icon, size: 32),
          )
        : OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            onPressed: onPressed,
            child: Icon(icon, size: 26),
          );
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(width: size, height: size, child: button),
    );
  }
}
