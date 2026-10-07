import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/progress_summary_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/task_card.dart';
import '../../../data/task_repository.dart';
import '../../../domain/models/task_item.dart';

/// Extra bottom padding so list content clears the floating action button.
const double _fabClearance = 88;

/// Today's tasks with a progress summary and a collapsible completed section.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  bool _showCompleted = true;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<TaskItem>> tasks = ref.watch(todayTasksProvider);
    return tasks.when(
      data: (List<TaskItem> all) => _TodayList(
        tasks: all,
        showCompleted: _showCompleted,
        onToggleCompleted: () =>
            setState(() => _showCompleted = !_showCompleted),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace st) => _TasksError(
        onRetry: () => ref.invalidate(taskListProvider),
      ),
    );
  }
}

class _TasksError extends StatelessWidget {
  const _TasksError({required this.onRetry});

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
              'Could not load your tasks.',
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.x2),
            Text(
              'Check your storage and try again.',
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.muted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.x4),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayList extends StatelessWidget {
  const _TodayList({
    required this.tasks,
    required this.showCompleted,
    required this.onToggleCompleted,
  });

  final List<TaskItem> tasks;
  final bool showCompleted;
  final VoidCallback onToggleCompleted;

  @override
  Widget build(BuildContext context) {
    final List<TaskItem> open =
        tasks.where((TaskItem t) => !t.isDone).toList();
    final List<TaskItem> done =
        tasks.where((TaskItem t) => t.isDone).toList();
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: AppSpace.contentMax),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.x5,
            AppSpace.x4,
            AppSpace.x5,
            _fabClearance,
          ),
          children: <Widget>[
            Text('Today', style: context.text.headlineMedium),
            const SizedBox(height: AppSpace.x1),
            Text(
              formatScreenDate(DateTime.now()),
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.muted),
            ),
            const SizedBox(height: AppSpace.x4),
            ProgressSummaryCard(done: done.length, total: tasks.length),
            const SizedBox(height: AppSpace.x4),
            if (tasks.isEmpty)
              const EmptyState(
                icon: Icons.spa_outlined,
                title: 'Nothing scheduled',
                subtitle:
                    'Enjoy the calm. Add a task with the + button when you are ready.',
              )
            else ...<Widget>[
              for (final TaskItem task in open)
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: AppSpace.x3),
                  child: TaskCard(task: task),
                ),
              if (done.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpace.x2),
                SectionHeader(
                  title: 'Completed',
                  count: done.length,
                  trailing: IconButton(
                    tooltip:
                        showCompleted ? 'Hide completed' : 'Show completed',
                    onPressed: onToggleCompleted,
                    icon: Icon(
                      showCompleted
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.x2),
                AnimatedSize(
                  duration: AppMotion.medium,
                  curve: Curves.easeOut,
                  child: showCompleted
                      ? Column(
                          children: <Widget>[
                            for (final TaskItem task in done)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpace.x3,
                                ),
                                child: TaskCard(task: task),
                              ),
                          ],
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
