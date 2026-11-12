import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'token_store.dart';

typedef QueryParams = Map<String, Object?>;

/// Thin JSON client for the Nest API.
///
/// The API delivers tokens as `Set-Cookie` (httpOnly) and also accepts the access token as
/// `Authorization: Bearer`. A native app has no cookie jar, so the cookies are read from the
/// login/refresh responses, stored securely, and sent back explicitly.
class ApiClient {
  ApiClient({
    required this._baseUrl,
    required this._tokens,
    http.Client? client,
    this._onSessionExpired,
  }) : _client = client ?? http.Client();

  static const _timeout = Duration(seconds: 25);
  static const _uploadTimeout = Duration(seconds: 120);
  static const _accessCookie = 'access_token';
  static const _refreshCookie = 'refresh_token';

  final String Function() _baseUrl;
  final TokenStore _tokens;
  final http.Client _client;
  final void Function()? _onSessionExpired;

  Future<bool>? _refreshing;

  Future<dynamic> get(String path, {QueryParams? query}) =>
      _request('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, QueryParams? query}) =>
      _request('POST', path, body: body ?? const {}, query: query);

  Future<dynamic> patch(String path, {Object? body}) =>
      _request('PATCH', path, body: body ?? const {});

  Future<dynamic> put(String path, {Object? body}) =>
      _request('PUT', path, body: body ?? const {});

  Future<dynamic> delete(String path) => _request('DELETE', path);

  /// Runs the login call and keeps the session cookies.
  Future<Map<String, dynamic>> login(String company, String email, String password) async {
    final response = await _send(
      'POST',
      '/api/auth/login',
      body: {'company': company, 'email': email, 'password': password},
      withAuth: false,
    );
    await _captureCookies(response);
    return _decode(response) as Map<String, dynamic>;
  }

  /// A GET that needs no session (e.g. a company's branding before anyone signs in).
  Future<dynamic> getPublic(String path) async {
    final response = await _send('GET', path, withAuth: false);
    return _decode(response);
  }

  /// Exchanges the refresh cookie for a new pair. Returns false when the session is gone.
  Future<bool> refreshSession() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<void> logout() async {
    try {
      await _send('POST', '/api/auth/logout', body: const {}, withAuth: false);
    } catch (_) {
      // The local session is cleared regardless of the server answer.
    }
    await _tokens.clear();
  }

  Future<bool> _doRefresh() async {
    final refresh = _tokens.refreshToken;
    if (refresh == null) return false;
    final response = await _send(
      'POST',
      '/api/auth/refresh',
      body: const {},
      withAuth: false,
      cookie: '$_refreshCookie=$refresh',
    );
    if (response.statusCode == 401) {
      await _tokens.clear();
      return false;
    }
    // Transport and server failures are not a reason to end the session.
    _decode(response);
    await _captureCookies(response);
    return true;
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    QueryParams? query,
  }) async {
    final response =
        await _retrying(() => _build(method, path, body: body, query: query));
    return _decode(response);
  }

  /// Sends a request; on 401 refreshes the session once and sends a fresh copy.
  /// [build] is a factory because a request object can only be sent once.
  Future<http.Response> _retrying(
    http.BaseRequest Function() build, {
    Duration timeout = _timeout,
  }) async {
    var response = await _sendBuilt(build(), timeout: timeout);
    if (response.statusCode == 401 && _tokens.refreshToken != null) {
      if (await refreshSession()) {
        response = await _sendBuilt(build(), timeout: timeout);
      } else {
        _onSessionExpired?.call();
      }
    } else if (response.statusCode == 401) {
      _onSessionExpired?.call();
    }
    return response;
  }

  /// Uploads one file as `multipart/form-data` (the API reads the field named [field]).
  Future<dynamic> postFile(
    String path, {
    required String field,
    required List<int> bytes,
    required String filename,
  }) async {
    final response = await _retrying(
      () => http.MultipartRequest('POST', _uri(path, null))
        ..files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename)),
      timeout: _uploadTimeout,
    );
    return _decode(response);
  }

  /// Downloads a binary body such as the Excel template.
  Future<Uint8List> getBytes(String path, {QueryParams? query}) async {
    final response = await _retrying(
      () => _build('GET', path, query: query),
      timeout: _uploadTimeout,
    );
    if (response.statusCode >= 400) _decode(response);
    return response.bodyBytes;
  }

  http.Request _build(
    String method,
    String path, {
    Object? body,
    QueryParams? query,
  }) {
    final request = http.Request(method, _uri(path, query));
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return request;
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    QueryParams? query,
    bool withAuth = true,
    String? cookie,
  }) {
    return _sendBuilt(
      _build(method, path, body: body, query: query),
      withAuth: withAuth,
      cookie: cookie,
    );
  }

  Future<http.Response> _sendBuilt(
    http.BaseRequest request, {
    bool withAuth = true,
    String? cookie,
    Duration timeout = _timeout,
  }) async {
    request.headers['Accept'] = 'application/json';
    final access = _tokens.accessToken;
    if (withAuth && access != null) {
      request.headers['Authorization'] = 'Bearer $access';
    }
    if (cookie != null) request.headers['Cookie'] = cookie;

    try {
      final streamed = await _client.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.network();
    }
  }

  Uri _uri(String path, QueryParams? query) {
    final base = _baseUrl().trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base$path');
    final params = <String, String>{};
    query?.forEach((key, value) {
      if (value == null) return;
      final text = value.toString();
      if (text.isEmpty) return;
      params[key] = text;
    });
    return params.isEmpty ? uri : uri.replace(queryParameters: params);
  }

  dynamic _decode(http.Response response) {
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    Object? parsed;
    if (text.isNotEmpty) {
      try {
        parsed = jsonDecode(text);
      } catch (_) {
        parsed = null;
      }
    }
    if (response.statusCode >= 400) {
      throw ApiException.fromBody(response.statusCode, parsed);
    }
    return parsed;
  }

  Future<void> _captureCookies(http.Response response) async {
    final cookies = parseSetCookie(response.headers['set-cookie']);
    final access = cookies[_accessCookie];
    final refresh = cookies[_refreshCookie];
    await _tokens.save(
      access: access != null && access.isNotEmpty ? access : null,
      refresh: refresh != null && refresh.isNotEmpty ? refresh : null,
    );
  }
}

/// `package:http` joins repeated `Set-Cookie` headers with commas; `Expires` also contains a
/// comma, so only split where a new `name=` starts.
Map<String, String> parseSetCookie(String? header) {
  final result = <String, String>{};
  if (header == null || header.isEmpty) return result;
  for (final cookie in header.split(RegExp(r',(?=\s*[A-Za-z0-9_\-]+=)'))) {
    final pair = cookie.split(';').first.trim();
    final separator = pair.indexOf('=');
    if (separator <= 0) continue;
    result[pair.substring(0, separator)] = pair.substring(separator + 1);
  }
  return result;
}
