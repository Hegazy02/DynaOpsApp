/// `RequestLogInterceptor`: records every finished Dio exchange into
/// `request_log` — `Authorization` redacted, bodies JSON-encoded and capped at
/// [maxBodyChars]. Requests with `extra[skipKey] == true` (the connectivity
/// probe) are not recorded. Logging never fails or delays the request.
///
/// Why it exists: the request inspector needs the real payload, status and
/// response of tracking calls, including those sent from the service isolate.
/// Status: used — added by `createDioClient` when the inspector is enabled.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'request_log_dao.dart';
import 'request_log_entry_model.dart';

class RequestLogInterceptor extends Interceptor {
  RequestLogInterceptor(this._dao, {required this.source, this.maxBodyChars = 20000, DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  /// Set `Options(extra: {RequestLogInterceptor.skipKey: true})` to keep a request out of the log.
  static const skipKey = 'requestLog.skip';
  static const _startedKey = 'requestLog.startedAt';

  final RequestLogDao _dao;
  final String source;
  final int maxBodyChars;
  final DateTime Function() _now;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedKey] = _now();
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _record(response.requestOptions, response: response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _record(err.requestOptions, response: err.response, error: '${err.type.name}: ${err.message ?? err.error}');
    handler.next(err);
  }

  void _record(RequestOptions options, {Response<dynamic>? response, String? error}) {
    if (options.extra[skipKey] == true) return;
    final started = options.extra[_startedKey] as DateTime? ?? _now();
    final headers = Map<String, Object?>.of(options.headers);
    if (headers.containsKey('Authorization')) headers['Authorization'] = 'bearer ••••';
    final entry = RequestLogEntryModel(
      source: source,
      method: options.method,
      url: options.uri.toString(),
      requestHeaders: _encode(headers),
      requestBody: _encode(options.data),
      statusCode: response?.statusCode,
      responseBody: _encode(response?.data),
      error: error,
      startedAt: started,
      duration: _now().difference(started),
    );
    // Fire-and-forget: a logging failure must never affect the upload.
    unawaited(_dao.insert(entry).catchError((Object _) {}));
  }

  String? _encode(Object? data) {
    if (data == null) return null;
    String text;
    try {
      text = data is String ? data : jsonEncode(data);
    } catch (_) {
      text = data.toString();
    }
    return text.length > maxBodyChars ? '${text.substring(0, maxBodyChars)}… (truncated)' : text;
  }
}
