import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/duration_chip.dart';
import '../../../core/widgets/info_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/subtask_tile.dart';
import '../../../data/task_actions.dart';
import '../../../domain/models/task_item.dart';
import '../timer/timer_controller.dart';
import 'task_form_sheet.dart';

/// Detail content for one task (below the loading/error/not-found shell).
class TaskDetailBody extends ConsumerWidget {
  const TaskDetailBody({
    super.key,
    required this.task,
    required this.newSubtask,
    required this.onAddSubtask,
    required this.onReorder,
    required this.onDelete,
    required this.onRun,
  });

  final TaskItem task;
  final TextEditingController newSubtask;
  final VoidCallback onAddSubtask;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onDelete;
  final Future<void> Function(Future<void> Function() op) onRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TaskActions actions = ref.read(taskActionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: <Widget>[
          PopupMenuButton<String>(
            tooltip: 'Task options',
            onSelected: (String value) {
              if (value == 'edit') {
                showTaskFormSheet(context, existing: task);
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.edit_outlined),
                    SizedBox(width: AppSpace.x3),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.delete_outline),
                    SizedBox(width: AppSpace.x3),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Align(
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
              Text(task.title, style: context.text.headlineMedium),
              if (task.notes.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpace.x2),
                Text(task.notes, style: context.text.bodyLarge),
              ],
              const SizedBox(height: AppSpace.x3),
              Wrap(
                spacing: AppSpace.x2,
                runSpacing: AppSpace.x2,
                children: <Widget>[
                  InfoChip(
                    icon: Icons.calendar_month_outlined,
                    label: formatShortDay(task.date),
                  ),
                  if (task.time != null)
                    InfoChip(
                      icon: Icons.schedule,
                      label: formatClock(task.time!),
                    ),
                  if (task.recurrence != RecurrenceType.once)
                    InfoChip(
                      icon: Icons.repeat,
                      label: recurrenceLabel(task),
                    ),
                  if (task.displayEstimate != null)
                    DurationChip(minutes: task.displayEstimate!),
                ],
              ),
              const SizedBox(height: AppSpace.x5),
              SectionHeader(
                title: 'Subtasks',
                count: task.hasSubtasks ? task.doneSubtasks : null,
              ),
              const SizedBox(height: AppSpace.x1),
              if (!task.hasSubtasks)
                Text(
                  'Break it down into small steps.',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.muted,
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: task.subtasks.length,
                  onReorderItem: onReorder,
                  itemBuilder: (BuildContext context, int index) {
                    final Subtask subtask = task.subtasks[index];
                    return SubtaskTile(
                      key: ValueKey<String>(subtask.id),
                      subtask: subtask,
                      dragIndex: index,
                      onToggled: (_) => onRun(
                        () => actions.toggleSubtask(task, subtask.id),
                      ),
                      onPlay: () {
                        ref
                            .read(timerControllerProvider.notifier)
                            .start(task: task, subtask: subtask);
                        context.push(
                          Uri(
                            path: '/timer',
                            queryParameters: <String, String>{
                              'taskId': task.id,
                              'subtaskId': subtask.id,
                            },
                          ).toString(),
                        );
                      },
                    );
                  },
                ),
              const SizedBox(height: AppSpace.x2),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: newSubtask,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => onAddSubtask(),
                      decoration: const InputDecoration(
                        hintText: 'Add subtask',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.x2),
                  IconButton.filled(
                    tooltip: 'Add subtask',
                    onPressed: onAddSubtask,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.x6),
              PrimaryButton(
                label: 'Start focus session',
                icon: Icons.play_arrow,
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
              if (!task.canRunOwnTimer) ...<Widget>[
                const SizedBox(height: AppSpace.x2),
                Text(
                  'Timers are set on subtasks',
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
