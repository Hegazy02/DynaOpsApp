/// Tests for the request log on a real in-memory SQLite: the DAO keeps only
/// the newest rows, and `RequestLogInterceptor` records successes and
/// failures with the token redacted, skips flagged requests, and counts pings.
///
/// Status: active — part of `flutter test`.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dynaopsapp/core/database/app_database.dart';
import 'package:dynaopsapp/features/request_inspector/data/request_log_dao.dart';
import 'package:dynaopsapp/features/request_inspector/data/request_log_entry_model.dart';
import 'package:dynaopsapp/features/request_inspector/data/request_log_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

/// Answers every request with [status] and a small JSON body, without a network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status);
  final int status;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(
        jsonEncode({'message': 'status $status'}),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase database;
  late RequestLogDao dao;

  setUp(() async {
    database = await openTestDatabase();
    dao = RequestLogDao(database.db, maxRows: 3);
  });

  tearDown(() => database.close());

  Dio dio(int status) => Dio(BaseOptions(baseUrl: 'https://api.test/api/'))
    ..httpClientAdapter = _FakeAdapter(status)
    ..interceptors.add(RequestLogInterceptor(dao, source: 'service'));

  /// The interceptor writes fire-and-forget; give the insert a moment.
  Future<List<RequestLogEntryModel>> logged() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return dao.recent();
  }

  test('keeps only the newest maxRows entries, newest first', () async {
    for (var i = 0; i < 5; i++) {
      await dao.insert(RequestLogEntryModel(
        source: 'ui',
        method: 'GET',
        url: 'https://api.test/$i',
        startedAt: DateTime.utc(2026),
        duration: Duration.zero,
      ));
    }
    expect((await dao.recent()).map((e) => e.url), ['https://api.test/4', 'https://api.test/3', 'https://api.test/2']);
  });

  test('records a successful upload with payload, response and redacted token', () async {
    await dio(200).post<void>(
      'LocationPings/batch',
      data: {
        'pings': [
          {'lat': 1},
          {'lat': 2},
        ],
      },
      options: Options(headers: {'Authorization': 'bearer secret-token'}),
    );

    final entry = (await logged()).single;
    expect(entry.method, 'POST');
    expect(entry.url, 'https://api.test/api/LocationPings/batch');
    expect(entry.source, 'service');
    expect(entry.statusCode, 200);
    expect(entry.succeeded, isTrue);
    expect(entry.pingCount, 2);
    expect(entry.responseBody, contains('status 200'));
    expect(entry.requestHeaders, isNot(contains('secret-token')));
  });

  test('records a rejected request with status and error', () async {
    await expectLater(dio(422).post<void>('LocationPings/batch', data: {'pings': []}), throwsA(isA<DioException>()));

    final entry = (await logged()).single;
    expect(entry.statusCode, 422);
    expect(entry.succeeded, isFalse);
    expect(entry.error, startsWith('badResponse'));
    expect(entry.responseBody, contains('status 422'));
  });

  test('skips requests flagged with skipKey', () async {
    await dio(200).head<void>('', options: Options(extra: {RequestLogInterceptor.skipKey: true}));
    expect(await logged(), isEmpty);
  });
}
