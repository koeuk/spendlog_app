import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/branding_provider.dart';
import 'providers/theme_provider.dart';
import 'router.dart';
import 'theme.dart';
import 'widgets/glass.dart';

void main() {
  runApp(const ProviderScope(child: SpendLogApp()));
}

class SpendLogApp extends ConsumerWidget {
  const SpendLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The admin's look, restored from the last run and refreshed on launch.
    final branding = ref.watch(brandingProvider);

    return MaterialApp.router(
      title: branding.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(branding),
      darkTheme: AppTheme.dark(branding),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      // One gradient ground beneath every route; scaffolds are transparent.
      builder: (context, child) => GlassBackdrop(child: child!),
    );
  }
}
