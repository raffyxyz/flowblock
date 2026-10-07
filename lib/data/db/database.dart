import 'package:drift/drift.dart';

import '../../domain/models/task_item.dart';
import '../../domain/models/task_occurrence.dart';
import '../../domain/models/timer_session.dart';
import 'daos/occurrences_dao.dart';
import 'daos/subtasks_dao.dart';
import 'daos/tasks_dao.dart';
import 'daos/timer_sessions_dao.dart';
import '../seed/seed_data.dart';
import 'tables.dart';

part 'database.g.dart';

/// Local SQLite database (Step 2).
///
/// Takes a [QueryExecutor] so tests can inject an in-memory database and web
/// can be added later. No static singleton; production instances come from
/// [appDatabaseProvider] (see `provider.dart`).
@DriftDatabase(
  tables: [
    Tasks,
    Subtasks,
    TaskOccurrences,
    OccurrenceSubtaskStates,
    TimerSessions,
  ],
  daos: [TasksDao, SubtasksDao, OccurrencesDao, TimerSessionsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor, {this.seedOnCreate = false});

  /// When true, the debug seed tasks are inserted once in `onCreate`.
  /// Production passes `kDebugMode`; tests and release builds start empty.
  final bool seedOnCreate;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      if (seedOnCreate) {
        await seedDatabase(this);
      }
    },
    // Empty onUpgrade stub for future versions (v2+ migrations go here).
    onUpgrade: (Migrator m, int from, int to) async {},
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
