import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'utils/format.dart';
import 'screens/activity_screen.dart';
import 'screens/admin_settings_screen.dart';
import 'screens/admin_users_screen.dart';
import 'screens/borrowing_detail_screen.dart';
import 'screens/borrowings_screen.dart';
import 'screens/budgets_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/income_screen.dart';
import 'screens/income_sources_screen.dart';
import 'screens/login_screen.dart';
import 'screens/preferences_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/recurring_screen.dart';
import 'screens/register_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/savings_plan_screen.dart';
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
          state.matchedLocation == '/register' ||
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
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
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
                    // The month's plan and the savings history, behind the
                    // month card. Nested so back returns to Savings.
                    routes: [
                      GoRoute(
                        path: 'plan',
                        builder: (context, state) => SavingsPlanScreen(
                          month:
                              state.uri.queryParameters['month'] ?? currentYm(),
                          planned: state.uri.queryParameters['planned'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'borrowings',
                    builder: (context, state) => const BorrowingsScreen(),
                    // One borrowing's page — the ledger, and every action on
                    // the debt. Nested so back returns to the list.
                    routes: [
                      GoRoute(
                        path: ':uuid',
                        builder: (context, state) => BorrowingDetailScreen(
                          uuid: state.pathParameters['uuid']!,
                        ),
                      ),
                    ],
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
                  // The names income is filed under. Beside categories, for
                  // the same reason: an occasional tidy-up, not a tab.
                  GoRoute(
                    path: 'income-sources',
                    builder: (context, state) => const IncomeSourcesScreen(),
                  ),
                  GoRoute(
                    path: 'admin-users',
                    builder: (context, state) => const AdminUsersScreen(),
                  ),
                  // The account's own currency and colours, for everyone.
                  GoRoute(
                    path: 'currency',
                    builder: (context, state) =>
                        const CurrencyPreferenceScreen(),
                  ),
                  GoRoute(
                    path: 'colours',
                    builder: (context, state) =>
                        const ColourPreferenceScreen(),
                  ),
                  // The app-wide settings, one page per subject rather than
                  // one page of tabs. Settings lists them; these are where
                  // the rows land.
                  GoRoute(
                    path: 'app/spending',
                    builder: (context, state) =>
                        const SpendingSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'app/guidance',
                    builder: (context, state) =>
                        const GuidanceSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'app/faqs',
                    builder: (context, state) => const FaqSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'app/branding',
                    builder: (context, state) =>
                        const BrandingSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'app/colours',
                    builder: (context, state) => const ColourSettingsScreen(),
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
