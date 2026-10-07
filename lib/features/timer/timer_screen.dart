import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/task_repository.dart';
import '../../../domain/models/task_item.dart';
import 'running_timer.dart';
import 'timer_controller.dart';

/// Full-screen minimal focus timer. The countdown itself is owned by
/// [TimerController] (placeholder ticker); this screen only renders state.
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
    // Unconditional watch ('no id' simply yields null data).
    final AsyncValue<TaskItem?> routeTask =
        ref.watch(taskProvider(taskId ?? ''));
    if (taskId != null) {
      return routeTask.when(
        data: (TaskItem? task) {
          if (task != null &&
              task.hasSubtasks &&
              (subtaskId == null ||
                  task.subtasks.every(
                    (Subtask s) => s.id != subtaskId,
                  ))) {
            return _FallbackShell(
              title: 'Timers live on subtasks',
              subtitle:
                  '“${task.title}” has subtasks. Start a timer '
                  'from one of its subtasks instead.',
            );
          }
          return _TimerBody(timer: timer);
        },
        loading: () => const _LoadingShell(),
        error: (Object e, StackTrace st) =>
            _ErrorShell(onRetry: () => ref.invalidate(taskProvider)),
      );
    }
    return _TimerBody(timer: timer);
  }
}

class _TimerBody extends ConsumerWidget {
  const _TimerBody({required this.timer});

  final ActiveTimer? timer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ActiveTimer? current = timer;
    if (current == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Timer')),
        body: const EmptyState(
          icon: Icons.timer_outlined,
          title: 'No active timer',
          subtitle:
              'Start a timer from any task or subtask to begin a focus session.',
        ),
      );
    }
    final AsyncValue<TaskItem?> task = ref.watch(
      taskProvider(current.taskId),
    );
    return task.when(
      data: (TaskItem? t) => Scaffold(
        appBar: AppBar(title: const Text('Timer')),
        body: RunningTimer(timer: current, task: t),
      ),
      loading: () => const _LoadingShell(),
      error: (Object e, StackTrace st) =>
          _ErrorShell(onRetry: () => ref.invalidate(taskProvider)),
    );
  }
}

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Timer')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorShell extends StatelessWidget {
  const _ErrorShell({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Timer')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Could not load the timer task.',
                style: context.text.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.x4),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _FallbackShell extends StatelessWidget {
  const _FallbackShell({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
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
                title: title,
                subtitle: subtitle,
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
}
