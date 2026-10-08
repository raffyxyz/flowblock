import 'package:flowblock/domain/models/task_item.dart';
import 'package:flowblock/features/tasks/sheet/sheet_task_builder.dart';
import 'package:flowblock/features/tasks/sheet/subtask_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sheet builder gaps: blank rows dropped, rename preserves identity.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TaskItem existing() {
    return TaskItem(
      id: 't1',
      title: 'Parent',
      date: DateTime(2026, 3, 4),
      subtasks: <Subtask>[
        Subtask(
          id: 's1',
          title: 'Alpha',
          durationMinutes: 10,
          isDone: true,
          sortOrder: 0,
          completedAt: DateTime.utc(2026, 3, 3, 10),
          createdAt: DateTime.utc(2026, 3, 1),
          updatedAt: DateTime.utc(2026, 3, 2),
        ),
        Subtask(id: 's2', title: 'Beta', sortOrder: 1),
      ],
    );
  }

  SubtaskDraft draft({String? id, required String title, bool done = false}) {
    final SubtaskDraft d = SubtaskDraft(id: id, title: title, isDone: done);
    return d;
  }

  test('blank subtask rows are dropped on save', () {
    final TaskItem task = buildSheetTask(
      title: 'T',
      notes: '',
      date: DateTime(2026, 3, 4),
      time: null,
      recurrence: RecurrenceType.once,
      weekdays: const <int>{},
      duration: 25,
      drafts: <SubtaskDraft>[
        draft(title: '  '),
        draft(title: 'Real'),
        draft(title: ''),
      ],
      newId: () => 'n1',
    );
    expect(task.subtasks.map((Subtask s) => s.title), <String>['Real']);
  });

  test('renamed subtask keeps id, done, completedAt', () {
    final TaskItem prev = existing();
    final SubtaskDraft d1 = draft(id: 's1', title: 'Alpha renamed');
    d1.durationMinutes = 15;
    final SubtaskDraft d2 = draft(id: 's2', title: 'Beta');
    final TaskItem built = buildSheetTask(
      existing: prev,
      title: 'Parent',
      notes: '',
      date: DateTime(2026, 3, 4),
      time: null,
      recurrence: RecurrenceType.once,
      weekdays: const <int>{},
      duration: 25,
      drafts: <SubtaskDraft>[d1, d2],
      newId: () => 'unused',
    );
    final Subtask kept = built.subtasks.firstWhere(
      (Subtask s) => s.id == 's1',
    );
    expect(kept.title, 'Alpha renamed');
    expect(kept.isDone, isTrue);
    expect(kept.completedAt, prev.subtasks[0].completedAt);
    expect(kept.createdAt, prev.subtasks[0].createdAt);
    expect(built.subtasks[1].id, 's2');
    d1.dispose();
    d2.dispose();
  });

  test('new rows get ids and time is preserved', () {
    int counter = 0;
    final SubtaskDraft d = draft(title: 'Fresh');
    final TaskItem built = buildSheetTask(
      title: 'T',
      notes: '',
      date: DateTime(2026, 3, 4),
      time: const TimeOfDay(hour: 9, minute: 30),
      recurrence: RecurrenceType.once,
      weekdays: const <int>{},
      duration: 25,
      drafts: <SubtaskDraft>[d],
      newId: () => 'gen-${counter++}',
    );
    expect(built.subtasks.single.id, 'gen-0');
    expect(built.time?.hour, 9);
    d.dispose();
  });
}
