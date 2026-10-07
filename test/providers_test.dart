import 'package:drift/native.dart';
import 'package:flowblock/data/db/database.dart';
import 'package:flowblock/data/db/provider.dart';
import 'package:flowblock/data/task_repository.dart';
import 'package:flowblock/domain/models/task_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Provider wiring test (Step 3): with [appDatabaseProvider] overridden by
/// an in-memory database, [taskListProvider] emits after a write.
void main() {
  test('taskListProvider emits after addTask', () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    final ProviderContainer container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 3, 4, 12)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    final List<List<TaskItem>> emitted = <List<TaskItem>>[];
    container.listen(
      taskListProvider,
      (AsyncValue<List<TaskItem>>? _, AsyncValue<List<TaskItem>> next) {
        next.whenData(emitted.add);
      },
    );

    Future<void> waitFor(bool Function() cond) async {
      for (int i = 0; i < 200 && !cond(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    await waitFor(() => emitted.isNotEmpty);
    expect(emitted.last, isEmpty);

    await container
        .read(taskRepositoryProvider)
        .addTask(
          TaskItem(id: '', title: 'Hello', date: DateTime(2026, 3, 4)),
        );
    await waitFor(
      () => emitted.any(
        (List<TaskItem> list) =>
            list.any((TaskItem t) => t.title == 'Hello'),
      ),
    );
    expect(
      emitted.last.map((TaskItem t) => t.title),
      contains('Hello'),
    );
  });
}
