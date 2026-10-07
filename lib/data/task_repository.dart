import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/task_item.dart';

int _idCounter = 0;

/// Unique ids for tasks/subtasks created during the session.
String newId() {
  return '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
}

/// Abstract task store. Widgets talk only to the providers below, so a real
/// Drift database can replace [InMemoryTaskRepository] later without touching
/// any widget.
abstract class TaskRepository {
  List<TaskItem> seedTasks();
}

/// In-memory seed data for Step 1 (UI only). Dates are relative to today so
/// the Today and Upcoming screens always have something to show.
class InMemoryTaskRepository implements TaskRepository {
  @override
  List<TaskItem> seedTasks() {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    DateTime at(DateTime day, int hour, [int minute = 0]) {
      return DateTime(day.year, day.month, day.day, hour, minute);
    }

    return <TaskItem>[
      TaskItem(
        id: 'task-focus',
        title: 'Morning focus block',
        notes: 'Single-tasking only. Phone stays in the other room.',
        date: today,
        time: at(today, 9),
        durationMinutes: 50,
        subtasks: const <Subtask>[
          Subtask(
              id: 'focus-1',
              title: 'Clear inbox',
              durationMinutes: 10,
              isDone: true),
          Subtask(
              id: 'focus-2',
              title: 'Draft outline',
              durationMinutes: 15,
              isDone: true),
          Subtask(
              id: 'focus-3', title: 'Deep work session', durationMinutes: 25),
          Subtask(id: 'focus-4', title: 'Review notes', durationMinutes: 10),
        ],
      ),
      TaskItem(
        id: 'task-design',
        title: 'Design review prep',
        notes: 'Bring two options and one clear recommendation.',
        date: today,
        time: at(today, 11, 30),
        recurrence: RecurrenceType.daily,
        durationMinutes: 25,
        subtasks: const <Subtask>[
          Subtask(
              id: 'design-1', title: 'Update mockups', durationMinutes: 15),
          Subtask(
              id: 'design-2',
              title: 'Write talking points',
              durationMinutes: 10),
        ],
      ),
      TaskItem(
        id: 'task-update',
        title: 'Write project update',
        date: today,
        time: at(today, 14),
        durationMinutes: 15,
        subtasks: const <Subtask>[
          Subtask(
              id: 'update-1',
              title: 'Collect highlights',
              durationMinutes: 5,
              isDone: true),
          Subtask(id: 'update-2', title: 'Draft summary', durationMinutes: 10),
        ],
      ),
      TaskItem(
        id: 'task-gym',
        title: 'Gym session',
        date: today,
        time: at(today, 18),
        recurrence: RecurrenceType.daily,
        durationMinutes: 30,
        isDone: true,
        subtasks: const <Subtask>[
          Subtask(id: 'gym-1', title: 'Warm up', isDone: true),
          Subtask(id: 'gym-2', title: 'Strength set', isDone: true),
        ],
      ),
      TaskItem(
        id: 'task-read',
        title: 'Read 20 pages',
        date: today,
        durationMinutes: 20,
        isDone: true,
      ),
      TaskItem(
        id: 'task-planning',
        title: 'Weekly planning',
        notes: 'Review last week, pick three priorities for next week.',
        date: today.add(const Duration(days: 1)),
        time: at(today.add(const Duration(days: 1)), 10),
        recurrence: RecurrenceType.weekly,
        weekdays: const <int>[1],
        durationMinutes: 25,
        subtasks: const <Subtask>[
          Subtask(id: 'plan-1', title: 'Review last week'),
          Subtask(id: 'plan-2', title: 'Pick three priorities'),
          Subtask(id: 'plan-3', title: 'Time-block calendar'),
        ],
      ),
      TaskItem(
        id: 'task-demo',
        title: 'Prepare sprint demo',
        date: today.add(const Duration(days: 2)),
        time: at(today.add(const Duration(days: 2)), 15),
        durationMinutes: 50,
        subtasks: const <Subtask>[
          Subtask(id: 'demo-1', title: 'Record walkthrough', durationMinutes: 25),
          Subtask(id: 'demo-2', title: 'Trim to five minutes', durationMinutes: 15),
        ],
      ),
      TaskItem(
        id: 'task-backup',
        title: 'Back up laptop files',
        date: today.add(const Duration(days: 4)),
        recurrence: RecurrenceType.monthly,
        durationMinutes: 15,
      ),
    ];
  }
}

