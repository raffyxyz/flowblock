import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flowblock/data/db/database.dart';
import 'package:flowblock/data/db/mappers.dart';
import 'package:flowblock/domain/models/task_item.dart';
import 'package:flowblock/domain/models/timer_session.dart'
    show TimerEndReason;
import 'package:flutter_test/flutter_test.dart';

/// TimerSessionsDao: insert, finish, watch, and the single open session.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.tasksDao.insertTaskWithSubtasks(
      taskCompanionFromDomain(
        TaskItem(id: 't1', title: 'Timed', date: DateTime(2026, 3, 4)),
      ),
      const <SubtasksCompanion>[],
    );
  });

  tearDown(() async {
    await db.close();
  });

  TimerSessionsCompanion session(
    String id,
    DateTime started, {
    bool open = true,
  }) {
    return TimerSessionsCompanion.insert(
      id: id,
      taskId: 't1',
      startedAt: started,
      plannedSeconds: 1500,
      endedAt: open
          ? const Value<DateTime?>(null)
          : Value<DateTime?>(started.add(const Duration(minutes: 25))),
      elapsedSeconds: Value<int>(open ? 0 : 1500),
    );
  }

  test('getOpenSession returns only the session with null endedAt',
      () async {
    expect(await db.timerSessionsDao.getOpenSession(), isNull);

    await db.timerSessionsDao.insert(
      session('closed', DateTime.utc(2026, 3, 4, 8), open: false),
    );
    expect(await db.timerSessionsDao.getOpenSession(), isNull);

    await db.timerSessionsDao.insert(
      session('open', DateTime.utc(2026, 3, 4, 9)),
    );
    final TimerSession? openSession =
        await db.timerSessionsDao.getOpenSession();
    expect(openSession?.id, 'open');

    await db.timerSessionsDao.finish(
      'open',
      DateTime.utc(2026, 3, 4, 9, 25),
      1500,
      TimerEndReason.completed,
    );
    expect(await db.timerSessionsDao.getOpenSession(), isNull);

    final List<TimerSession> all =
        await db.timerSessionsDao.watchForTask('t1').first;
    final TimerSession finished = all.firstWhere(
      (TimerSession s) => s.id == 'open',
    );
    expect(finished.endReason, TimerEndReason.completed);
    expect(finished.elapsedSeconds, 1500);
  });

  test('finish records endedAt, elapsedSeconds, and endReason', () async {
    await db.timerSessionsDao.insert(
      session('s1', DateTime.utc(2026, 3, 4, 9)),
    );
    final DateTime ended = DateTime.utc(2026, 3, 4, 9, 10);
    await db.timerSessionsDao.finish(
      's1',
      ended,
      600,
      TimerEndReason.stopped,
    );

    final List<TimerSession> all =
        await db.timerSessionsDao.watchForTask('t1').first;
    expect(all.single.endedAt?.toUtc(), ended);
    expect(all.single.elapsedSeconds, 600);
    expect(all.single.endReason, TimerEndReason.stopped);
  });
}
