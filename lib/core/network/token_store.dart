import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the session tokens in the platform keystore.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage;
  String? _access;
  String? _refresh;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      // A stuck keystore must not hold the splash screen forever.
      const limit = Duration(seconds: 4);
      _access = await _storage.read(key: _accessKey).timeout(limit);
      _refresh = await _storage.read(key: _refreshKey).timeout(limit);
    } catch (_) {
      // A corrupted or unavailable keystore just means the user signs in again.
      _access = null;
      _refresh = null;
    }
    _loaded = true;
  }

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  bool get hasSession => _refresh != null || _access != null;

  Future<void> save({String? access, String? refresh}) async {
    if (access != null) {
      _access = access;
      await _write(_accessKey, access);
    }
    if (refresh != null) {
      _refresh = refresh;
      await _write(_refreshKey, refresh);
    }
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (_) {}
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }
}
