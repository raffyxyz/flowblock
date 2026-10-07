import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'subtasks_dao.g.dart';

/// Pure data operations for subtasks (no business rules).
@DriftAccessor(tables: [Subtasks])
class SubtasksDao extends DatabaseAccessor<AppDatabase>
    with _$SubtasksDaoMixin {
  SubtasksDao(super.db);

  Future<void> insert(SubtasksCompanion entry) {
    return into(subtasks).insert(entry);
  }

  Future<bool> updateSubtask(SubtasksCompanion entry) {
    return update(subtasks).replace(entry);
  }

  Future<int> deleteSubtask(String id) {
    return (delete(subtasks)..where((Subtasks s) => s.id.equals(id)))
        .go();
  }

  Future<void> setDone(String id, bool isDone, DateTime? completedAt) {
    return (update(subtasks)..where((Subtasks s) => s.id.equals(id)))
        .write(
          SubtasksCompanion(
            isDone: Value<bool>(isDone),
            completedAt: Value<DateTime?>(completedAt?.toUtc()),
          ),
        );
  }

  Future<void> reorder(String taskId, List<String> orderedIds) {
    return transaction(() async {
      for (int i = 0; i < orderedIds.length; i++) {
        await (update(subtasks)
              ..where((Subtasks s) => s.id.equals(orderedIds[i]))
              ..where((Subtasks s) => s.taskId.equals(taskId)))
            .write(SubtasksCompanion(sortOrder: Value<int>(i)));
      }
    });
  }

  Stream<List<Subtask>> watchForTask(String taskId) {
    final SimpleSelectStatement<$SubtasksTable, Subtask> query =
        select(subtasks)
          ..where((Subtasks s) => s.taskId.equals(taskId))
          ..orderBy(<OrderClauseGenerator<$SubtasksTable>>[
            (Subtasks s) => OrderingTerm.asc(s.sortOrder),
          ]);
    return query.watch();
  }
}
