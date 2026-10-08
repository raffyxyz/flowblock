import 'package:drift/native.dart';
import 'package:flowblock/data/db/database.dart' hide Subtask;
import 'package:flowblock/data/repositories/drift_task_repository.dart';
import 'package:flowblock/domain/models/task_item.dart';
import 'package:flowblock/domain/validation_exception.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gap-fillers for Step 4.1: completedAt retention, parent recompute via
/// update, stronger atomicity, bare toggle, and per-limit validation.
void main() {
  late AppDatabase db;
  late DriftTaskRepository repo;
  late DateTime now;
  late int idCounter;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 3, 4, 12);
    idCounter = 0;
    repo = DriftTaskRepository(
      db: db,
      clock: () => now,
      newId: () => 'id-${idCounter++}',
    );
  });

  tearDown(() async {
    await db.close();
  });

  TaskItem draft(String title, {List<Subtask> subs = const <Subtask>[]}) {
    return TaskItem(
      id: 'draft-ignored',
      title: title,
      date: DateTime(2026, 3, 4),
      subtasks: subs,
    );
  }

  Future<TaskItem> only() async {
    final List<TaskItem> tasks = await repo.watchAll().first;
    expect(tasks, hasLength(1));
    return tasks.single;
  }

  test('renamed subtask keeps id, done, completedAt', () async {
    await repo.addTask(
      draft(
        'Parent',
        subs: const <Subtask>[
          Subtask(id: 'x', title: 'One', isDone: true),
          Subtask(id: 'y', title: 'Two'),
        ],
      ),
    );
    TaskItem task = await only();
    final DateTime? doneAt = task.subtasks
        .firstWhere((Subtask s) => s.isDone)
        .completedAt;
    expect(doneAt, isNotNull);

    final TaskItem edited = task.copyWith(
      subtasks: <Subtask>[
        task.subtasks[0].copyWith(title: 'Renamed'),
        task.subtasks[1].copyWith(title: 'Still Two'),
      ],
    );
    await repo.updateTaskWithSubtasks(edited);
    task = (await repo.getById(task.id))!;
    expect(task.subtasks[0].title, 'Renamed');
    expect(task.subtasks[0].isDone, isTrue);
    expect(task.subtasks[0].completedAt?.toUtc(), doneAt?.toUtc());
    expect(task.subtasks[1].isDone, isFalse);
  });

  test('update adds, deletes, writes sortOrder 0..n-1', () async {
    await repo.addTask(
      draft(
        'Parent',
        subs: const <Subtask>[
          Subtask(id: 'a', title: 'A'),
          Subtask(id: 'b', title: 'B'),
          Subtask(id: 'c', title: 'C'),
        ],
      ),
    );
    TaskItem task = await only();
    final String keep = task.subtasks[1].id;
    final TaskItem edited = task.copyWith(
      subtasks: <Subtask>[
        const Subtask(id: 'new-1', title: 'New 1'),
        task.subtasks[1],
        const Subtask(id: 'new-2', title: 'New 2'),
      ],
    );
    await repo.updateTaskWithSubtasks(edited);
    task = (await repo.getById(task.id))!;
    expect(task.subtasks.map((Subtask s) => s.title), <String>[
      'New 1',
      'B',
      'New 2',
    ]);
    expect(task.subtasks.map((Subtask s) => s.sortOrder), <int>[0, 1, 2]);
    expect(task.subtasks[1].id, keep);
  });

  test('update recomputes parent once (open re-opens done)', () async {
    await repo.addTask(
      draft(
        'Parent',
        subs: const <Subtask>[Subtask(id: 'x', title: 'One', isDone: true)],
      ),
    );
    TaskItem task = await only();
    expect(task.isDone, isTrue);
    final TaskItem edited = task.copyWith(
      subtasks: <Subtask>[
        task.subtasks.single,
        const Subtask(id: 'new-open', title: 'Two'),
      ],
    );
    await repo.updateTaskWithSubtasks(edited);
    task = (await repo.getById(task.id))!;
    expect(task.subtasks, hasLength(2));
    expect(task.isDone, isFalse);
    expect(task.completedAt, isNull);
  });

  test('update failure leaves old data fully intact', () async {
    await repo.addTask(
      draft(
        'Parent',
        subs: const <Subtask>[
          Subtask(id: 'x', title: 'Keep 1'),
          Subtask(id: 'y', title: 'Keep 2'),
        ],
      ),
    );
    TaskItem before = await only();
    final List<String> titles = <String>[
      for (final Subtask s in before.subtasks) s.title,
    ];
    await expectLater(
      repo.updateTaskWithSubtasks(
        before.copyWith(
          subtasks: const <Subtask>[
            Subtask(id: 'dup', title: 'One'),
            Subtask(id: 'dup', title: 'Two'),
          ],
        ),
      ),
      throwsA(isA<Exception>()),
    );
    before = (await repo.getById(before.id))!;
    expect(before.subtasks.map((Subtask s) => s.title), titles);
    expect(before.title, 'Parent');
  });

  test('toggleTaskDone flips bare task', () async {
    await repo.addTask(draft('Solo'));
    TaskItem task = await only();
    expect(task.isDone, isFalse);
    await repo.toggleTaskDone(task.id);
    task = (await repo.getById(task.id))!;
    expect(task.isDone, isTrue);
    expect(task.completedAt?.toUtc(), now);
    await repo.toggleTaskDone(task.id);
    task = (await repo.getById(task.id))!;
    expect(task.isDone, isFalse);
    expect(task.completedAt, isNull);
  });

  test('each validation limit rejects and persists nothing', () async {
    Future<void> rejects(TaskItem bad) async {
      await expectLater(repo.addTask(bad), throwsA(isA<ValidationException>()));
    }

    await rejects(draft('   '));
    await rejects(draft('A' * 121));
    await rejects(
      TaskItem(
        id: 'x',
        title: 'Valid',
        notes: 'N' * 2001,
        date: DateTime(2026, 1, 1),
      ),
    );
    await rejects(
      TaskItem(
        id: 'x',
        title: 'Valid',
        durationMinutes: 0,
        date: DateTime(2026, 1, 1),
      ),
    );
    await rejects(
      TaskItem(
        id: 'x',
        title: 'Valid',
        durationMinutes: 601,
        date: DateTime(2026, 1, 1),
      ),
    );
    await rejects(
      draft(
        'Too Many',
        subs: <Subtask>[
          for (int i = 0; i < 51; i++) Subtask(id: 's$i', title: 'S$i'),
        ],
      ),
    );
    expect(await repo.watchAll().first, isEmpty);
  });
}
