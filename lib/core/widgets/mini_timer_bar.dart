import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../features/timer/timer_controller.dart';

/// Slim bar pinned above the bottom nav while a focus session runs.
/// Tapping it returns to the full timer screen.
class MiniTimerBar extends ConsumerWidget {
  const MiniTimerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ActiveTimer? timer = ref.watch(timerControllerProvider);
    if (timer == null) {
      return const SizedBox.shrink();
    }
    final FlowColors colors = context.colors;
    final TimerController controller =
        ref.read(timerControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.x4,
        AppSpace.x2,
        AppSpace.x4,
        0,
      ),
      child: GestureDetector(
        onTap: () {
          context.push(
            Uri(
              path: '/timer',
              queryParameters: <String, String>{
                'taskId': timer.taskId,
                if (timer.subtaskId case final String id) 'subtaskId': id,
              },
            ).toString(),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.x2,
            vertical: AppSpace.x1,
          ),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colors.line),
            boxShadow: AppShadow.soft(context),
          ),
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: timer.isRunning ? 'Pause timer' : 'Resume timer',
                onPressed: controller.toggle,
                icon: Icon(
                  timer.isRunning ? Icons.pause : Icons.play_arrow,
                  color: colors.accent,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      timer.title,
                      style: context.text.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      formatCountdown(timer.remainingSeconds),
                      style: context.text.labelMedium
                          ?.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Stop timer',
                onPressed: controller.stop,
                icon: Icon(Icons.close, color: colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
