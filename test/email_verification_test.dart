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
import 'package:spendlog_app/screens/verify_email_screen.dart';

/// A signed-in account whose email is unconfirmed is held on the verify
/// screen, and let into the app by the `user` the verify call hands back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpClientAdapter original;
  late _VerifyAdapter adapter;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );

    original = ApiClient.instance.dio.httpClientAdapter;
    adapter = _VerifyAdapter();
    ApiClient.instance.dio.httpClientAdapter = adapter;
  });

  tearDown(() => ApiClient.instance.dio.httpClientAdapter = original);

  const unverified = User(
    uuid: 'u-1',
    name: 'Ada Lovelace',
    email: 'ada@example.com',
    isAdmin: false,
  );

  Future<(BuildContext, GoRouter)> boot(WidgetTester tester) async {
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

    // Past the splash hold, which would otherwise settle into signed-out.
    await tester.pump(const Duration(seconds: 4));

    outer.read<AuthNotifier>().setUser(unverified);
    await tester.pumpAndSettle();

    return (outer, outer.read<GoRouter>());
  }

  String location(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  test('the user model reads email_verified_at', () {
    final json = {'uuid': 'u-1', 'email': 'a@b.c'};

    expect(User.fromJson(json).emailVerified, isFalse);
    expect(
      User.fromJson({...json, 'email_verified_at': '2026-09-29T10:00:00+00:00'})
          .emailVerified,
      isTrue,
    );
  });

  testWidgets('an unverified user is held on the verify screen', (
    tester,
  ) async {
    final (_, router) = await boot(tester);

    expect(location(router), '/verify-email');
    expect(find.byType(VerifyEmailScreen), findsOneWidget);
    expect(find.textContaining('ada@example.com'), findsOneWidget);

    // Nothing else in the app is reachable until the code is accepted.
    router.go('/expenses');
    await tester.pumpAndSettle();
    expect(location(router), '/verify-email');
  });

  testWidgets('a rejected code shows under the field and keeps the gate', (
    tester,
  ) async {
    final (_, router) = await boot(tester);
    adapter.accept = false;

    await tester.enterText(find.byType(TextFormField), '000000');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text(_VerifyAdapter.invalid), findsOneWidget);
    expect(location(router), '/verify-email');
  });

  testWidgets('an accepted code stores the verified user and lets them in', (
    tester,
  ) async {
    final (context, router) = await boot(tester);

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(adapter.lastCode, '123456');
    expect(context.read<AuthNotifier>().state.user!.emailVerified, isTrue);
    expect(location(router), '/');
    expect(find.text('Your email is verified.'), findsOneWidget);
  });
}

/// Answers `POST /email/verify` the way the API does; every other request
/// fails, so the screens behind the gate do not wait on a socket.
class _VerifyAdapter implements HttpClientAdapter {
  static const invalid =
      'That code is not valid. It may have expired — you can request a new one.';

  bool accept = true;
  String? lastCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/email/verify') {
      lastCode = (options.data as Map)['code'] as String?;

      return accept
          ? _json(200, {
              'message': 'Your email is verified.',
              'user': {
                'uuid': 'u-1',
                'name': 'Ada Lovelace',
                'email': 'ada@example.com',
                'is_admin': false,
                'email_verified_at': '2026-09-29T10:00:00+00:00',
              },
            })
          : _json(422, {
              'message': invalid,
              'errors': {
                'code': [invalid],
              },
            });
    }

    return _json(500, {'message': 'unavailable'});
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
