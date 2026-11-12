import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'server_url';
const _definedUrl = String.fromEnvironment('API_BASE_URL');

/// Overridden in `main()` once SharedPreferences is ready.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

String defaultServerUrl() {
  if (_definedUrl.isNotEmpty) return _definedUrl;
  // The Android emulator reaches the host machine through 10.0.2.2.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }
  return 'http://localhost:3000';
}

/// Adds the scheme when missing and drops trailing slashes and a trailing `/api`.
String normalizeServerUrl(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return '';
  if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(value)) {
    value = 'http://$value';
  }
  value = value.replaceAll(RegExp(r'/+$'), '');
  value = value.replaceFirst(RegExp(r'/api$', caseSensitive: false), '');
  return value;
}

bool isValidServerUrl(String raw) {
  final uri = Uri.tryParse(normalizeServerUrl(raw));
  return uri != null && uri.hasAuthority && uri.host.isNotEmpty;
}

class ServerUrlNotifier extends Notifier<String> {
  @override
  String build() =>
      ref.watch(sharedPreferencesProvider).getString(_prefsKey) ??
      defaultServerUrl();

  Future<void> update(String raw) async {
    final value = normalizeServerUrl(raw);
    if (value.isEmpty) return;
    state = value;
    await ref.read(sharedPreferencesProvider).setString(_prefsKey, value);
  }
}

final serverUrlProvider =
    NotifierProvider<ServerUrlNotifier, String>(ServerUrlNotifier.new);
