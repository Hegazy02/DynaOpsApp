/// Tests for `TrackingPolicyRepository`: before the first `RepDashboard`
/// answer (and when that read fails) the rep is not tracked and not blocked;
/// a fetched answer is stored, announced and decides `trackingRequired`.
///
/// Status: active — part of `flutter test`.
library;

import 'package:dynaopsapp/core/logging/app_logger.dart';
import 'package:dynaopsapp/features/sync/data/sync_meta_dao.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_api.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_policy_model.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_policy_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements TrackingApi {}

class _MockMeta extends Mock implements SyncMetaDao {}

class _MockLogger extends Mock implements AppLogger {}

void main() {
  late _MockApi api;
  late _MockMeta meta;
  late TrackingPolicyRepository repository;
  final stored = <String, String?>{};

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    api = _MockApi();
    meta = _MockMeta();
    stored.clear();
    when(() => meta.get(any())).thenAnswer((i) async => stored[i.positionalArguments[0] as String]);
    when(() => meta.set(any(), any())).thenAnswer((i) async {
      stored[i.positionalArguments[0] as String] = i.positionalArguments[1] as String?;
    });
    when(() => meta.setDate(any(), any())).thenAnswer((_) async {});
    when(() => meta.getDate(any())).thenAnswer((_) async => null);
    repository = TrackingPolicyRepository(api, meta, _MockLogger());
  });

  test('before the first answer the rep is not tracked and not blocked', () async {
    expect(await repository.current(), TrackingPolicyModel.unknown);
    expect(await repository.trackingRequired(), false);
  });

  test('a failed first read keeps the rep untracked', () async {
    when(() => api.fetchRepDashboard()).thenThrow(DioException(requestOptions: RequestOptions()));
    expect((await repository.refreshIfStale()).enabled, false);
  });

  test('an answer is stored, announced and decides trackingRequired', () async {
    when(() => api.fetchRepDashboard())
        .thenAnswer((_) async => {'trackingEnabled': true, 'trackingMode': 'Continuous'});
    final announced = expectLater(repository.changes, emits(isA<TrackingPolicyModel>()));
    await repository.refresh();
    await announced;
    expect(await repository.trackingRequired(), true);
  });
}
