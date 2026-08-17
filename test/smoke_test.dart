import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendlog_app/api/api_client.dart';
import 'package:spendlog_app/api/env.dart';
import 'package:spendlog_app/main.dart';
import 'package:spendlog_app/models/user.dart';
import 'package:spendlog_app/providers/auth_provider.dart';
import 'package:spendlog_app/router.dart';
import 'package:spendlog_app/screens/budgets_screen.dart';
import 'package:spendlog_app/screens/dashboard_screen.dart';
import 'package:spendlog_app/screens/expenses_screen.dart';
import 'package:spendlog_app/screens/profile_screen.dart';
import 'package:spendlog_app/utils/format.dart';

/// Compiles the entire widget graph (every screen is reachable from these
/// imports) and pins the pure helpers — a cheap tripwire until real widget
/// tests exist.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // No stored token, so the startup restore settles into signed-out without
    // reaching for the keychain or the network.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  test('app graph compiles', () {
    expect(const SpendLogApp(), isNotNull);
    expect(const DashboardScreen(), isNotNull);
    expect(const ExpensesScreen(), isNotNull);
    expect(const BudgetsScreen(), isNotNull);
    expect(const ProfileScreen(), isNotNull);
  });

  test('month helpers speak the API format', () {
    expect(monthLabel('2026-08'), 'August 2026');
    expect(shiftMonth('2026-01', -1), '2025-12');
    expect(shiftMonth('2026-12', 1), '2027-01');
    expect(dayLabel('2026-08-17'), 'Aug 17');
    expect(money('12.50'), '\$12.50');
  });

  test('an overspend is shown without its minus sign', () {
    // The API reports `remaining: "-6.00"` when over; the screens supply the
    // word "over", so the sign must not be printed as well.
    expect(moneyAbs('-6.00'), '\$6.00');
    expect(moneyAbs('6.00'), '\$6.00');
  });

  test('the API base URL is a reachable address carrying the port', () {
    final url = Uri.parse(Env.baseUrl);

    // This file has been flattened to placeholder hosts before, which compiles
    // and analyzes clean but points every request at nowhere.
    expect(url.scheme, anyOf('http', 'https'));
    expect(url.host, matches(RegExp(r'^[a-z0-9.\-]+$')));
    expect(url.host, isNot(contains('[')));
    expect(url.hasPort, isTrue, reason: 'the PORT knob must reach the URL');
    expect(url.path, '/api/v1');
  });

  test('the router survives an auth change', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = container.read(routerProvider);
    await pumpEventQueue();

    container.read(authProvider.notifier).setUser(
          const User(
            uuid: 'u-1',
            name: 'Ada Lovelace',
            email: 'ada@example.com',
            isAdmin: false,
          ),
        );
    await pumpEventQueue();

    // Rebuilding the router on an auth change re-applies `initialLocation`
    // and throws away all four tabs' navigation state — so saving a profile
    // would bounce the user back to the dashboard.
    expect(identical(before, container.read(routerProvider)), isTrue);
  });

  group('a rejected token', () {
    late HttpClientAdapter original;

    setUp(() {
      original = ApiClient.instance.dio.httpClientAdapter;
      ApiClient.instance.dio.httpClientAdapter = _StatusAdapter(401);
    });

    tearDown(() => ApiClient.instance.dio.httpClientAdapter = original);

    test('drops the session when an authenticated call is refused', () async {
      final fired = ApiClient.instance.onUnauthorized.first;

      await expectLater(
        ApiClient.instance.dio.get<void>('/expenses'),
        throwsA(isA<DioException>()),
      );

      // Times out — and fails — if the interceptor stayed quiet.
      await fired.timeout(const Duration(seconds: 2));
    });

    test('stays quiet for the endpoints reached without a token', () async {
      var fired = false;
      final subscription =
          ApiClient.instance.onUnauthorized.listen((_) => fired = true);
      addTearDown(subscription.cancel);

      await expectLater(
        ApiClient.instance.dio.post<void>('/login'),
        throwsA(isA<DioException>()),
      );
      await pumpEventQueue();

      // Signing the user out over a failed *sign in* would be nonsense.
      expect(fired, isFalse);
    });
  });
}

/// A Dio adapter that answers everything with one status and a Laravel-shaped
/// error body.
class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.statusCode);

  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        '{"message":"Unauthenticated."}',
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
