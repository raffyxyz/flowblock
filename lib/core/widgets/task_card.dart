import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_checkbox.dart';
import '../../../core/widgets/duration_chip.dart';
import '../../../data/task_repository.dart';
import '../../../domain/models/task_item.dart';
import '../../../features/timer/timer_controller.dart';

/// Card for a single task, shared by the Today and Upcoming screens.
class TaskCard extends ConsumerWidget {
  const TaskCard({super.key, required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FlowColors colors = context.colors;
    final bool done = task.isDone;
    return Opacity(
      opacity: done ? 0.6 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadow.soft(context),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => context.push('/task/${task.id}'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.x4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                AppCheckbox(
                  value: done,
                  semanticLabel: done
                      ? 'Mark ${task.title} as not done'
                      : 'Mark ${task.title} as done',
                  onChanged: (_) => ref
                      .read(taskListProvider.notifier)
                      .toggleTask(task.id),
                ),
                const SizedBox(width: AppSpace.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        task.title,
                        style: context.text.titleMedium?.copyWith(
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: AppSpace.x1),
                      Wrap(
                        spacing: AppSpace.x2,
                        runSpacing: AppSpace.x1,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          if (task.hasSubtasks)
                            Text(
                              '${task.doneSubtasks}/${task.subtasks.length}',
                              style: context.text.labelMedium?.copyWith(
                                color: colors.muted,
                              ),
                            ),
                          if (task.time != null)
                            _Meta(
                              icon: Icons.schedule,
                              label: formatClock(task.time!),
                            ),
                          if (task.recurrence != RecurrenceType.once)
                            _Meta(
                              icon: Icons.repeat,
                              label: recurrenceLabel(task),
                              semanticLabel:
                                  'Repeating task: ${recurrenceLabel(task)}',
                            ),
                          if (task.displayEstimate != null)
                            DurationChip(minutes: task.displayEstimate!),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.x2),
                _PlayButton(
                  enabled: task.canRunOwnTimer,
                  label: task.canRunOwnTimer
                      ? 'Start timer for ${task.title}'
                      : 'Timer is set on subtasks',
                  onPressed: task.canRunOwnTimer
                      ? () {
                          ref
                              .read(timerControllerProvider.notifier)
                              .start(task: task);
                          context.push(
                            Uri(
                              path: '/timer',
                              queryParameters: <String, String>{
                                'taskId': task.id,
                              },
                            ).toString(),
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, this.semanticLabel});

  final IconData icon;
  final String label;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: context.colors.muted),
          const SizedBox(width: AppSpace.x1),
          Text(
            label,
            style: context.text.labelMedium
                ?.copyWith(color: context.colors.muted),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final FlowColors colors = context.colors;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox(
            width: AppSpace.x12,
            height: AppSpace.x12,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accentSoft,
                ),
                child: Icon(Icons.play_arrow, color: colors.accent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
