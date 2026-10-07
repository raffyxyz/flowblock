import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flowblock/data/db/database.dart';
import 'package:flowblock/data/db/mappers.dart';
import 'package:flowblock/domain/models/task_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// Foreign keys, cascading deletes, and the SET NULL timer history rule.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedFullGraph() async {
    await db.tasksDao.insertTaskWithSubtasks(
      taskCompanionFromDomain(
        TaskItem(
          id: 't1',
          title: 'Cascade root',
          date: DateTime(2026, 3, 4),
        ),
      ),
      <SubtasksCompanion>[
        SubtasksCompanion.insert(
          id: 's1',
          taskId: 't1',
          title: 'step',
          sortOrder: 0,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      ],
    );
    await db.occurrencesDao.getOrCreate('t1', '2026-03-04');
    final TaskOccurrence occ =
        await db.occurrencesDao.getOrCreate('t1', '2026-03-04');
    await db.occurrencesDao.upsertSubtaskState(
      OccurrenceSubtaskStatesCompanion.insert(
        occurrenceId: occ.id,
        subtaskId: 's1',
      ),
    );
    await db.timerSessionsDao.insert(
      TimerSessionsCompanion.insert(
        id: 'sess-1',
        taskId: 't1',
        subtaskId: const Value<String?>('s1'),
        startedAt: DateTime.utc(2026, 3, 4, 9),
        plannedSeconds: 1500,
      ),
    );
  }

  test('deleting a task cascades to subtasks, occurrences, timers',
      () async {
    await seedFullGraph();
    await db.tasksDao.deleteTask('t1');

    expect(await db.tasksDao.getById('t1'), isNull);
    expect(
      await db.subtasksDao.watchForTask('t1').first,
      isEmpty,
    );
    expect(
      await db.occurrencesDao.watchForDate('2026-03-04').first,
      isEmpty,
    );
    expect(
      await db.timerSessionsDao.watchForTask('t1').first,
      isEmpty,
    );
  });

  test('foreign keys are enforced for subtasks', () async {
    await expectLater(
      db.subtasksDao.insert(
        SubtasksCompanion.insert(
          id: 'orphan',
          taskId: 'no-such-task',
          title: 'orphan',
          sortOrder: 0,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('deleting a subtask keeps timer history with subtaskId null',
      () async {
    await seedFullGraph();
    await db.subtasksDao.deleteSubtask('s1');

    final List<TimerSession> sessions =
        await db.timerSessionsDao.watchForTask('t1').first;
    expect(sessions, hasLength(1));
    expect(sessions.single.subtaskId, isNull);
    expect(sessions.single.taskId, 't1');
  });
}
