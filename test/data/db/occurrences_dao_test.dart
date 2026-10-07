import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flowblock/data/db/database.dart';
import 'package:flowblock/data/db/mappers.dart';
import 'package:flowblock/domain/models/task_item.dart';
import 'package:flowblock/domain/models/task_occurrence.dart'
    show OccurrenceStatus;
import 'package:flutter_test/flutter_test.dart';

/// OccurrencesDao: getOrCreate, unique (taskId, date), status, subtask states.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.tasksDao.insertTaskWithSubtasks(
      taskCompanionFromDomain(
        TaskItem(id: 't1', title: 'Recurring', date: DateTime(2026, 3, 4)),
      ),
      const <SubtasksCompanion>[],
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('getOrCreate returns the same row for the same date', () async {
    final TaskOccurrence first = await db.occurrencesDao.getOrCreate(
      't1',
      '2026-03-04',
    );
    final TaskOccurrence second = await db.occurrencesDao.getOrCreate(
      't1',
      '2026-03-04',
    );
    expect(second.id, first.id);

    final TaskOccurrence other = await db.occurrencesDao.getOrCreate(
      't1',
      '2026-03-05',
    );
    expect(other.id, isNot(first.id));
  });

  test('unique constraint on (taskId, date)', () async {
    await db.occurrencesDao.getOrCreate('t1', '2026-03-06');
    await expectLater(
      db.into(db.taskOccurrences).insert(
            TaskOccurrencesCompanion.insert(
              id: 'dup',
              taskId: 't1',
              date: '2026-03-06',
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('setStatus updates status and completedAt', () async {
    final TaskOccurrence occ = await db.occurrencesDao.getOrCreate(
      't1',
      '2026-03-04',
    );
    final DateTime doneAt = DateTime.utc(2026, 3, 4, 18);
    await db.occurrencesDao.setStatus(
      occ.id,
      OccurrenceStatus.done,
      doneAt,
    );

    final List<TaskOccurrence> rows =
        await db.occurrencesDao.watchForDate('2026-03-04').first;
    expect(rows.single.status, OccurrenceStatus.done);
    expect(rows.single.completedAt?.toUtc(), doneAt);
  });

  test('upsert and watch subtask states per occurrence', () async {
    await db.tasksDao.insertTaskWithSubtasks(
      taskCompanionFromDomain(
        TaskItem(id: 't2', title: 'With subs', date: DateTime(2026, 3, 4)),
      ),
      <SubtasksCompanion>[
        SubtasksCompanion.insert(
          id: 's1',
          taskId: 't2',
          title: 'step',
          sortOrder: 0,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      ],
    );
    final TaskOccurrence occ = await db.occurrencesDao.getOrCreate(
      't2',
      '2026-03-04',
    );
    await db.occurrencesDao.upsertSubtaskState(
      OccurrenceSubtaskStatesCompanion.insert(
        occurrenceId: occ.id,
        subtaskId: 's1',
        isDone: const Value<bool>(true),
        completedAt: Value<DateTime?>(DateTime.utc(2026, 3, 4, 10)),
      ),
    );

    final List<OccurrenceSubtaskState> states = await db
        .occurrencesDao
        .watchSubtaskStates(occ.id)
        .first;
    expect(states, hasLength(1));
    expect(states.single.isDone, isTrue);

    // Upsert flips it back without creating a second row.
    await db.occurrencesDao.upsertSubtaskState(
      OccurrenceSubtaskStatesCompanion.insert(
        occurrenceId: occ.id,
        subtaskId: 's1',
        isDone: const Value<bool>(false),
      ),
    );
    final List<OccurrenceSubtaskState> again = await db
        .occurrencesDao
        .watchSubtaskStates(occ.id)
        .first;
    expect(again, hasLength(1));
    expect(again.single.isDone, isFalse);
  });
}
