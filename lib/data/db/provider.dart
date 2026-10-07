import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection.dart';
import 'database.dart';

/// Production database provider (Step 2).
///
/// Nothing in widgets or existing providers reads this yet; Step 3 wires it
/// to the repository layer.
final Provider<AppDatabase> appDatabaseProvider =
    Provider<AppDatabase>((Ref ref) {
      final AppDatabase db = AppDatabase(openProductionConnection());
      ref.onDispose(() {
        db.close();
      });
      return db;
    });
