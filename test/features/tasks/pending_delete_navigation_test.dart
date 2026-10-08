import 'package:drift/native.dart';
import 'package:flowblock/core/widgets/root_messenger.dart';
import 'package:flowblock/data/db/database.dart' hide Subtask;
import 'package:flowblock/data/db/provider.dart';
import 'package:flowblock/data/task_repository.dart';
import 'package:flowblock/domain/models/task_item.dart';
import 'package:flowblock/features/tasks/pending_delete_controller.dart';
import 'package:flowblock/features/timer/timer_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Detail-navigation survival + race safety + bulk-complete timer stop.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('delete from detail shows Undo on list and restores exactly',
      (WidgetTester tester) async {
    final TaskItem task = TaskItem(
      id: 't1',
      title: 'Exact',
      date: DateTime(2026, 3, 4),
      durationMinutes: 25,
      subtasks: <Subtask>[
        Subtask(
          id: 's1',
          title: 'One',
          durationMinutes: 10,
          isDone: true,
          sortOrder: 0,
          completedAt: DateTime.utc(2026, 3, 3),
        ),
        Subtask(id: 's2', title: 'Two', durationMinutes: 5, sortOrder: 1),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          home: _ListThenDetail(task: task),
        ),
      ),
    );
    // Open detail.
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();
    expect(find.text('Exact'), findsWidgets);
    // Delete from detail: pops immediately, SnackBar must land on list.
    await tester.tap(find.text('delete task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('list: Exact'), findsNothing);
    expect(find.text('Task deleted'), findsOneWidget);
    // Undo restores with subtasks, done, durations, order.
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('list: Exact'), findsOneWidget);
    final BuildContext ctx = tester.element(find.text('list: Exact'));
    final PendingDeleteController ctrl =
        ProviderScope.containerOf(ctx).read(
      pendingDeleteControllerProvider.notifier,
    );
    final TaskItem? restored = ctrl.filterTask(task);
    expect(restored?.subtasks.map((Subtask s) => s.id), <String>['s1', 's2']);
    expect(restored?.subtasks.first.isDone, isTrue);
    expect(restored?.subtasks.first.durationMinutes, 10);
    expect(restored?.subtasks.map((Subtask s) => s.sortOrder), <int>[0, 1]);
  });

  test('Undo after commit does nothing harmful', () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 3, 4, 12)),
      ],
    );
    addTearDown(container.dispose);
    final PendingDeleteController ctrl =
        container.read(pendingDeleteControllerProvider.notifier);
    // No UI: simulate stage bookkeeping then commit then late Undo.
    ctrl.state = ctrl.state.copyWith(pendingTaskIds: const <String>{'t1'});
    ctrl.commitAll();
    // Late Undo must not throw and must leave state empty.
    ctrl.undoTaskDelete('t1');
    expect(ctrl.state.pendingTaskIds, isEmpty);
  });

  test('bulk-completing subtasks stops running subtask timer', () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final DateTime fixed = DateTime.utc(2026, 3, 4, 12);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => fixed),
      ],
    );
    addTearDown(container.dispose);
    final TaskRepository repo = container.read(taskRepositoryProvider);
    await repo.addTask(
      TaskItem(
        id: 'ignored',
        title: 'Parent',
        date: DateTime(2026, 3, 4),
        subtasks: const <Subtask>[
          Subtask(id: 'x', title: 'One', durationMinutes: 25),
          Subtask(id: 'y', title: 'Two', durationMinutes: 25),
        ],
      ),
    );
    TaskItem task = (await repo.watchAll().first).single;
    container
        .read(timerControllerProvider.notifier)
        .start(task: task, subtask: task.subtasks.first);
    expect(container.read(timerControllerProvider), isNotNull);
    await repo.toggleTaskDone(task.id);
    // Watch propagation is async; poll briefly.
    for (int i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (container.read(timerControllerProvider) == null) {
        break;
      }
    }
    expect(container.read(timerControllerProvider), isNull);
    task = (await repo.getById(task.id))!;
    expect(task.isDone, isTrue);
  });
}

class _ListThenDetail extends ConsumerWidget {
  const _ListThenDetail({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> pending =
        ref.watch(pendingDeleteControllerProvider).pendingTaskIds;
    final bool hidden = pending.contains(task.id);
    return Scaffold(
      body: Column(
        children: <Widget>[
          if (!hidden) Text('list: ${task.title}'),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _Detail(taskId: task.id),
              ),
            ),
            child: const Text('open detail'),
          ),
        ],
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          const Text('Exact'),
          TextButton(
            onPressed: () {
              final String id = taskId;
              Navigator.of(context).pop();
              ref
                  .read(pendingDeleteControllerProvider.notifier)
                  .stageTaskDelete(context: context, ref: ref, taskId: id);
            },
            child: const Text('delete task'),
          ),
        ],
      ),
    );
  }
}
