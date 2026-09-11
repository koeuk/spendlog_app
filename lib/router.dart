import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/activity_screen.dart';
import 'screens/admin_settings_screen.dart';
import 'screens/admin_users_screen.dart';
import 'screens/budgets_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/income_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/recurring_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/savings_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/splash_screen.dart';

/// The app's one router, built once and handed [auth] as its
/// `refreshListenable`.
///
/// Built once on purpose. Rebuilding it on every auth change — including the
/// [AuthNotifier.setUser] that follows a profile save — would hand
/// `MaterialApp.router` a brand new [GoRouter], which re-applies
/// `initialLocation` and destroys every tab's navigation state. An
/// [AuthNotifier] is already a `Listenable`, so passing it straight through
/// re-runs `redirect` against the current location and nothing else.
GoRouter buildRouter(AuthNotifier auth) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth,
    // Auth is the only routing rule: signed out belongs on the auth screens,
    // signed in belongs in the app, and restoring belongs on the splash.
    redirect: (context, state) {
      final session = auth.state;

      final onAuthPages =
          state.matchedLocation == '/login' ||
          state.matchedLocation.startsWith('/forgot-password') ||
          state.matchedLocation.startsWith('/reset-password');

      // Returning the location we are already on would be a redirect loop.
      if (session.restoring) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }
      if (!session.signedIn && !onAuthPages) return '/login';
      if (session.signedIn &&
          (onAuthPages || state.matchedLocation == '/splash')) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      // The signed-in app: five tabs behind one bottom bar, each branch
      // keeping its own state when you switch away and back.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardScreen(),
                // Income and savings are reached from the dashboard's cards (and
                // Profile), not from a tab of their own. Nested here so the bar
                // stays put and back returns to the dashboard.
                routes: [
                  GoRoute(
                    path: 'income',
                    builder: (context, state) => const IncomeScreen(),
                  ),
                  GoRoute(
                    path: 'recurring',
                    builder: (context, state) => const RecurringScreen(),
                  ),
                  GoRoute(
                    path: 'savings',
                    builder: (context, state) => const SavingsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/expenses',
                builder: (context, state) => const ExpensesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/budgets',
                builder: (context, state) => const BudgetsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                // Managing categories is occasional and admin-gated, so it sits
                // under Profile rather than spending a tab. Nested, so the bar
                // stays put and back returns to Profile.
                routes: [
                  GoRoute(
                    path: 'categories',
                    builder: (context, state) => const CategoriesScreen(),
                  ),
                  GoRoute(
                    path: 'activity',
                    builder: (context, state) => const ActivityScreen(),
                  ),
                  GoRoute(
                    path: 'admin-users',
                    builder: (context, state) => const AdminUsersScreen(),
                  ),
                  GoRoute(
                    path: 'admin-settings',
                    builder: (context, state) => const AdminSettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
