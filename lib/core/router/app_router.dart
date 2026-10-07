import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/mini_timer_bar.dart';
import '../../features/tasks/task_form_sheet.dart';
import '../../features/tasks/today_screen.dart';
import '../../features/upcoming/upcoming_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/tasks/task_detail_screen.dart';
import '../../features/timer/timer_screen.dart';

/// go_router setup: a [ShellRoute] keeps the bottom nav visible on the three
/// main tabs, while detail and timer screens cover it as full pages.
final appRouterProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return AppShell(child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) {
              return const TodayScreen();
            },
          ),
          GoRoute(
            path: '/upcoming',
            builder: (BuildContext context, GoRouterState state) {
              return const UpcomingScreen();
            },
          ),
          GoRoute(
            path: '/settings',
            builder: (BuildContext context, GoRouterState state) {
              return const SettingsScreen();
            },
          ),
        ],
      ),
      GoRoute(
        path: '/task/:id',
        builder: (BuildContext context, GoRouterState state) {
          return TaskDetailScreen(taskId: state.pathParameters['id'] ?? '');
        },
      ),
      GoRoute(
        path: '/timer',
        builder: (BuildContext context, GoRouterState state) {
          final Map<String, String> query = state.uri.queryParameters;
          return TimerScreen(
            taskId: query['taskId'],
            subtaskId: query['subtaskId'],
          );
        },
      ),
    ],
  );
});

/// App shell: persistent bottom navigation with the mini timer bar pinned
/// above it, plus the add-task FAB shown only on the Today tab.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String location = GoRouterState.of(context).uri.path;
    final int index =
        location == '/upcoming' ? 1 : location == '/settings' ? 2 : 0;
    return Scaffold(
      body: SafeArea(child: child),
      floatingActionButton: index == 0
          ? FloatingActionButton(
              tooltip: 'Add task',
              onPressed: () => showTaskFormSheet(context),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const MiniTimerBar(),
          NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (int value) {
              switch (value) {
                case 0:
                  context.go('/');
                case 1:
                  context.go('/upcoming');
                case 2:
                  context.go('/settings');
              }
            },
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.today_outlined),
                selectedIcon: Icon(Icons.today),
                label: 'Today',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Upcoming',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
