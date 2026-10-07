import 'package:flutter/material.dart';

import '../../../domain/models/task_item.dart';
import 'subtask_draft.dart';

/// Assembles a [TaskItem] from the form sheet's state. Kept pure (and out of
/// the widget) so the sheet file stays small and this is easy to unit test.
///
/// Each draft carries its real [Subtask.id] (null for rows added in the sheet).
/// Renaming a subtask preserves its id, done state, completedAt, and createdAt.
/// Blank subtask rows are silently dropped on save.
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
  final Map<String, Subtask> prevMap = <String, Subtask>{
    if (existing != null)
      for (final Subtask s in existing.subtasks) s.id: s,
  };

  final List<Subtask> subtasks = <Subtask>[];
  for (int i = 0; i < drafts.length; i++) {
    final SubtaskDraft draft = drafts[i];
    final String subTitle = draft.controller.text.trim();
    if (subTitle.isEmpty) {
      continue;
    }
    final Subtask? prev = draft.id != null ? prevMap[draft.id] : null;
    if (prev != null) {
      subtasks.add(
        Subtask(
          id: prev.id,
          title: subTitle,
          durationMinutes: draft.durationMinutes,
          isDone: prev.isDone,
          sortOrder: i,
          completedAt: prev.completedAt,
          createdAt: prev.createdAt,
          updatedAt: prev.updatedAt,
        ),
      );
    } else {
      subtasks.add(
        Subtask(
          id: draft.id ?? newId(),
          title: subTitle,
          durationMinutes: draft.durationMinutes,
          isDone: draft.isDone,
          sortOrder: i,
        ),
      );
    }
  }

  final bool allDone =
      subtasks.isNotEmpty && subtasks.every((Subtask s) => s.isDone);
  final bool isDone = subtasks.isEmpty ? (existing?.isDone ?? false) : allDone;

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
    isDone: isDone,
    subtasks: subtasks,
    sortOrder: existing?.sortOrder ?? 0,
    recurrenceInterval: existing?.recurrenceInterval ?? 1,
    recurrenceEndsOn: existing?.recurrenceEndsOn,
    createdAt: existing?.createdAt,
    updatedAt: existing?.updatedAt,
  );
}
