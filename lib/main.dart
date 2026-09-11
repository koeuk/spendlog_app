import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'l10n/l10n.dart';
import 'providers/app_providers.dart';
import 'providers/branding_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'theme.dart';
import 'widgets/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before the first frame, so no screen paints English and then flips.
  await L10n.load();

  runApp(MultiProvider(providers: appProviders(), child: const SpendLogApp()));
}

class SpendLogApp extends StatelessWidget {
  const SpendLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The admin's look, restored from the last run and refreshed on launch.
    final branding = context.watch<BrandingNotifier>().state;
    final locale = context.watch<LocaleNotifier>().value;

    return MaterialApp.router(
      title: branding.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(branding, locale),
      darkTheme: AppTheme.dark(branding, locale),
      locale: Locale(locale),
      supportedLocales: const [Locale('en'), Locale('km')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: context.watch<ThemeModeNotifier>().value,
      // Read, not watched: there is only ever one router, and rebuilding this
      // widget for a theme or language change must not hand over a new one.
      routerConfig: context.read<GoRouter>(),
      // One gradient ground beneath every route; scaffolds are transparent.
      // Keyed on the language: tr() reads a static, so a switch has to rebuild
      // every screen rather than wait for each to notice on its own.
      builder: (context, child) => KeyedSubtree(
        key: ValueKey(locale),
        child: GlassBackdrop(child: child!),
      ),
    );
  }
}
