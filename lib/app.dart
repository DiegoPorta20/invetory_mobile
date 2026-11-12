import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_controller.dart';
import 'core/config/client_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class InventoryApp extends ConsumerStatefulWidget {
  const InventoryApp({super.key});

  @override
  ConsumerState<InventoryApp> createState() => _InventoryAppState();
}

class _InventoryAppState extends ConsumerState<InventoryApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authControllerProvider.notifier).restore());
  }

  @override
  Widget build(BuildContext context) {
    // A new key rebuilds the whole tree, so every widget re-reads the active palette.
    final version = ref.watch(brandVersionProvider);
    final branding = ref.watch(brandingProvider);
    return KeyedSubtree(
      key: ValueKey(version),
      child: MaterialApp.router(
        title: branding.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: ref.watch(routerProvider),
        locale: const Locale('es', 'PE'),
        supportedLocales: const [Locale('es', 'PE'), Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
