import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/duration_chip.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/info_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/subtask_tile.dart';
import '../../../data/task_repository.dart';
import '../../../domain/models/task_item.dart';
import '../timer/timer_controller.dart';
import 'task_form_sheet.dart';
import 'task_timer_guard.dart';

/// Full detail page for one task: meta info, reorderable subtasks,
/// inline add, and an overflow menu (Edit / Delete, mock actions).
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final TextEditingController _newSubtask = TextEditingController();

  @override
  void dispose() {
    _newSubtask.dispose();
    super.dispose();
  }

  Future<void> _addSubtask(TaskItem task) async {
    final String title = _newSubtask.text.trim();
    if (title.isEmpty) {
      return;
    }
    if (task.canRunOwnTimer) {
      final bool proceed = await confirmStopTaskTimer(context, ref, task);
      if (!proceed || !mounted) {
        return;
      }
    }
    ref.read(taskListProvider.notifier).addSubtask(
          task.id,
          Subtask(id: newId(), title: title),
        );
    _newSubtask.clear();
  }

  Future<void> _confirmDelete(TaskItem task) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete task?'),
          content: Text(
            '“${task.title}” and its subtasks will be removed. '
            'This is a mock action for now.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    ref.read(taskListProvider.notifier).deleteTask(task.id);
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final TaskItem? task =
        findTask(ref.watch(taskListProvider), widget.taskId);
    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off_outlined,
          title: 'Task not found',
          subtitle: 'It may have been deleted. Go back and pick another task.',
        ),
      );
    }
    final TaskListNotifier tasks = ref.read(taskListProvider.notifier);
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
                _confirmDelete(task);
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
                  onReorderItem: (int oldIndex, int newIndex) {
                    tasks.moveSubtask(task.id, oldIndex, newIndex);
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final Subtask subtask = task.subtasks[index];
                    return SubtaskTile(
                      key: ValueKey<String>(subtask.id),
                      subtask: subtask,
                      dragIndex: index,
                      onToggled: (_) => tasks.toggleSubtask(
                        task.id,
                        subtask.id,
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
                      controller: _newSubtask,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addSubtask(task),
                      decoration: const InputDecoration(
                        hintText: 'Add subtask',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.x2),
                  IconButton.filled(
                    tooltip: 'Add subtask',
                    onPressed: () => _addSubtask(task),
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
