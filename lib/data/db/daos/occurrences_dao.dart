import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/models/task_occurrence.dart' show OccurrenceStatus;
import '../database.dart';
import '../tables.dart';

part 'occurrences_dao.g.dart';

/// Pure data operations for occurrences (no recurrence math here).
@DriftAccessor(tables: [TaskOccurrences, OccurrenceSubtaskStates])
class OccurrencesDao extends DatabaseAccessor<AppDatabase>
    with _$OccurrencesDaoMixin {
  OccurrencesDao(super.db);

  static const Uuid _uuid = Uuid();

  /// Returns the existing row for ([taskId], [date]) or creates a pending one.
  /// [date] is wall-clock 'yyyy-MM-dd'.
  Future<TaskOccurrence> getOrCreate(String taskId, String date) async {
    final TaskOccurrence? existing =
        await (select(taskOccurrences)
              ..where((TaskOccurrences o) => o.taskId.equals(taskId))
              ..where((TaskOccurrences o) => o.date.equals(date)))
            .getSingleOrNull();
    if (existing != null) {
      return existing;
    }
    final TaskOccurrencesCompanion entry = TaskOccurrencesCompanion.insert(
      id: _uuid.v4(),
      taskId: taskId,
      date: date,
    );
    await into(taskOccurrences).insert(entry);
    final TaskOccurrence? created =
        await (select(taskOccurrences)
              ..where((TaskOccurrences o) => o.taskId.equals(taskId))
              ..where((TaskOccurrences o) => o.date.equals(date)))
            .getSingleOrNull();
    return created!;
  }

  Future<void> setStatus(
    String id,
    OccurrenceStatus status,
    DateTime? completedAt,
  ) {
    return (update(taskOccurrences)
          ..where((TaskOccurrences o) => o.id.equals(id)))
        .write(
          TaskOccurrencesCompanion(
            status: Value<OccurrenceStatus>(status),
            completedAt: Value<DateTime?>(completedAt?.toUtc()),
          ),
        );
  }

  Stream<List<TaskOccurrence>> watchForDate(String date) {
    return (select(taskOccurrences)
          ..where((TaskOccurrences o) => o.date.equals(date)))
        .watch();
  }

  Future<void> upsertSubtaskState(
    OccurrenceSubtaskStatesCompanion entry,
  ) {
    return into(occurrenceSubtaskStates).insertOnConflictUpdate(entry);
  }

  Stream<List<OccurrenceSubtaskState>> watchSubtaskStates(
    String occurrenceId,
  ) {
    return (select(occurrenceSubtaskStates)..where(
            (OccurrenceSubtaskStates s) =>
                s.occurrenceId.equals(occurrenceId),
          ))
        .watch();
  }
}
