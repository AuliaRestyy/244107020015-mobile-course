import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/todo_page.dart';
import '../pages/stats_page.dart';
import 'shell_scaffold.dart';

/// Global navigator keys for each branch.
/// These allow navigation within each tab independently.
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _todoNavigatorKey = GlobalKey<NavigatorState>();
final _statsNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter configuration with StatefulShellRoute for bottom navigation.
final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // StatefulShellRoute provides persistent state across branches
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        // ShellScaffold wraps pages with the NavigationBar
        return ShellScaffold(navigationShell: navigationShell);
      },
      branches: [
        // Branch 0: ToDo List (home page)
        StatefulShellBranch(
          navigatorKey: _todoNavigatorKey,
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: TodoPage(),
              ),
            ),
          ],
        ),
        // Branch 1: Statistics page
        StatefulShellBranch(
          navigatorKey: _statsNavigatorKey,
          routes: [
            GoRoute(
              path: '/stats',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: StatsPage(),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);
