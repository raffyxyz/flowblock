import 'package:drift/native.dart';
import 'package:flowblock/data/db/database.dart' hide Subtask;
import 'package:flowblock/data/repositories/drift_task_repository.dart';
import 'package:flowblock/domain/models/task_item.dart';
import 'package:flowblock/domain/validation_exception.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository business-rule tests (Step 3): parent auto-complete/re-open,
/// timestamps, sort orders, and atomicity. Uses an in-memory database with
/// a fake clock and fake ids so results are deterministic.
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

  test('add a task with subtasks assigns sortOrder correctly', () async {
    await repo.addTask(
      draft(
        'Parent',
        subs: const <Subtask>[
          Subtask(id: 'x', title: 'One'),
          Subtask(id: 'y', title: 'Two'),
        ],
      ),
    );
    await repo.addTask(draft('Second'));

    final List<TaskItem> tasks = await repo.watchAll().first;
    expect(tasks.map((TaskItem t) => t.title), <String>[
      'Parent',
      'Second',
    ]);
    expect(tasks.map((TaskItem t) => t.sortOrder), <int>[0, 1]);
    expect(
      tasks.first.subtasks.map((Subtask s) => s.sortOrder),
      <int>[0, 1],
    );
    // Repo mints fresh ids; draft ids are ignored.
    expect(tasks.first.id, isNot('draft-ignored'));
  });

  test('checking the last open subtask completes the parent', () async {
    await repo.addTask(
      draft(
        'Parent',
        subs: const <Subtask>[
          Subtask(id: 'x', title: 'One'),
          Subtask(id: 'y', title: 'Two'),
        ],
      ),
    );
    TaskItem task = await only();
    final String first = task.subtasks[0].id;
    final String second = task.subtasks[1].id;

    await repo.setSubtaskDone(task.id, first, true);
    task = (await repo.getById(task.id))!;
    expect(task.isDone, isFalse);

    await repo.setSubtaskDone(task.id, second, true);
    task = (await repo.getById(task.id))!;
    expect(task.isDone, isTrue);
    expect(task.completedAt?.toUtc(), now);
  });

  test('unchecking a subtask re-opens the parent', () async {
    await repo.addTask(
      draft(
        'Parent',
        subs: const <Subtask>[
          Subtask(id: 'x', title: 'One', isDone: true),
          Subtask(id: 'y', title: 'Two', isDone: true),
        ],
      ),
    );
    TaskItem task = await only();
    expect(task.isDone, isTrue);

    await repo.setSubtaskDone(task.id, task.subtasks[0].id, false);
    task = (await repo.getById(task.id))!;
    expect(task.isDone, isFalse);
    expect(task.completedAt, isNull);
    expect(task.doneSubtasks, 1);
  });

  test('adding an open subtask to a done parent re-opens it', () async {
    await repo.addTask(
      draft(
        'Parent',
        subs: const <Subtask>[Subtask(id: 'x', title: 'One', isDone: true)],
      ),
    );
    TaskItem task = await only();
    expect(task.isDone, isTrue);

    await repo.addSubtask(task.id, title: 'Two');
    task = (await repo.getById(task.id))!;
    expect(task.hasSubtasks, isTrue);
    expect(task.canRunOwnTimer, isFalse);
    expect(task.isDone, isFalse);
  });

  test('deleting the last open subtask completes the parent', () async {
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
    await repo.deleteSubtask(task.id, task.subtasks[1].id);
    task = (await repo.getById(task.id))!;
    expect(task.subtasks, hasLength(1));
    expect(task.isDone, isTrue);
  });

  test('deleting all subtasks leaves the parent state unchanged', () async {
    await repo.addTask(
      draft(
        'Parent',
        subs: const <Subtask>[Subtask(id: 'x', title: 'One')],
      ),
    );
    TaskItem task = await only();
    expect(task.isDone, isFalse);
    await repo.deleteSubtask(task.id, task.subtasks.single.id);
    task = (await repo.getById(task.id))!;
    expect(task.subtasks, isEmpty);
    expect(task.isDone, isFalse);
    expect(task.canRunOwnTimer, isTrue);
  });

  test('deleting a task removes its subtasks', () async {
    await repo.addTask(
      draft(
        'Parent',
        subs: const <Subtask>[Subtask(id: 'x', title: 'One')],
      ),
    );
    final TaskItem task = await only();
    await repo.deleteTask(task.id);
    expect(await repo.watchAll().first, isEmpty);
    expect(await repo.getById(task.id), isNull);
  });

  test('toggling a parent flips all of its subtasks', () async {
    await repo.addTask(
      draft(
        'Parent',
        subs: const <Subtask>[Subtask(id: 'x', title: 'One')],
      ),
    );
    TaskItem task = await only();
    await repo.setTaskDone(task.id, true);
    task = (await repo.getById(task.id))!;
    expect(task.doneSubtasks, 1);
    expect(task.completedAt?.toUtc(), now);
    await repo.setTaskDone(task.id, false);
    task = (await repo.getById(task.id))!;
    expect(task.doneSubtasks, 0);
    expect(task.completedAt, isNull);
  });

  test('reorderSubtasks persists the new order', () async {
    await repo.addTask(
      draft(
        'Parent',
        subs: const <Subtask>[
          Subtask(id: 'x', title: 'One'),
          Subtask(id: 'y', title: 'Two'),
          Subtask(id: 'z', title: 'Three'),
        ],
      ),
    );
    TaskItem task = await only();
    final List<String> ids = <String>[
      task.subtasks[2].id,
      task.subtasks[0].id,
      task.subtasks[1].id,
    ];
    await repo.reorderSubtasks(task.id, ids);
    task = (await repo.getById(task.id))!;
    expect(
      task.subtasks.map((Subtask s) => s.id).toList(),
      ids,
    );
  });

  test('reorderTasks persists the new order', () async {
    await repo.addTask(draft('A'));
    await repo.addTask(draft('B'));
    List<TaskItem> tasks = await repo.watchAll().first;
    await repo.reorderTasks(<String>[tasks[1].id, tasks[0].id]);
    tasks = await repo.watchAll().first;
    expect(
      tasks.map((TaskItem t) => t.title),
      <String>['B', 'A'],
    );
  });

  test('updatedAt changes on write but createdAt does not', () async {
    await repo.addTask(draft('A'));
    TaskItem task = await only();
    final DateTime created = task.createdAt!;
    expect(task.updatedAt, created);

    now = now.add(const Duration(minutes: 5));
    await repo.setTaskDone(task.id, true);
    task = (await repo.getById(task.id))!;
    expect(task.createdAt?.toUtc(), created.toUtc());
    expect(task.updatedAt?.toUtc(), now);
  });

  test('failed operations persist nothing (atomicity)', () async {
    await repo.addTask(draft('A'));
    TaskItem task = await only();
    // Two incoming subtasks sharing one id: the second insert violates
    // the primary key, so the whole update must roll back.
    await expectLater(
      repo.updateTask(
        task.copyWith(
          subtasks: const <Subtask>[
            Subtask(id: 'dup', title: 'One'),
            Subtask(id: 'dup', title: 'Two'),
          ],
        ),
      ),
      throwsA(isA<Exception>()),
    );
    task = (await repo.getById(task.id))!;
    expect(task.subtasks, isEmpty);
  });

  test('hasSubtasks and canRunOwnTimer reflect subtask presence', () {
    final TaskItem bare = TaskItem(
      id: 'bare',
      title: 'Bare',
      date: DateTime(2026, 1, 1),
      durationMinutes: 25,
    );
    expect(bare.hasSubtasks, isFalse);
    expect(bare.canRunOwnTimer, isTrue);

    final TaskItem parent = TaskItem(
      id: 'parent',
      title: 'Parent',
      date: DateTime(2026, 1, 1),
      durationMinutes: 25,
      subtasks: <Subtask>[Subtask(id: 's1', title: 'One')],
    );
    expect(parent.hasSubtasks, isTrue);
    expect(parent.canRunOwnTimer, isFalse);
  });

  test('rolledUpEstimate sums known subtask durations only', () {
    final TaskItem some = TaskItem(
      id: 'some',
      title: 'Some',
      date: DateTime(2026, 1, 1),
      subtasks: <Subtask>[
        Subtask(id: 's1', title: 'One', durationMinutes: 10),
        Subtask(id: 's2', title: 'Two'),
        Subtask(id: 's3', title: 'Three', durationMinutes: 15),
      ],
    );
    expect(some.rolledUpEstimate, 25);

    final TaskItem none = TaskItem(
      id: 'none',
      title: 'None',
      date: DateTime(2026, 1, 1),
      subtasks: <Subtask>[Subtask(id: 's1', title: 'One')],
    );
    expect(none.rolledUpEstimate, isNull);
  });

  test('displayEstimate prefers the rolled-up sum when subtasks exist', () {
    final TaskItem bare = TaskItem(
      id: 'bare',
      title: 'Bare',
      date: DateTime(2026, 1, 1),
      durationMinutes: 25,
    );
    expect(bare.displayEstimate, 25);

    final TaskItem parent = TaskItem(
      id: 'parent',
      title: 'Parent',
      date: DateTime(2026, 1, 1),
      durationMinutes: 50,
      subtasks: <Subtask>[
        Subtask(id: 's1', title: 'One', durationMinutes: 10),
        Subtask(id: 's2', title: 'Two'),
      ],
    );
    expect(parent.displayEstimate, 10);
  });

  test('updateTaskWithSubtasks keeps ids and done state when title changes', () async {
    await repo.addTask(
      draft(
        'Parent',
        subs: const <Subtask>[
          Subtask(id: 's1', title: 'Old Title 1', isDone: true),
          Subtask(id: 's2', title: 'Old Title 2', isDone: false),
        ],
      ),
    );
    TaskItem task = await only();
    final String s1Id = task.subtasks[0].id;
    final String s2Id = task.subtasks[1].id;

    final TaskItem updated = task.copyWith(
      subtasks: <Subtask>[
        task.subtasks[0].copyWith(title: 'New Title 1'),
        task.subtasks[1].copyWith(title: 'New Title 2'),
      ],
    );

    await repo.updateTaskWithSubtasks(updated);
    task = (await repo.getById(task.id))!;
    expect(task.subtasks[0].id, s1Id);
    expect(task.subtasks[0].title, 'New Title 1');
    expect(task.subtasks[0].isDone, isTrue);

    expect(task.subtasks[1].id, s2Id);
    expect(task.subtasks[1].title, 'New Title 2');
    expect(task.subtasks[1].isDone, isFalse);
  });

  test('updateTaskWithSubtasks adds and deletes subtasks and reorders', () async {
    await repo.addTask(
      draft(
        'Parent',
        subs: const <Subtask>[
          Subtask(id: 's1', title: 'Sub 1'),
          Subtask(id: 's2', title: 'Sub 2'),
        ],
      ),
    );
    TaskItem task = await only();
    final String s1Id = task.subtasks[0].id;

    final TaskItem edited = task.copyWith(
      subtasks: <Subtask>[
        const Subtask(id: 'temp-new', title: 'Sub 3'),
        task.subtasks[0],
      ],
    );

    await repo.updateTaskWithSubtasks(edited);
    task = (await repo.getById(task.id))!;
    expect(task.subtasks, hasLength(2));
    expect(task.subtasks[0].title, 'Sub 3');
    expect(task.subtasks[0].sortOrder, 0);
    expect(task.subtasks[1].id, s1Id);
    expect(task.subtasks[1].sortOrder, 1);
  });

  test('bulk toggle via parent checkbox toggleTaskDone', () async {
    await repo.addTask(
      draft(
        'Parent',
        subs: const <Subtask>[
          Subtask(id: 's1', title: 'Sub 1', isDone: true),
          Subtask(id: 's2', title: 'Sub 2', isDone: false),
        ],
      ),
    );
    TaskItem task = await only();
    expect(task.isDone, isFalse);

    // Not all done -> mark all done
    await repo.toggleTaskDone(task.id);
    task = (await repo.getById(task.id))!;
    expect(task.isDone, isTrue);
    expect(task.subtasks.every((Subtask s) => s.isDone), isTrue);

    // All done -> mark all open
    await repo.toggleTaskDone(task.id);
    task = (await repo.getById(task.id))!;
    expect(task.isDone, isFalse);
    expect(task.subtasks.every((Subtask s) => !s.isDone), isTrue);
  });

  test('validation limits reject invalid input and persist nothing', () async {
    await expectLater(
      repo.addTask(draft('   ')),
      throwsA(isA<ValidationException>()),
    );

    await expectLater(
      repo.addTask(draft('A' * 121)),
      throwsA(isA<ValidationException>()),
    );

    await expectLater(
      repo.addTask(
        TaskItem(
          id: 'test',
          title: 'Valid',
          notes: 'N' * 2001,
          date: DateTime(2026, 1, 1),
        ),
      ),
      throwsA(isA<ValidationException>()),
    );

    await expectLater(
      repo.addTask(
        TaskItem(
          id: 'test',
          title: 'Valid',
          durationMinutes: 1000,
          date: DateTime(2026, 1, 1),
        ),
      ),
      throwsA(isA<ValidationException>()),
    );

    final List<Subtask> tooMany = <Subtask>[
      for (int i = 0; i < 51; i++) Subtask(id: 's$i', title: 'Sub $i'),
    ];
    await expectLater(
      repo.addTask(draft('Too Many', subs: tooMany)),
      throwsA(isA<ValidationException>()),
    );

    final List<TaskItem> tasks = await repo.watchAll().first;
    expect(tasks, isEmpty);
  });
}
