import '../db/database.dart' hide Subtask;
import '../db/mappers.dart';
import '../../domain/models/task_item.dart';

/// Debug seed content (Step 3).
///
/// The same 8 realistic tasks the in-memory mock used since Step 1, with
/// dates relative to today so Today/Upcoming always have something to show
/// on a fresh debug install. Pure data: no database access here.
List<TaskItem> buildSeedTasks() {
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

/// Inserts the seed tasks with index-based sort orders. Called once from
/// [AppDatabase]'s `onCreate`, never from widgets or tests.
Future<void> seedDatabase(AppDatabase db) async {
  final List<TaskItem> seeds = buildSeedTasks();
  for (int i = 0; i < seeds.length; i++) {
    final TaskItem task = seeds[i];
    final List<Subtask> ordered = <Subtask>[
      for (int j = 0; j < task.subtasks.length; j++)
        task.subtasks[j].copyWith(sortOrder: j),
    ];
    await db.tasksDao.insertTaskWithSubtasks(
      taskCompanionFromDomain(task.copyWith(sortOrder: i, subtasks: ordered)),
      <SubtasksCompanion>[
        for (final Subtask s in ordered)
          subtaskCompanionFromDomain(s, task.id),
      ],
    );
  }
}
