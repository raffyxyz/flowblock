import 'package:flowblock/domain/models/task_item.dart';
import 'package:flowblock/domain/task_filters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for the pure date-filter function (Step 3).
///
/// Matches the previous mock behavior exactly: a task appears on a date
/// when its wall-clock day matches, ignoring clock time.
void main() {
  TaskItem task(String id, DateTime date) {
    return TaskItem(id: id, title: id, date: date);
  }

  test('tasksForDate matches the same wall-clock day only', () {
    final List<TaskItem> tasks = <TaskItem>[
      task('morning', DateTime(2026, 3, 4, 9)),
      task('evening', DateTime(2026, 3, 4, 23, 59)),
      task('next', DateTime(2026, 3, 5)),
    ];
    final List<TaskItem> got = tasksForDate(tasks, DateTime(2026, 3, 4));
    expect(got.map((TaskItem t) => t.id), <String>['morning', 'evening']);
  });

  test('tasksForDate returns empty when nothing matches', () {
    final List<TaskItem> tasks = <TaskItem>[
      task('a', DateTime(2026, 3, 4)),
    ];
    expect(tasksForDate(tasks, DateTime(2026, 3, 6)), isEmpty);
    expect(tasksForDate(const <TaskItem>[], DateTime(2026, 3, 4)), isEmpty);
  });

  test('findTask returns the task or null', () {
    final List<TaskItem> tasks = <TaskItem>[
      task('a', DateTime(2026, 3, 4)),
    ];
    expect(findTask(tasks, 'a')?.id, 'a');
    expect(findTask(tasks, 'missing'), isNull);
  });
}
