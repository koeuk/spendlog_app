import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:spendlog_app/api/api_client.dart';
import 'package:spendlog_app/main.dart';
import 'package:spendlog_app/models/user.dart';
import 'package:spendlog_app/providers/app_providers.dart';
import 'package:spendlog_app/providers/auth_provider.dart';
import 'package:spendlog_app/screens/categories_screen.dart';
import 'package:spendlog_app/screens/expense_form_page.dart';
import 'package:spendlog_app/screens/income_form_page.dart';
import 'package:spendlog_app/screens/income_sources_screen.dart';
import 'package:spendlog_app/screens/recurring_form_page.dart';
import 'package:spendlog_app/widgets/common.dart';

/// Every page reached from the Menu sheet or the Settings list must offer a
/// way back, and it must land where the person came from.
///
/// Checked against the real router rather than by reading the route table:
/// `glassBack` hides itself when there is nothing to pop, so a page nested
/// under the wrong parent loses its back arrow silently — it analyzes clean
/// and only shows up as a dead end on a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpClientAdapter original;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );

    // Every screen fetches on mount. Answering them all with one failure is
    // enough: a page renders its bar, and so its back arrow, either way.
    original = ApiClient.instance.dio.httpClientAdapter;
    ApiClient.instance.dio.httpClientAdapter = _FailingAdapter();
  });

  tearDown(() => ApiClient.instance.dio.httpClientAdapter = original);

  /// path → where its back arrow should land.
  const nested = <String, String>{
    // Reached from the Menu sheet, which sits over the dashboard.
    '/income': '/',
    '/recurring': '/',
    '/savings': '/',
    '/borrowings': '/',
    // Reached from the Settings list.
    '/profile/categories': '/profile',
    '/profile/activity': '/profile',
    '/profile/income-sources': '/profile',
    '/profile/admin-users': '/profile',
    '/profile/currency': '/profile',
    '/profile/colours': '/profile',
    '/profile/app/spending': '/profile',
    '/profile/app/guidance': '/profile',
    '/profile/app/faqs': '/profile',
    '/profile/app/branding': '/profile',
    '/profile/app/colours': '/profile',
  };

  /// The four in the nav bar, plus Settings: nothing sits beneath them to pop
  /// to, so a back arrow there would be a button that does nothing.
  const tabRoots = <String>['/', '/expenses', '/budgets', '/reports'];

  Future<GoRouter> boot(WidgetTester tester) async {
    late BuildContext outer;

    await tester.pumpWidget(
      MultiProvider(
        providers: appProviders(),
        child: Builder(
          builder: (context) {
            outer = context;

            return const SpendLogApp();
          },
        ),
      ),
    );

    // Past the splash hold first: the launch restore settles into signed-out
    // three seconds in, and would wipe a user signed in before it.
    await tester.pump(const Duration(seconds: 4));

    outer.read<AuthNotifier>().setUser(
      const User(
        uuid: 'u-1',
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        // Admin, so the app-settings rows and Users are routable.
        isAdmin: true,
      ),
    );
    await tester.pumpAndSettle();

    return outer.read<GoRouter>();
  }

  String location(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  for (final entry in nested.entries) {
    testWidgets('${entry.key} goes back to ${entry.value}', (tester) async {
      final router = await boot(tester);

      router.go(entry.key);
      await tester.pumpAndSettle();
      expect(location(router), entry.key, reason: 'never arrived');

      final back = find.byType(GlassBackButton);
      expect(back, findsOneWidget, reason: '${entry.key} has no way back');

      await tester.tap(back);
      await tester.pumpAndSettle();

      expect(location(router), entry.value);
    });
  }

  for (final path in tabRoots) {
    testWidgets('$path shows no back arrow', (tester) async {
      final router = await boot(tester);

      router.go(path);
      await tester.pumpAndSettle();

      expect(
        find.byType(GlassBackButton),
        findsNothing,
        reason: '$path is a tab root with nothing beneath it',
      );
    });
  }

  /// The add/edit forms are pushed onto the root navigator rather than routed
  /// to, so their back arrow answers to a different navigator than the pages
  /// above. Each must still close and leave the page it was opened from.
  final forms = <String, void Function(BuildContext)>{
    'category': (context) => showCategoryForm(context),
    'income source': (context) => showIncomeSourceSheet(context),
    'recurring rule': (context) => showRecurringForm(context),
    'expense': (context) => showExpenseForm(context),
    'income': (context) => showIncomeForm(context),
  };

  for (final entry in forms.entries) {
    testWidgets('the ${entry.key} form closes onto the page beneath', (
      tester,
    ) async {
      final router = await boot(tester);

      router.go('/profile/categories');
      await tester.pumpAndSettle();

      entry.value(tester.element(find.byType(CategoriesScreen)));
      await tester.pumpAndSettle();

      // The form's own bar, over the page that opened it.
      final back = find.byType(GlassBackButton);
      expect(back, findsOneWidget, reason: 'the form has no way back');

      await tester.tap(back);
      await tester.pumpAndSettle();

      // Back on the page, not somewhere else in the app.
      expect(find.byType(CategoriesScreen), findsOneWidget);
      expect(location(router), '/profile/categories');
    });
  }

  testWidgets('/profile goes back to the dashboard', (tester) async {
    final router = await boot(tester);

    router.go('/profile');
    await tester.pumpAndSettle();

    // A tab root like the four above, but reached from the Menu sheet like a
    // pushed page — so it carries an arrow of its own, pointing home.
    final back = find.byType(GlassBackButton);
    expect(back, findsOneWidget);

    await tester.tap(back);
    await tester.pumpAndSettle();

    expect(location(router), '/');
  });
}

/// Answers every request with a 500 and a Laravel-shaped body, so no screen
/// waits on a socket that is not there.
class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'message': 'unavailable'}),
      500,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
