import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection.dart';
import 'database.dart';

/// Production database provider (Step 3: now read by the repository).
///
/// [AppDatabase] seeds the 8 sample tasks once on first creation in debug
/// builds only; tests override this provider with an in-memory database
/// (which starts empty) and release builds start empty too.
final Provider<AppDatabase> appDatabaseProvider =
    Provider<AppDatabase>((Ref ref) {
      final AppDatabase db = AppDatabase(
        openProductionConnection(),
        seedOnCreate: kDebugMode,
      );
      ref.onDispose(() {
        db.close();
      });
      return db;
    });
