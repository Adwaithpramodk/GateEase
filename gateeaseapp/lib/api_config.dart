import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String baseurl = 'https://gateease.marymathacollege.ac.in';

BaseOptions _options() => BaseOptions(
  baseUrl: baseurl,
  connectTimeout: const Duration(seconds: 15),
  receiveTimeout: const Duration(seconds: 15),
  headers: {'Content-Type': 'application/json'},
  followRedirects: false,
);

final Dio dio = Dio(_options());
final Dio _sessionClient = Dio(_options());
const _storage = FlutterSecureStorage();
const _sessionKey = 'gateease.session';

Future<String?>? _refreshInProgress;
Future<void> Function()? onSessionExpired;
int _sessionGeneration = 0;

Future<({String access, String refresh})?> _readSession() async {
  final value = await _storage.read(key: _sessionKey);
  if (value == null) return null;
  final data = jsonDecode(value) as Map<String, dynamic>;
  return (access: data['access'] as String, refresh: data['refresh'] as String);
}

Future<void> saveSession(String access, String refresh) async {
  await _storage.write(
    key: _sessionKey,
    value: jsonEncode({'access': access, 'refresh': refresh}),
  );
}

Future<void> _clearSession() async {
  _sessionGeneration++;
  final prefs = await SharedPreferences.getInstance();
  await _storage.delete(key: _sessionKey);
  for (final key in ['lid', 'usertype', 'access_token', 'refresh_token']) {
    await prefs.remove(key);
  }
}

bool _expired(String token) {
  try {
    return JwtDecoder.isExpired(token);
  } catch (_) {
    return true;
  }
}

Future<bool> restoreSession() async {
  final prefs = await SharedPreferences.getInstance();
  final oldAccess = prefs.getString('access_token');
  final oldRefresh = prefs.getString('refresh_token');
  if (oldAccess != null && oldRefresh != null) {
    if (await _readSession() == null) await saveSession(oldAccess, oldRefresh);
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }
  final session = await _readSession();
  if (session == null || _expired(session.refresh)) {
    await _clearSession();
    return false;
  }
  return true;
}

Future<void> logoutSession({String? deviceToken}) async {
  try {
    await _refreshInProgress;
  } on DioException {
    // A failed renewal still allows the local session to be cleared.
  }
  final session = await _readSession();
  await _clearSession();
  if (session != null) {
    try {
      await _sessionClient.delete(
        '/api/token/refresh/',
        data: {'refresh': session.refresh, 'device_token': ?deviceToken},
      );
    } on DioException {
      // Local logout still works when the backend is unavailable.
    }
  }
}

Future<String?> _renewSession(String refresh, int generation) async {
  try {
    final result = await _sessionClient.post(
      '/api/token/refresh/',
      data: {'refresh': refresh},
    );
    if (generation != _sessionGeneration) return null;
    final access = result.data['access'] as String;
    await saveSession(access, result.data['refresh'] as String);
    return access;
  } on DioException catch (error) {
    if (error.response?.statusCode != 401) rethrow;
    if (generation == _sessionGeneration) {
      await _clearSession();
      await onSessionExpired?.call();
    }
    return null;
  }
}

Future<String?> _validAccess() async {
  final pending = _refreshInProgress;
  if (pending != null) return pending;
  final session = await _readSession();
  if (session == null) return null;
  if (!_expired(session.access)) return session.access;
  if (_expired(session.refresh)) {
    await _clearSession();
    await onSessionExpired?.call();
    return null;
  }
  final existingRefresh = _refreshInProgress;
  if (existingRefresh != null) return existingRefresh;
  final renewal = _renewSession(session.refresh, _sessionGeneration);
  _refreshInProgress = renewal;
  try {
    return await renewal;
  } finally {
    _refreshInProgress = null;
  }
}

bool isGateEaseOrigin(Uri uri) {
  final server = Uri.parse(baseurl);
  return uri.scheme == server.scheme &&
      uri.host == server.host &&
      uri.port == server.port;
}

void setupDioInterceptor() {
  dio.interceptors.clear();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (!isGateEaseOrigin(options.uri) ||
            {
              '/LoginpageAPI',
              '/UserReg',
              '/ForgetPassword',
              '/api/password/reset/',
            }.contains(options.uri.path)) {
          handler.next(options);
          return;
        }
        try {
          final token = await _validAccess();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            options.headers['X-Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        } catch (error) {
          handler.reject(DioException(requestOptions: options, error: error));
        }
      },
      onError: (error, handler) async {
        try {
          final sentToken = error.requestOptions.headers['Authorization'];
          if (error.response?.statusCode == 401 &&
              sentToken != null &&
              sentToken == 'Bearer ${(await _readSession())?.access}') {
            await _clearSession();
            await onSessionExpired?.call();
          }
        } finally {
          handler.next(error);
        }
      },
    ),
  );
}
