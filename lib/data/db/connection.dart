import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Production query executor for the `flowblock` database.
///
/// Kept in its own file so tests can inject `NativeDatabase.memory()`
/// instead, and web can be added later via [DriftWebOptions].
QueryExecutor openProductionConnection() {
  return driftDatabase(name: 'flowblock');
}
