import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowblock/data/task_repository.dart';
import 'package:flowblock/domain/models/task_item.dart';

void main() {
  ProviderContainer container() => ProviderContainer();

  test('checking the last open subtask completes the parent', () {
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    final TaskListNotifier tasks = c.read(taskListProvider.notifier);

    tasks.addTask(
      TaskItem(
        id: 't',
        title: 'Parent',
        date: DateTime(2026, 1, 1),
        subtasks: const <Subtask>[
          Subtask(id: 's1', title: 'One'),
          Subtask(id: 's2', title: 'Two'),
        ],
      ),
    );
    tasks.toggleSubtask('t', 's1');
    expect(findTask(c.read(taskListProvider), 't')?.isDone, isFalse);
    tasks.toggleSubtask('t', 's2');
    expect(findTask(c.read(taskListProvider), 't')?.isDone, isTrue);
  });

  test('unchecking a subtask re-opens the parent', () {
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    final TaskListNotifier tasks = c.read(taskListProvider.notifier);

    tasks.addTask(
      TaskItem(
        id: 't',
        title: 'Parent',
        date: DateTime(2026, 1, 1),
        subtasks: const <Subtask>[
          Subtask(id: 's1', title: 'One', isDone: true),
          Subtask(id: 's2', title: 'Two', isDone: true),
        ],
        isDone: true,
      ),
    );
    tasks.toggleSubtask('t', 's1');
    final TaskItem? task = findTask(c.read(taskListProvider), 't');
    expect(task?.isDone, isFalse);
    expect(task?.doneSubtasks, 1);
  });

  test('toggling a parent flips all of its subtasks', () {
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    final TaskListNotifier tasks = c.read(taskListProvider.notifier);

    tasks.addTask(
      TaskItem(
        id: 't',
        title: 'Parent',
        date: DateTime(2026, 1, 1),
        subtasks: const <Subtask>[
          Subtask(id: 's1', title: 'One'),
        ],
      ),
    );
    tasks.toggleTask('t');
    expect(findTask(c.read(taskListProvider), 't')?.doneSubtasks, 1);
    tasks.toggleTask('t');
    expect(findTask(c.read(taskListProvider), 't')?.doneSubtasks, 0);
  });

  test('hasSubtasks and canRunOwnTimer reflect subtask presence', () {
    TaskItem bare = TaskItem(
      id: 'bare',
      title: 'Bare',
      date: DateTime(2026, 1, 1),
      durationMinutes: 25,
    );
    expect(bare.hasSubtasks, isFalse);
    expect(bare.canRunOwnTimer, isTrue);

    TaskItem parent = TaskItem(
      id: 'parent',
      title: 'Parent',
      date: DateTime(2026, 1, 1),
      durationMinutes: 25,
      subtasks: <Subtask>[Subtask(id: 's1', title: 'One')],
    );
    expect(parent.hasSubtasks, isTrue);
    expect(parent.canRunOwnTimer, isFalse);
  });

  test('rolledUpEstimate sums known subtask durations only', () {
    TaskItem some = TaskItem(
      id: 'some',
      title: 'Some',
      date: DateTime(2026, 1, 1),
      subtasks: <Subtask>[
        Subtask(id: 's1', title: 'One', durationMinutes: 10),
        Subtask(id: 's2', title: 'Two'),
        Subtask(id: 's3', title: 'Three', durationMinutes: 15),
      ],
    );
    expect(some.rolledUpEstimate, 25);

    TaskItem none = TaskItem(
      id: 'none',
      title: 'None',
      date: DateTime(2026, 1, 1),
      subtasks: <Subtask>[Subtask(id: 's1', title: 'One')],
    );
    expect(none.rolledUpEstimate, isNull);

    TaskItem empty = TaskItem(
      id: 'empty',
      title: 'Empty',
      date: DateTime(2026, 1, 1),
    );
    expect(empty.rolledUpEstimate, isNull);
  });

  test('displayEstimate prefers the rolled-up sum when subtasks exist', () {
    TaskItem bare = TaskItem(
      id: 'bare',
      title: 'Bare',
      date: DateTime(2026, 1, 1),
      durationMinutes: 25,
    );
    expect(bare.displayEstimate, 25);

    TaskItem parent = TaskItem(
      id: 'parent',
      title: 'Parent',
      date: DateTime(2026, 1, 1),
      durationMinutes: 50,
      subtasks: <Subtask>[
        Subtask(id: 's1', title: 'One', durationMinutes: 10),
        Subtask(id: 's2', title: 'Two'),
      ],
    );
    expect(parent.displayEstimate, 10);

    TaskItem unknown = TaskItem(
      id: 'unknown',
      title: 'Unknown',
      date: DateTime(2026, 1, 1),
      durationMinutes: 50,
      subtasks: <Subtask>[Subtask(id: 's1', title: 'One')],
    );
    expect(unknown.displayEstimate, isNull);
  });

  test('adding the first subtask disables the own timer; '
      'removing the last re-enables it', () {
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    final TaskListNotifier tasks = c.read(taskListProvider.notifier);

    tasks.addTask(
      TaskItem(
        id: 't',
        title: 'Solo',
        date: DateTime(2026, 1, 1),
        durationMinutes: 25,
      ),
    );
    expect(findTask(c.read(taskListProvider), 't')?.canRunOwnTimer, isTrue);

    tasks.addSubtask('t', const Subtask(id: 's1', title: 'One'));
    final TaskItem? withSub =
        findTask(c.read(taskListProvider), 't');
    expect(withSub?.hasSubtasks, isTrue);
    expect(withSub?.canRunOwnTimer, isFalse);
    // Stored task-level duration is kept, not erased.
    expect(withSub?.durationMinutes, 25);

    tasks.removeSubtask('t', 's1');
    final TaskItem? soloAgain = findTask(c.read(taskListProvider), 't');
    expect(soloAgain?.hasSubtasks, isFalse);
    expect(soloAgain?.canRunOwnTimer, isTrue);
    expect(soloAgain?.durationMinutes, 25);
  });
}
