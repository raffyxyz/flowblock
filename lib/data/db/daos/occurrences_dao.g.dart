// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'occurrences_dao.dart';

// ignore_for_file: type=lint
mixin _$OccurrencesDaoMixin on DatabaseAccessor<AppDatabase> {
  $TasksTable get tasks => attachedDatabase.tasks;
  $TaskOccurrencesTable get taskOccurrences => attachedDatabase.taskOccurrences;
  $SubtasksTable get subtasks => attachedDatabase.subtasks;
  $OccurrenceSubtaskStatesTable get occurrenceSubtaskStates =>
      attachedDatabase.occurrenceSubtaskStates;
  OccurrencesDaoManager get managers => OccurrencesDaoManager(this);
}

class OccurrencesDaoManager {
  final _$OccurrencesDaoMixin _db;
  OccurrencesDaoManager(this._db);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
  $$TaskOccurrencesTableTableManager get taskOccurrences =>
      $$TaskOccurrencesTableTableManager(
        _db.attachedDatabase,
        _db.taskOccurrences,
      );
  $$SubtasksTableTableManager get subtasks =>
      $$SubtasksTableTableManager(_db.attachedDatabase, _db.subtasks);
  $$OccurrenceSubtaskStatesTableTableManager get occurrenceSubtaskStates =>
      $$OccurrenceSubtaskStatesTableTableManager(
        _db.attachedDatabase,
        _db.occurrenceSubtaskStates,
      );
}
