import 'package:drift/native.dart';
import 'package:flowblock/data/db/daos/tasks_dao.dart';
import 'package:flowblock/data/db/database.dart' hide Subtask;
import 'package:flowblock/data/db/mappers.dart';
import 'package:flowblock/domain/models/task_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// TasksDao: insert/read ordering, reorder, and watch emissions.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  TaskItem task(String id, int order) {
    return TaskItem(
      id: id,
      title: 'Task $id',
      date: DateTime(2026, 3, 4),
      sortOrder: order,
    );
  }

  Subtask sub(String id, int order) {
    return Subtask(id: id, title: 'Sub $id', sortOrder: order);
  }

  test('insert and read a task with subtasks ordered by sortOrder',
      () async {
    await db.tasksDao.insertTaskWithSubtasks(
      taskCompanionFromDomain(task('t1', 0)),
      <SubtasksCompanion>[
        subtaskCompanionFromDomain(sub('s-b', 1), 't1'),
        subtaskCompanionFromDomain(sub('s-a', 0), 't1'),
      ],
    );

    final TaskWithSubtasks? got = await db.tasksDao.getById('t1');
    expect(got, isNotNull);
    expect(got!.task.id, 't1');
    expect(
      got.subtasks.map((s) => s.id).toList(),
      <String>['s-a', 's-b'],
    );
    expect(
      got.subtasks.map((s) => s.sortOrder).toList(),
      <int>[0, 1],
    );
  });

  test('watchAllWithSubtasks orders tasks by sortOrder', () async {
    await db.tasksDao.insertTaskWithSubtasks(
      taskCompanionFromDomain(task('t-b', 1)),
      const <SubtasksCompanion>[],
    );
    await db.tasksDao.insertTaskWithSubtasks(
      taskCompanionFromDomain(task('t-a', 0)),
      const <SubtasksCompanion>[],
    );

    final List<TaskWithSubtasks> all =
        await db.tasksDao.watchAllWithSubtasks().first;
    expect(
      all.map((TaskWithSubtasks e) => e.task.id).toList(),
      <String>['t-a', 't-b'],
    );
  });

  test('reorderTasks rewrites sortOrder in a transaction', () async {
    for (final String id in <String>['t1', 't2', 't3']) {
      await db.tasksDao.insertTaskWithSubtasks(
        taskCompanionFromDomain(task(id, 0)),
        const <SubtasksCompanion>[],
      );
    }
    await db.tasksDao.reorderTasks(<String>['t3', 't1', 't2']);

    final List<TaskWithSubtasks> all =
        await db.tasksDao.watchAllWithSubtasks().first;
    expect(
      all.map((TaskWithSubtasks e) => e.task.id).toList(),
      <String>['t3', 't1', 't2'],
    );
  });

  test('subtask reorder rewrites sortOrder', () async {
    await db.tasksDao.insertTaskWithSubtasks(
      taskCompanionFromDomain(task('t1', 0)),
      <SubtasksCompanion>[
        subtaskCompanionFromDomain(sub('s1', 0), 't1'),
        subtaskCompanionFromDomain(sub('s2', 1), 't1'),
        subtaskCompanionFromDomain(sub('s3', 2), 't1'),
      ],
    );
    await db.subtasksDao.reorder('t1', <String>['s3', 's1', 's2']);

    final subs = await db.subtasksDao.watchForTask('t1').first;
    expect(
      subs.map((s) => s.id).toList(),
      <String>['s3', 's1', 's2'],
    );
  });

  test('setDone flips isDone with a completedAt instant', () async {
    await db.tasksDao.insertTaskWithSubtasks(
      taskCompanionFromDomain(task('t1', 0)),
      <SubtasksCompanion>[
        subtaskCompanionFromDomain(sub('s1', 0), 't1'),
      ],
    );
    final DateTime doneAt = DateTime.utc(2026, 5, 1, 12);
    await db.subtasksDao.setDone('s1', true, doneAt);

    final subs = await db.subtasksDao.watchForTask('t1').first;
    expect(subs.single.isDone, isTrue);
    expect(subs.single.completedAt?.toUtc(), doneAt);
  });

  test('watchAllWithSubtasks emits a new list after an insert', () async {
    final Stream<List<TaskWithSubtasks>> stream =
        db.tasksDao.watchAllWithSubtasks();
    final List<TaskWithSubtasks> empty = await stream.first;
    expect(empty, isEmpty);

    await db.tasksDao.insertTaskWithSubtasks(
      taskCompanionFromDomain(task('t-new', 0)),
      const <SubtasksCompanion>[],
    );
    final List<TaskWithSubtasks> after = await stream.firstWhere(
      (List<TaskWithSubtasks> list) => list.isNotEmpty,
    );
    expect(after.map((TaskWithSubtasks e) => e.task.id), contains('t-new'));
  });
}
