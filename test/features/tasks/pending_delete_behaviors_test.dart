import 'package:flowblock/core/widgets/root_messenger.dart';
import 'package:flowblock/data/task_repository.dart';
import 'package:flowblock/domain/models/task_item.dart';
import 'package:flowblock/features/tasks/pending_delete_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRepo implements TaskRepository {
  int deleteTaskCalls = 0;
  int deleteSubtaskCalls = 0;
  final List<String> deletedTasks = <String>[];

  @override
  Future<void> deleteTask(String id) async {
    deleteTaskCalls++;
    deletedTasks.add(id);
  }

  @override
  Future<void> deleteSubtask(String taskId, String subtaskId) async {
    deleteSubtaskCalls++;
  }

  @override
  Stream<List<TaskItem>> watchAll() => Stream<List<TaskItem>>.value(const <TaskItem>[]);
  @override
  Stream<TaskItem?> watchById(String id) => Stream<TaskItem?>.value(null);
  @override
  Future<TaskItem?> getById(String id) async => null;
  @override
  Future<void> addTask(TaskItem draft) async {}
  @override
  Future<void> updateTask(TaskItem task) async {}
  @override
  Future<void> updateTaskWithSubtasks(TaskItem task) async {}
  @override
  Future<void> setTaskDone(String id, bool isDone) async {}
  @override
  Future<void> toggleTaskDone(String id) async {}
  @override
  Future<void> setSubtaskDone(String t, String s, bool d) async {}
  @override
  Future<void> addSubtask(String t, {required String title, int? durationMinutes}) async {}
  @override
  Future<void> updateSubtask(String t, Subtask s) async {}
  @override
  Future<void> reorderSubtasks(String t, List<String> ids) async {}
  @override
  Future<void> reorderTasks(List<String> ids) async {}
}

Widget app(FakeRepo fake, Widget home) {
  return ProviderScope(
    overrides: [
      taskRepositoryProvider.overrideWithValue(fake),
    ],
    child: MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      home: home,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Undo cancels with zero database calls', (WidgetTester tester) async {
    final FakeRepo fake = FakeRepo();
    late BuildContext captured;
    await tester.pumpWidget(
      app(fake, Builder(builder: (BuildContext c) {
        captured = c;
        return const Scaffold(body: Text('home'));
      })),
    );
    final ProviderContainer container = ProviderScope.containerOf(captured);
    container
        .read(pendingDeleteControllerProvider.notifier)
        .stageTaskDelete(context: captured, ref: container, taskId: 't1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Task deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(fake.deleteTaskCalls, 0);
    expect(
      container.read(pendingDeleteControllerProvider).pendingTaskIds,
      isEmpty,
    );
  });

  testWidgets('SnackBar close without Undo commits', (WidgetTester tester) async {
    final FakeRepo fake = FakeRepo();
    late BuildContext captured;
    await tester.pumpWidget(
      app(fake, Builder(builder: (BuildContext c) {
        captured = c;
        return const Scaffold(body: Text('home'));
      })),
    );
    final ProviderContainer container = ProviderScope.containerOf(captured);
    container
        .read(pendingDeleteControllerProvider.notifier)
        .stageTaskDelete(context: captured, ref: container, taskId: 't1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 500));
    // Let the async delete land.
    await tester.pump(const Duration(milliseconds: 100));
    expect(fake.deleteTaskCalls, 1);
  });

  testWidgets('lifecycle paused/detached commit; inactive/hidden do not',
      (WidgetTester tester) async {
    final FakeRepo fake = FakeRepo();
    late BuildContext captured;
    await tester.pumpWidget(
      app(fake, Builder(builder: (BuildContext c) {
        captured = c;
        return const Scaffold(body: Text('home'));
      })),
    );
    final ProviderContainer container = ProviderScope.containerOf(captured);
    final PendingDeleteController ctrl =
        container.read(pendingDeleteControllerProvider.notifier);

    ctrl.stageTaskDelete(context: captured, ref: container, taskId: 't1');
    await tester.pump();
    ctrl.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pump();
    expect(fake.deleteTaskCalls, 0);
    ctrl.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await tester.pump();
    expect(fake.deleteTaskCalls, 0);
    ctrl.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fake.deleteTaskCalls, 1);

    ctrl.stageTaskDelete(context: captured, ref: container, taskId: 't2');
    await tester.pump();
    ctrl.didChangeAppLifecycleState(AppLifecycleState.detached);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fake.deleteTaskCalls, 2);
  });

  testWidgets('second delete commits the first immediately',
      (WidgetTester tester) async {
    final FakeRepo fake = FakeRepo();
    late BuildContext captured;
    await tester.pumpWidget(
      app(fake, Builder(builder: (BuildContext c) {
        captured = c;
        return const Scaffold(body: Text('home'));
      })),
    );
    final ProviderContainer container = ProviderScope.containerOf(captured);
    final PendingDeleteController ctrl =
        container.read(pendingDeleteControllerProvider.notifier);
    ctrl.stageTaskDelete(context: captured, ref: container, taskId: 'a');
    await tester.pump();
    ctrl.stageTaskDelete(context: captured, ref: container, taskId: 'b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fake.deletedTasks, contains('a'));
    expect(fake.deleteTaskCalls, 1);
    expect(
      container.read(pendingDeleteControllerProvider).pendingTaskIds,
      contains('b'),
    );
  });

  testWidgets('disposing a widget does not commit', (WidgetTester tester) async {
    final FakeRepo fake = FakeRepo();
    late BuildContext captured;
    await tester.pumpWidget(
      app(
        fake,
        _Watcher(onReady: (BuildContext c) {
          captured = c;
        }),
      ),
    );
    final ProviderContainer container = ProviderScope.containerOf(captured);
    container
        .read(pendingDeleteControllerProvider.notifier)
        .stageTaskDelete(context: captured, ref: container, taskId: 't1');
    await tester.pump();
    expect(find.text('Task deleted'), findsOneWidget);
    // Remove the watching widget; provider itself stays alive.
    await tester.pumpWidget(app(fake, const Scaffold(body: Text('other'))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(fake.deleteTaskCalls, 0);
  });
}

class _Watcher extends ConsumerWidget {
  const _Watcher({required this.onReady});

  final ValueChanged<BuildContext> onReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pendingDeleteControllerProvider);
    onReady(context);
    return const Scaffold(body: Text('watching'));
  }
}
