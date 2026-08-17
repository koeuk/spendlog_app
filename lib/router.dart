import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/budgets_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/splash_screen.dart';

/// Turns auth changes into a `refreshListenable` tick.
///
/// The router must be built exactly once. Watching [authProvider] here instead
/// would hand `MaterialApp.router` a brand new [GoRouter] on every auth
/// change — including the [AuthNotifier.setUser] that follows a profile save —
/// which re-applies `initialLocation` and destroys all four tabs' navigation
/// state. Refreshing only re-runs `redirect` against the current location.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    // Auth is the only routing rule: signed out belongs on the auth screens,
    // signed in belongs in the app, and restoring belongs on the splash.
    redirect: (context, state) {
      // Read rather than watch: the listenable above drives re-evaluation.
      final auth = ref.read(authProvider);

      final onAuthPages = state.matchedLocation == '/login' ||
          state.matchedLocation.startsWith('/forgot-password') ||
          state.matchedLocation.startsWith('/reset-password');

      // Returning the location we are already on would be a redirect loop.
      if (auth.restoring) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }
      if (!auth.signedIn && !onAuthPages) return '/login';
      if (auth.signedIn && (onAuthPages || state.matchedLocation == '/splash')) return '/';

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) =>
            ResetPasswordScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
      // The signed-in app: four tabs behind one bottom bar, each branch
      // keeping its own state when you switch away and back.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/expenses', builder: (context, state) => const ExpensesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/budgets', builder: (context, state) => const BudgetsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);

  return router;
});
