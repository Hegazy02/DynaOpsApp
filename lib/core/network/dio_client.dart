/// `createDioClient` builds the app's single Dio instance (base URL, timeouts,
/// debug logging without bodies) and `AuthInterceptor` adds the bearer token
/// and `Accept-Language`, and marks the session expired on 401.
///
/// Why it exists: flutter-dio-repository-setup — networking lives in one
/// client; repositories never configure Dio and Cubits never see it.
/// Status: used — registered in `service_locator.dart`; today its only caller
/// is the connectivity reachability probe. The M2 `LocationUploader` will be
/// the first real API client.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../../features/auth/data/session_repository.dart';
import '../config/app_config.dart';

/// The single Dio instance for this isolate (flutter-dio-repository-setup).
Dio createDioClient(AppConfig config, SessionRepository session) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl.toString(),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  dio.interceptors.add(AuthInterceptor(session));
  if (kDebugMode) {
    // Bodies off: they carry location history and sometimes tokens.
    dio.interceptors.add(PrettyDioLogger(requestBody: false, responseBody: false));
  }
  return dio;
}

/// Attaches the bearer token and `Accept-Language` like Angular's token.interceptor.
///
/// Departs from the skill example on 401 (§7): it marks the session expired —
/// dropping the token, keeping `userId` — instead of deleting the whole session,
/// never navigates, and never retries.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._session);
  final SessionRepository _session;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _session.validToken;
    if (token != null) options.headers['Authorization'] = 'bearer $token';
    options.headers['Accept-Language'] = _session.current?.lang ?? 'en';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) await _session.markExpired();
    handler.next(err);
  }
}
