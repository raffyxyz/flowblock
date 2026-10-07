import 'package:flutter/material.dart';

import '../../../data/task_repository.dart';
import '../../../domain/models/task_item.dart';
import 'subtask_draft.dart';

/// Assembles a [TaskItem] from the form sheet's state. Kept pure (and out of
/// the widget) so the sheet file stays small and this is easy to unit test.
TaskItem buildSheetTask({
  TaskItem? existing,
  required String title,
  required String notes,
  required DateTime date,
  required TimeOfDay? time,
  required RecurrenceType recurrence,
  required Set<int> weekdays,
  required int duration,
  required List<SubtaskDraft> drafts,
}) {
  final List<Subtask> subtasks = <Subtask>[
    for (final SubtaskDraft draft in drafts)
      if (draft.controller.text.trim().isNotEmpty)
        Subtask(
          id: newId(),
          title: draft.controller.text.trim(),
          durationMinutes: draft.durationMinutes,
          isDone: draft.isDone,
        ),
  ];
  final List<Subtask> merged = existing == null
      ? subtasks
      : _keepDoneFlags(existing.subtasks, subtasks);
  return TaskItem(
    id: existing?.id ?? newId(),
    title: title,
    notes: notes,
    date: date,
    time: time == null
        ? null
        : DateTime(date.year, date.month, date.day, time.hour, time.minute),
    recurrence: recurrence,
    weekdays: recurrence == RecurrenceType.weekly
        ? (List<int>.from(weekdays)..sort())
        : const <int>[],
    durationMinutes: duration,
    isDone:
        merged.isNotEmpty && merged.every((Subtask s) => s.isDone),
    subtasks: merged,
  );
}

/// Keeps the done state of pre-existing subtasks matched by title, since
/// edited drafts get fresh ids.
List<Subtask> _keepDoneFlags(
  List<Subtask> previous,
  List<Subtask> next,
) {
  return <Subtask>[
    for (final Subtask s in next)
      if (s.isDone)
        s
      else
        s.copyWith(
          isDone:
              previous.any((Subtask p) => p.title == s.title && p.isDone),
        ),
  ];
}
