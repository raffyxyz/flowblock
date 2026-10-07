import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/task_card.dart';
import '../../../data/task_repository.dart';
import '../../../domain/models/task_item.dart';
import '../../../domain/task_filters.dart';

/// Week strip plus the tasks scheduled on the selected day.
class UpcomingScreen extends ConsumerStatefulWidget {
  const UpcomingScreen({super.key});

  @override
  ConsumerState<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends ConsumerState<UpcomingScreen> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    // Today plus the next 13 days.
    final List<DateTime> window = <DateTime>[
      for (int i = 0; i < 14; i++) today.add(Duration(days: i)),
    ];
    final AsyncValue<List<TaskItem>> all = ref.watch(taskListProvider);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpace.contentMax),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.x5,
                AppSpace.x4,
                AppSpace.x5,
                AppSpace.x2,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Upcoming', style: context.text.headlineMedium),
                    const SizedBox(height: AppSpace.x1),
                    Text(
                      'Plan the days ahead.',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.x5,
                  vertical: AppSpace.x1,
                ),
                itemCount: window.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(width: AppSpace.x2),
                itemBuilder: (BuildContext context, int index) {
                  return _DayChip(
                    day: window[index],
                    selected: sameDay(window[index], _selected),
                    onTap: () => setState(() => _selected = window[index]),
                  );
                },
              ),
            ),
            Expanded(
              child: all.when(
                data: (List<TaskItem> tasks) =>
                    _DayList(tasks: tasksForDate(tasks, _selected)),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (Object e, StackTrace st) => Center(
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
                        const SizedBox(height: AppSpace.x4),
                        FilledButton(
                          onPressed: () =>
                              ref.invalidate(taskListProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList({required this.tasks});

  final List<TaskItem> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const EmptyState(
        icon: Icons.event_available_outlined,
        title: 'Nothing on this day',
        subtitle:
            'No tasks scheduled. Pick another day or add one with + on Today.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.x5,
        AppSpace.x3,
        AppSpace.x5,
        AppSpace.x6,
      ),
      children: <Widget>[
        for (final TaskItem task in tasks)
          Padding(
            padding: const EdgeInsets.only(
              bottom: AppSpace.x3,
            ),
            child: TaskCard(task: task),
          ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  static const List<String> _weekdays = <String>[
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S'
  ];

  @override
  Widget build(BuildContext context) {
    final FlowColors colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${day.day} ${day.month}: ${selected ? 'selected' : 'not selected'}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _weekdays[day.weekday - 1],
                style: context.text.labelMedium
                    ?.copyWith(color: colors.muted),
              ),
              const SizedBox(height: AppSpace.x1),
              AnimatedContainer(
                duration: AppMotion.short,
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? colors.accent : Colors.transparent,
                  border: Border.all(
                    color: selected ? colors.accent : colors.line,
                  ),
                ),
                child: Text(
                  '${day.day}',
                  style: context.text.titleMedium?.copyWith(
                    color: selected ? colors.onAccent : colors.heading,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
