import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spendlog_app/api/api_client.dart';
import 'package:spendlog_app/main.dart';
import 'package:spendlog_app/models/user.dart';
import 'package:spendlog_app/providers/app_providers.dart';
import 'package:spendlog_app/providers/auth_provider.dart';
import 'package:spendlog_app/widgets/common.dart';

/// The dashboard's greeting collapses as the cards rise under it, which the
/// analyzer cannot check: a header that overflows its own extent, or one that
/// lets the name scroll away, both compile.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpClientAdapter original;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );

    original = ApiClient.instance.dio.httpClientAdapter;
    ApiClient.instance.dio.httpClientAdapter = _DashboardAdapter();
  });

  tearDown(() => ApiClient.instance.dio.httpClientAdapter = original);

  Future<void> boot(WidgetTester tester) async {
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

    // Past the splash hold: the launch restore settles into signed-out three
    // seconds in and would wipe a user signed in ahead of it.
    await tester.pump(const Duration(seconds: 4));

    outer.read<AuthNotifier>().setUser(
      const User(
        uuid: 'u-1',
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        isAdmin: false,
        // Verified, or the router holds the session on /verify-email.
        emailVerifiedAt: '2026-01-01T00:00:00+00:00',
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the greeting collapses and keeps the name', (tester) async {
    await boot(tester);

    // The dashboard is the opening tab, so it is already on screen.
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.byType(UserAvatar), findsWidgets);

    final greeting = find.textContaining(
      RegExp('Good (morning|afternoon|evening)'),
    );
    expect(greeting, findsOneWidget, reason: 'the header starts expanded');

    final headerBefore = tester.getSize(find.byType(UserAvatar).first);

    // Scroll the cards up under the header.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
    await tester.pumpAndSettle();

    // The photo shrinks...
    final headerAfter = tester.getSize(find.byType(UserAvatar).first);
    expect(
      headerAfter.height,
      lessThan(headerBefore.height),
      reason: 'the photo should shrink as the header collapses',
    );

    // ...and the name rides it down rather than scrolling away with the cards.
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  testWidgets('the header lays out at a small window', (tester) async {
    // A short, narrow window is where anything that mis-measures its own
    // extent gives itself away — 320x568 is the smallest phone still in use.
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await boot(tester);

    // An overflow reaches the test as a framework error, not a failed
    // expectation, so it has to be asked for by name: leave this out and the
    // dashboard can overflow while the test still reports green.
    expect(tester.takeException(), isNull);
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });
}

/// Answers /dashboard with a full, plausible payload and everything else with
/// a 500 — the cards below only need to build, not to be right.
class _DashboardAdapter implements HttpClientAdapter {
  static final _dashboard = {
    'data': {
      'today': {'date': '2026-09-29', 'total': '12.50'},
      'current_month': '2026-09',
      'budget_month': '2026-09',
      'breakdown_month': '2026-09',
      'summary': {
        'month': '2026-09',
        'overall': {
          'spent': '420.00',
          'percent': 84,
          'bar_percent': 84,
          'status': 'under',
          'budget': '500.00',
          'remaining': '80.00',
        },
        'categories': <dynamic>[],
      },
      'breakdown': [
        {
          'uuid': 'c-1',
          'name': 'Food',
          'color': 'emerald',
          'spent': '220.00',
          'share': 52,
        },
      ],
      'recent': [
        {
          'uuid': 'e-1',
          'item': 'Coffee',
          'price': '2.50',
          'spent_on': '2026-09-29',
        },
      ],
      'income': {'total': '900.00'},
      'balance': '480.00',
      'savings': {
        'month': '2026-09',
        'planned': '100.00',
        'saved_this_month': '60.00',
        'percent': 60,
        'total_saved': '1240.00',
      },
    },
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final isDashboard = options.path.startsWith('/dashboard');

    return ResponseBody.fromString(
      jsonEncode(isDashboard ? _dashboard : {'message': 'unavailable'}),
      isDashboard ? 200 : 500,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
