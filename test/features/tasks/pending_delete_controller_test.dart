import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowblock/domain/models/task_item.dart';
import 'package:flowblock/features/tasks/pending_delete_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PendingDeleteController filters subtasks and recomputes parent state', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final PendingDeleteController controller =
        container.read(pendingDeleteControllerProvider.notifier);

    final TaskItem task = TaskItem(
      id: 't1',
      title: 'Parent Task',
      date: DateTime(2026, 1, 1),
      isDone: false,
      subtasks: const <Subtask>[
        Subtask(id: 's1', title: 'Sub 1', isDone: true),
        Subtask(id: 's2', title: 'Sub 2', isDone: false),
      ],
    );

    expect(controller.filterTask(task)?.isDone, isFalse);
    expect(controller.filterTask(task)?.subtasks, hasLength(2));

    controller.state = controller.state.copyWith(
      pendingSubtasks: const <String, Set<String>>{
        't1': <String>{'s2'},
      },
    );

    final TaskItem? filtered = controller.filterTask(task);
    expect(filtered, isNotNull);
    expect(filtered!.subtasks, hasLength(1));
    expect(filtered.subtasks.single.id, 's1');
    expect(filtered.isDone, isTrue);
  });

  test('PendingDeleteController filters tasks', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final PendingDeleteController controller =
        container.read(pendingDeleteControllerProvider.notifier);

    final TaskItem task = TaskItem(
      id: 't1',
      title: 'Parent Task',
      date: DateTime(2026, 1, 1),
    );

    controller.state = controller.state.copyWith(
      pendingTaskIds: const <String>{'t1'},
    );

    expect(controller.filterTask(task), isNull);
    expect(controller.filterTaskList(<TaskItem>[task]), isEmpty);
  });
}
