import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/circular_timer_ring.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/subtask_tile.dart';
import '../../../data/task_actions.dart';
import '../../../domain/models/task_item.dart';
import 'timer_controller.dart';

/// Running-timer content (below the loading/error shells).
class RunningTimer extends ConsumerWidget {
  const RunningTimer({super.key, required this.timer, required this.task});

  final ActiveTimer timer;
  final TaskItem? task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TimerController controller =
        ref.read(timerControllerProvider.notifier);
    final TaskItem? current = task;
    final bool hasNext = timerHasNext(timer, current);
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
                  onToggled: (_) async {
                    try {
                      await ref
                          .read(taskActionsProvider)
                          .setSubtaskDone(
                            current.id,
                            subtask.id,
                            !subtask.isDone,
                          );
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not update the subtask.'),
                          ),
                        );
                      }
                    }
                  },
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
