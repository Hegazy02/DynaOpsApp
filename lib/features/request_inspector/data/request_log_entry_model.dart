/// `RequestLogEntryModel`: one finished HTTP exchange as stored in
/// `request_log` — method, URL, redacted headers, request/response bodies
/// (JSON text, truncated), status or error, start time, duration, and which
/// isolate sent it (`ui` or `service`).
///
/// Why it exists: the request inspector shows what the tracking upload and
/// policy calls actually sent and received, from either isolate.
/// Status: used — written by `RequestLogInterceptor`, read by
/// `RequestInspectorRepository`.
library;

import 'dart:convert';

import 'package:equatable/equatable.dart';

class RequestLogEntryModel extends Equatable {
  const RequestLogEntryModel({
    this.id,
    required this.source,
    required this.method,
    required this.url,
    this.requestHeaders,
    this.requestBody,
    this.statusCode,
    this.responseBody,
    this.error,
    required this.startedAt,
    required this.duration,
  });

  factory RequestLogEntryModel.fromRow(Map<String, Object?> row) => RequestLogEntryModel(
        id: row['id'] as int?,
        source: row['source']! as String,
        method: row['method']! as String,
        url: row['url']! as String,
        requestHeaders: row['request_headers'] as String?,
        requestBody: row['request_body'] as String?,
        statusCode: row['status_code'] as int?,
        responseBody: row['response_body'] as String?,
        error: row['error'] as String?,
        startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at']! as int, isUtc: true),
        duration: Duration(milliseconds: row['duration_ms']! as int),
      );

  final int? id;

  /// `ui` or `service` — the isolate whose Dio sent it.
  final String source;
  final String method;
  final String url;
  final String? requestHeaders;
  final String? requestBody;
  final int? statusCode;
  final String? responseBody;

  /// Transport error or Dio message when there was no 2xx answer.
  final String? error;
  final DateTime startedAt;
  final Duration duration;

  bool get succeeded => statusCode != null && statusCode! >= 200 && statusCode! < 300;

  /// Number of pings when this is a `LocationPings/batch` upload, else null.
  int? get pingCount {
    final body = requestBody;
    if (body == null) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded['pings'] is List ? (decoded['pings'] as List).length : null;
    } on FormatException {
      return null;
    }
  }

  Map<String, Object?> toRow() => {
        'source': source,
        'method': method,
        'url': url,
        'request_headers': requestHeaders,
        'request_body': requestBody,
        'status_code': statusCode,
        'response_body': responseBody,
        'error': error,
        'started_at': startedAt.toUtc().millisecondsSinceEpoch,
        'duration_ms': duration.inMilliseconds,
      };

  @override
  List<Object?> get props => [
        id,
        source,
        method,
        url,
        requestHeaders,
        requestBody,
        statusCode,
        responseBody,
        error,
        startedAt,
        duration,
      ];
}