final taskRepositoryProvider =
    Provider<TaskRepository>((Ref ref) => InMemoryTaskRepository());

/// In-memory task list. Checking the last open subtask completes the parent;
/// unchecking any subtask re-opens it.
class TaskListNotifier extends Notifier<List<TaskItem>> {
  @override
  List<TaskItem> build() {
    return ref.watch(taskRepositoryProvider).seedTasks();
  }

  void _update(String id, TaskItem Function(TaskItem task) transform) {
    state = <TaskItem>[
      for (final TaskItem task in state)
        if (task.id == id) transform(task) else task,
    ];
  }

  void toggleTask(String id) {
    _update(id, (TaskItem task) {
      final bool done = !task.isDone;
      return task.copyWith(
        isDone: done,
        subtasks: <Subtask>[
          for (final Subtask s in task.subtasks) s.copyWith(isDone: done),
        ],
      );
    });
  }

  void toggleSubtask(String taskId, String subtaskId) {
    _update(taskId, (TaskItem task) {
      final List<Subtask> subtasks = <Subtask>[
        for (final Subtask s in task.subtasks)
          if (s.id == subtaskId) s.copyWith(isDone: !s.isDone) else s,
      ];
      final bool allDone =
          subtasks.isNotEmpty && subtasks.every((Subtask s) => s.isDone);
      return task.copyWith(subtasks: subtasks, isDone: allDone);
    });
  }

  void addTask(TaskItem task) {
    state = <TaskItem>[...state, task];
  }

  void updateTask(TaskItem task) {
    _update(task.id, (_) => task);
  }

  void deleteTask(String id) {
    state = state.where((TaskItem task) => task.id != id).toList();
  }

  void addSubtask(String taskId, Subtask subtask) {
    _update(taskId, (TaskItem task) {
      return task.copyWith(
        subtasks: <Subtask>[...task.subtasks, subtask],
        isDone: false,
      );
    });
  }

  void removeSubtask(String taskId, String subtaskId) {
    _update(taskId, (TaskItem task) {
      final List<Subtask> subtasks = task.subtasks
          .where((Subtask s) => s.id != subtaskId)
          .toList();
      final bool allDone =
          subtasks.isNotEmpty && subtasks.every((Subtask s) => s.isDone);
      return task.copyWith(
        subtasks: subtasks,
        isDone: subtasks.isEmpty ? task.isDone : allDone,
      );
    });
  }

  void moveSubtask(String taskId, int oldIndex, int newIndex) {
    _update(taskId, (TaskItem task) {
      final List<Subtask> subtasks = List<Subtask>.from(task.subtasks);
      final Subtask moved = subtasks.removeAt(oldIndex);
      subtasks.insert(newIndex, moved);
      return task.copyWith(subtasks: subtasks);
    });
  }
}

final taskListProvider =
    NotifierProvider<TaskListNotifier, List<TaskItem>>(TaskListNotifier.new);

/// Tasks scheduled for the current day.
final todayTasksProvider = Provider<List<TaskItem>>((Ref ref) {
  final DateTime now = DateTime.now();
  return tasksForDay(ref.watch(taskListProvider), now);
});

/// Tasks scheduled on [day].
List<TaskItem> tasksForDay(List<TaskItem> tasks, DateTime day) {
  return tasks.where((TaskItem task) => sameDay(task.date, day)).toList();
}

/// Nullable lookup by id (avoids adding a collection dependency).
TaskItem? findTask(List<TaskItem> tasks, String id) {
  for (final TaskItem task in tasks) {
    if (task.id == id) {
      return task;
    }
  }
  return null;
}
