import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/l10n.dart';
import 'providers/branding_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'router.dart';
import 'theme.dart';
import 'widgets/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before the first frame, so no screen paints English and then flips.
  await L10n.load();

  runApp(const ProviderScope(child: SpendLogApp()));
}

class SpendLogApp extends ConsumerWidget {
  const SpendLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The admin's look, restored from the last run and refreshed on launch.
    final branding = ref.watch(brandingProvider);
    final locale = ref.watch(localeProvider);

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
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      // One gradient ground beneath every route; scaffolds are transparent.
      // Keyed on the language: tr() reads a static, so a switch has to rebuild
      // every screen rather than wait for each to notice on its own.
      builder: (context, child) =>
          KeyedSubtree(key: ValueKey(locale), child: GlassBackdrop(child: child!)),
    );
  }
}
