// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timer_sessions_dao.dart';

// ignore_for_file: type=lint
mixin _$TimerSessionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TasksTable get tasks => attachedDatabase.tasks;
  $SubtasksTable get subtasks => attachedDatabase.subtasks;
  $TimerSessionsTable get timerSessions => attachedDatabase.timerSessions;
  TimerSessionsDaoManager get managers => TimerSessionsDaoManager(this);
}

class TimerSessionsDaoManager {
  final _$TimerSessionsDaoMixin _db;
  TimerSessionsDaoManager(this._db);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
  $$SubtasksTableTableManager get subtasks =>
      $$SubtasksTableTableManager(_db.attachedDatabase, _db.subtasks);
  $$TimerSessionsTableTableManager get timerSessions =>
      $$TimerSessionsTableTableManager(_db.attachedDatabase, _db.timerSessions);
}
