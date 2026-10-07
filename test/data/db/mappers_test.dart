import 'package:flowblock/data/db/mappers.dart';
import 'package:flowblock/domain/models/task_item.dart';
import 'package:flowblock/domain/models/task_occurrence.dart';
import 'package:flowblock/domain/models/timer_session.dart';
import 'package:flowblock/data/db/database.dart' as db;
import 'package:flutter_test/flutter_test.dart';

/// Mapper round trips, including weekday bitmask and enum storage.
void main() {
  test('weekday bitmask uses bit 0 = Monday', () {
    expect(weekdaysToBitmask(const <int>[1]), 1);
    expect(weekdaysToBitmask(const <int>[1, 3, 5]), 21);
    expect(weekdaysToBitmask(const <int>[7]), 64);
    expect(weekdaysToBitmask(const <int>[]), 0);
    expect(bitmaskToWeekdays(21), <int>[1, 3, 5]);
    expect(bitmaskToWeekdays(0), isEmpty);
  });

  test('day format round trip', () {
    expect(formatDay(DateTime(2026, 3, 4)), '2026-03-04');
    expect(parseDay('2026-03-04'), DateTime(2026, 3, 4));
  });

  test('task round trip keeps every new field', () {
    final TaskItem item = TaskItem(
      id: 't1',
      title: ' titled ',
      notes: 'keep me',
      date: DateTime(2026, 3, 4),
      time: DateTime(2026, 3, 4, 9, 30),
      recurrence: RecurrenceType.weekly,
      weekdays: const <int>[1, 5],
      durationMinutes: 50,
      isDone: false,
      sortOrder: 3,
      recurrenceInterval: 2,
      recurrenceEndsOn: DateTime(2026, 6, 30),
      createdAt: DateTime.utc(2026, 1, 1, 8),
      updatedAt: DateTime.utc(2026, 2, 2, 9),
      subtasks: const <Subtask>[
        Subtask(
          id: 's1',
          title: 'step',
          durationMinutes: 15,
          sortOrder: 0,
        ),
      ],
    );

    final db.TasksCompanion companion = taskCompanionFromDomain(item);
    // Enums are stored as text by name.
    expect(companion.recurrenceType.value, RecurrenceType.weekly);
    expect(companion.recurrenceType.value.name, 'weekly');
    // Weekdays stored as bitmask Mon + Fri = 1 + 16.
    expect(companion.recurrenceWeekdays.value, 17);
    // Estimate stored as seconds, schedule as wall-clock text + minutes.
    expect(companion.estimatedSeconds.value, 3000);
    expect(companion.scheduledDate.value, '2026-03-04');
    expect(companion.scheduledMinutes.value, 570);
    expect(companion.recurrenceInterval.value, 2);
    expect(companion.recurrenceEndsOn.value, '2026-06-30');

    // Simulate a read-back row pair.
    final db.Task row = db.Task(
      id: 't1',
      title: item.title,
      notes: 'keep me',
      sortOrder: 3,
      isDone: false,
      estimatedSeconds: 3000,
      scheduledDate: '2026-03-04',
      scheduledMinutes: 570,
      recurrenceType: RecurrenceType.weekly,
      recurrenceInterval: 2,
      recurrenceWeekdays: 17,
      recurrenceEndsOn: '2026-06-30',
      createdAt: DateTime.utc(2026, 1, 1, 8),
      updatedAt: DateTime.utc(2026, 2, 2, 9),
    );
    final db.Subtask subRow = db.Subtask(
      id: 's1',
      taskId: 't1',
      title: 'step',
      sortOrder: 0,
      isDone: false,
      durationSeconds: 900,
      createdAt: DateTime.utc(2026, 1, 1, 8),
      updatedAt: DateTime.utc(2026, 2, 2, 9),
    );
    final TaskItem back = taskItemFromRows(row, <db.Subtask>[subRow]);
    expect(back.notes, 'keep me');
    expect(back.durationMinutes, 50);
    expect(back.recurrence, RecurrenceType.weekly);
    expect(back.weekdays, <int>[1, 5]);
    expect(back.recurrenceInterval, 2);
    expect(back.recurrenceEndsOn, DateTime(2026, 6, 30));
    expect(back.sortOrder, 3);
    expect(back.date, DateTime(2026, 3, 4));
    expect(back.time, DateTime(2026, 3, 4, 9, 30));
    expect(back.subtasks.single.durationMinutes, 15);
    // Derived getters still work after the round trip.
    expect(back.hasSubtasks, isTrue);
    expect(back.canRunOwnTimer, isFalse);
    expect(back.displayEstimate, 15);
  });

  test('empty notes map to null and back to empty', () {
    final TaskItem item = TaskItem(
      id: 't',
      title: 'x',
      date: DateTime(2026, 1, 1),
    );
    final db.TasksCompanion companion = taskCompanionFromDomain(item);
    expect(companion.notes.value, isNull);
  });

  test('occurrence and timer round trips keep enums', () {
    final TaskOccurrence occ = TaskOccurrence(
      id: 'o1',
      taskId: 't1',
      date: DateTime(2026, 3, 4),
      status: OccurrenceStatus.skipped,
    );
    final db.TaskOccurrencesCompanion occComp =
        occurrenceCompanionFromDomain(occ);
    expect(occComp.status.value.name, 'skipped');
    final TaskOccurrence occBack = occurrenceFromRow(
      db.TaskOccurrence(
        id: 'o1',
        taskId: 't1',
        date: '2026-03-04',
        status: OccurrenceStatus.skipped,
      ),
    );
    expect(occBack.date, DateTime(2026, 3, 4));
    expect(occBack.status, OccurrenceStatus.skipped);

    final TimerSession sess = TimerSession(
      id: 's1',
      taskId: 't1',
      startedAt: DateTime.utc(2026, 3, 4, 9),
      plannedSeconds: 1500,
      mode: TimerMode.stopwatch,
      endReason: TimerEndReason.stopped,
    );
    final db.TimerSessionsCompanion sessComp =
        timerCompanionFromDomain(sess);
    expect(sessComp.mode.value.name, 'stopwatch');
    expect(sessComp.endReason.value?.name, 'stopped');
    final TimerSession sessBack = timerSessionFromRow(
      db.TimerSession(
        id: 's1',
        taskId: 't1',
        startedAt: DateTime.utc(2026, 3, 4, 9),
        plannedSeconds: 1500,
        elapsedSeconds: 0,
        mode: TimerMode.stopwatch,
        endReason: TimerEndReason.stopped,
      ),
    );
    expect(sessBack.mode, TimerMode.stopwatch);
    expect(sessBack.endReason, TimerEndReason.stopped);
    expect(sessBack.isOpen, isTrue);
  });
}
