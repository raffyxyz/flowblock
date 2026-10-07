import 'package:drift/drift.dart';

import '../../../domain/models/timer_session.dart'
    show TimerEndReason;
import '../database.dart';
import '../tables.dart';

part 'timer_sessions_dao.g.dart';

/// Pure data operations for timer history (no timer rules here).
@DriftAccessor(tables: [TimerSessions])
class TimerSessionsDao extends DatabaseAccessor<AppDatabase>
    with _$TimerSessionsDaoMixin {
  TimerSessionsDao(super.db);

  Future<void> insert(TimerSessionsCompanion entry) {
    return into(timerSessions).insert(entry);
  }

  Future<void> finish(
    String id,
    DateTime endedAt,
    int elapsedSeconds,
    TimerEndReason? endReason,
  ) {
    return (update(timerSessions)
          ..where((TimerSessions t) => t.id.equals(id)))
        .write(
          TimerSessionsCompanion(
            endedAt: Value<DateTime?>(endedAt.toUtc()),
            elapsedSeconds: Value<int>(elapsedSeconds),
            endReason: Value<TimerEndReason?>(endReason),
          ),
        );
  }

  Stream<List<TimerSession>> watchForTask(String taskId) {
    return (select(timerSessions)
          ..where((TimerSessions t) => t.taskId.equals(taskId))
          ..orderBy(<OrderClauseGenerator<$TimerSessionsTable>>[
            (TimerSessions t) => OrderingTerm.desc(t.startedAt),
          ]))
        .watch();
  }

  /// The single open session (`endedAt` null), if any.
  Future<TimerSession?> getOpenSession() {
    return (select(timerSessions)
          ..where((TimerSessions t) => t.endedAt.isNull()))
        .getSingleOrNull();
  }
}
