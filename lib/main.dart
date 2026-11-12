import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

import 'app.dart';
import 'core/config/client_config.dart';
import 'core/config/server_config.dart';
import 'core/theme/app_colors.dart';
import 'core/format/formatters.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(appLocale);
  final prefs = await SharedPreferences.getInstance();
  _applyCachedBranding(prefs);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(
    ProviderScope(
      // A failed request should surface as an error state with a retry button, not loop silently.
      retry: (retryCount, error) => null,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const InventoryApp(),
    ),
  );
}

/// Paints the last company's colors before the first frame, so there is no flash of defaults.
void _applyCachedBranding(SharedPreferences prefs) {
  Branding? cached;
  try {
    final config = prefs.getString('client_config');
    final company = prefs.getString('company_slug');
    if (config != null) {
      cached = ClientConfig.fromJson(jsonDecode(config) as Map<String, dynamic>).branding;
    } else if (company != null) {
      final branding = prefs.getString('branding_$company');
      if (branding != null) cached = Branding.fromJson(jsonDecode(branding));
    }
  } catch (_) {
    cached = null;
  }
  if (cached == null) return;
  AppColors.applyPalette(cached.palette);
  BrandingController.initial = cached;
}
