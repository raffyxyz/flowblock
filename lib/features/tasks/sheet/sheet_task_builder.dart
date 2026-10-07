import 'package:flutter/material.dart';

import '../../../domain/models/task_item.dart';
import 'subtask_draft.dart';

/// Assembles a [TaskItem] from the form sheet's state. Kept pure (and out of
/// the widget) so the sheet file stays small and this is easy to unit test.
///
/// Subtask ids are preserved across edits by matching titles: a draft whose
/// title matches an unmatched existing subtask reuses that id (and keeps its
/// done flag unless the draft itself is done). Genuinely new drafts get an
/// id from [newId]. The repository syncs subtasks by id.
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
  required String Function() newId,
}) {
  final List<Subtask> previous = existing?.subtasks ?? const <Subtask>[];
  final List<bool> claimed = List<bool>.filled(previous.length, false);
  final List<Subtask> subtasks = <Subtask>[
    for (final SubtaskDraft draft in drafts)
      if (draft.controller.text.trim().isNotEmpty)
        _reuseOrNew(previous, claimed, draft, newId),
  ];
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
        subtasks.isNotEmpty && subtasks.every((Subtask s) => s.isDone),
    subtasks: subtasks,
    sortOrder: existing?.sortOrder ?? 0,
    recurrenceInterval: existing?.recurrenceInterval ?? 1,
    recurrenceEndsOn: existing?.recurrenceEndsOn,
    createdAt: existing?.createdAt,
    updatedAt: existing?.updatedAt,
  );
}

Subtask _reuseOrNew(
  List<Subtask> previous,
  List<bool> claimed,
  SubtaskDraft draft,
  String Function() newId,
) {
  final String title = draft.controller.text.trim();
  for (int i = 0; i < previous.length; i++) {
    if (!claimed[i] && previous[i].title == title) {
      claimed[i] = true;
      final Subtask match = previous[i];
      return Subtask(
        id: match.id,
        title: title,
        durationMinutes: draft.durationMinutes,
        isDone: draft.isDone || match.isDone,
        sortOrder: match.sortOrder,
        completedAt: match.completedAt,
        createdAt: match.createdAt,
        updatedAt: match.updatedAt,
      );
    }
  }
  return Subtask(
    id: newId(),
    title: title,
    durationMinutes: draft.durationMinutes,
    isDone: draft.isDone,
  );
}
