import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/task_actions.dart';
import '../../../data/task_repository.dart';
import '../../../domain/models/task_item.dart';
import 'pending_delete_controller.dart';
import 'task_detail_body.dart';
import 'task_timer_guard.dart';

/// Full detail page for one task: meta info, reorderable subtasks,
/// inline add, and an overflow menu (Edit / Delete).
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

  Future<void> _run(Future<void> Function() op) async {
    try {
      await op();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
          ),
        );
      }
    }
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
    final String saved = title;
    _newSubtask.clear();
    await _run(
      () => ref.read(taskActionsProvider).addSubtask(task.id, title: saved),
    );
  }

  Future<void> _confirmDelete(TaskItem task) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete task?'),
          content: Text('“${task.title}” and its subtasks will be removed.'),
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
    if (mounted) {
      context.pop();
    }
    ref.read(pendingDeleteControllerProvider.notifier).stageTaskDelete(
      context: context,
      ref: ref,
      taskId: task.id,
    );
  }

  void _reorder(TaskItem task, int oldIndex, int newIndex) {
    final List<String> ids = <String>[
      for (final Subtask s in task.subtasks) s.id,
    ];
    final String moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    _run(() => ref.read(taskActionsProvider).reorderSubtasks(task.id, ids));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(pendingDeleteControllerProvider);
    final AsyncValue<TaskItem?> task = ref.watch(taskProvider(widget.taskId));
    return task.when(
      data: (TaskItem? raw) {
        final TaskItem? t = ref
            .read(pendingDeleteControllerProvider.notifier)
            .filterTask(raw);
        if (t == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.search_off_outlined,
              title: 'Task not found',
              subtitle:
                  'It may have been deleted. Go back and pick another task.',
            ),
          );
        }
        return TaskDetailBody(
          task: t,
          newSubtask: _newSubtask,
          onAddSubtask: () => _addSubtask(t),
          onReorder: (int o, int n) => _reorder(t, o, n),
          onDelete: () => _confirmDelete(t),
          onRun: _run,
        );
      },
      loading: () =>
          Scaffold(appBar: AppBar(), body: const _LoadingBody()),
      error: (Object e, StackTrace st) => Scaffold(
        appBar: AppBar(),
        body: _ErrorBody(
          onRetry: () => ref.invalidate(taskProvider(widget.taskId)),
        ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Could not load this task.',
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.x4),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
