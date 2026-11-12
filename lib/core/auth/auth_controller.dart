import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/models.dart';
import '../config/client_config.dart';
import '../config/server_config.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../network/token_store.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: () => ref.read(serverUrlProvider),
    tokens: ref.watch(tokenStoreProvider),
    onSessionExpired: () =>
        ref.read(authControllerProvider.notifier).expireSession(),
  );
});

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState(this.status, [this.user]);

  final AuthStatus status;
  final AppUser? user;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState(AuthStatus.unknown);

  ApiClient get _api => ref.read(apiClientProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  /// Restores the previous session on app start.
  Future<void> restore() async {
    await _tokens.load();
    if (!_tokens.hasSession) {
      state = const AuthState(AuthStatus.unauthenticated);
      return;
    }
    try {
      await _enter();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        try {
          if (await _api.refreshSession()) {
            await _enter();
            return;
          }
        } on ApiException {
          // The refresh failed for a non-auth reason: treat it like an offline start below.
          if (_enterWithCachedUser()) return;
        }
        await _tokens.clear();
        state = const AuthState(AuthStatus.unauthenticated);
        return;
      }
      // Offline or server down: keep the user signed in; each screen shows its own
      // error state with a retry until the connection is back.
      if (!_enterWithCachedUser()) {
        state = const AuthState(AuthStatus.unauthenticated);
      }
    }
  }

  static const _cachedUserKey = 'cached_user';

  /// Signs in with the current session: the user first, then what their company lets them do.
  Future<void> _enter() async {
    final user = await _fetchMe();
    await _loadConfig();
    state = AuthState(AuthStatus.authenticated, user);
  }

  Future<void> _loadConfig() async {
    final config = ref.read(clientConfigProvider.notifier);
    final json = await _api.get('/api/config') as Map<String, dynamic>;
    config.accept(json);
    final slug = (json['company'] as Map?)?['slug'];
    if (slug is String && json['branding'] is Map<String, dynamic>) {
      config.cacheBranding(slug, json['branding'] as Map<String, dynamic>);
    }
  }

  bool _enterWithCachedUser() {
    final raw = ref.read(sharedPreferencesProvider).getString(_cachedUserKey);
    if (raw == null) return false;
    if (!ref.read(clientConfigProvider.notifier).restoreCached()) return false;
    try {
      final user = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      state = AuthState(AuthStatus.authenticated, user);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _cacheUser(AppUser user) => ref
      .read(sharedPreferencesProvider)
      .setString(
        _cachedUserKey,
        jsonEncode({
          'id': user.id,
          'email': user.email,
          'name': user.name,
          'role': user.role,
          'isActive': user.isActive,
        }),
      );

  Future<AppUser> _fetchMe() async {
    final user =
        AppUser.fromJson(await _api.get('/api/auth/me') as Map<String, dynamic>);
    await _cacheUser(user);
    return user;
  }

  Future<void> login(String company, String email, String password) async {
    final slug = company.trim().toLowerCase();
    try {
      final json = await _api.login(slug, email, password);
      final user = AppUser.fromJson(json);
      await _cacheUser(user);
      await _loadConfig();
      state = AuthState(AuthStatus.authenticated, user);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        throw const ApiException(
          statusCode: 401,
          code: 'INVALID_CREDENTIALS',
          message: 'Empresa, correo o contraseña incorrectos.',
        );
      }
      if (error.statusCode == 403) {
        throw const ApiException(
          statusCode: 403,
          code: 'COMPANY_SUSPENDED',
          message: 'Esta empresa está suspendida. Contacta a tu proveedor.',
        );
      }
      if (error.statusCode == 503) {
        throw const ApiException(
          statusCode: 503,
          code: 'SERVICE_UNAVAILABLE',
          message: 'No se pudo verificar la empresa. Inténtalo en unos minutos.',
        );
      }
      rethrow;
    }
  }

  /// Branding of a company, available before signing in. Null when the code is unknown.
  Future<CompanyLookup?> lookupCompany(String company) async {
    final slug = company.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9-]{3,60}$').hasMatch(slug)) return null;
    try {
      final json = await _api.getPublic('/api/public/companies/$slug/branding');
      final lookup = parseCompanyLookup(json);
      ref
          .read(clientConfigProvider.notifier)
          .cacheBranding(lookup.slug, (json as Map<String, dynamic>)['branding'] as Map<String, dynamic>);
      return lookup;
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      // Offline: fall back to the colors cached the last time this company signed in.
      final cached = ref.read(clientConfigProvider.notifier).cachedBranding(slug);
      return cached == null ? null : CompanyLookup(slug, slug, cached);
    }
  }

  Future<void> logout() async {
    await _api.logout();
    await ref.read(sharedPreferencesProvider).remove(_cachedUserKey);
    ref.read(clientConfigProvider.notifier).clear();
    state = const AuthState(AuthStatus.unauthenticated);
  }

  Future<void> changePassword(String current, String next) async {
    await _api.post(
      '/api/auth/change-password',
      body: {'currentPassword': current, 'newPassword': next},
    );
  }

  void expireSession() {
    if (state.status != AuthStatus.authenticated) return;
    _tokens.clear();
    ref.read(clientConfigProvider.notifier).clear();
    state = const AuthState(AuthStatus.unauthenticated);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
