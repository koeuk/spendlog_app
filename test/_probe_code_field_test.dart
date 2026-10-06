// Throwaway: renders the two code screens to PNG so the field can be looked at.
// Delete when done.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:spendlog_app/l10n/l10n.dart';
import 'package:spendlog_app/providers/app_providers.dart';
import 'package:spendlog_app/screens/reset_password_screen.dart';
import 'package:spendlog_app/screens/verify_email_screen.dart';
import 'package:spendlog_app/theme.dart';

const _fontDir = '/home/koeuk/.local/share/com.spendlog.spendlog_app';
const _iconFont =
    '/home/koeuk/snap/flutter/common/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';

Future<void> _loadFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final entry in Directory(_fontDir).listSync().whereType<File>()) {
    final name = entry.uri.pathSegments.last;
    if (!name.endsWith('.ttf')) continue;

    // google_fonts registers under the part before the hash.
    final family = name.split('_').take(2).join('_');
    await (FontLoader(family)
          ..addFont(Future.value(entry.readAsBytesSync().buffer.asByteData())))
        .load();
  }

  await (FontLoader('MaterialIcons')
        ..addFont(
          Future.value(File(_iconFont).readAsBytesSync().buffer.asByteData()),
        ))
      .load();
}

Future<void> _shoot(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  testWidgets('render the code screens', (tester) async {
    await _loadFonts();
    L10n.locale = 'en';
    await L10n.load();

    tester.view.physicalSize = const Size(390 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final shot in [
      ('reset', const ResetPasswordScreen(email: 'koeukkos@gmail.com')),
      ('verify', const VerifyEmailScreen()),
    ]) {
      final key = GlobalKey();

      await tester.pumpWidget(
        MultiProvider(
          providers: appProviders(),
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              theme: AppTheme.light(),
              home: shot.$2,
            ),
          ),
        ),
      );

      // Past the 3s launch restore, or its timer is still pending at the end.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));

      await _shoot(tester, key, '/tmp/code_${shot.$1}.png');
    }
  });
}
