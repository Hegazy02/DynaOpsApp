/// Tests for `ConnectivityRepository`'s reachability rule: any HTTP answer or
/// a slow reply (receive timeout) means online; failing to connect or no
/// transport means offline; only real changes are published.
///
/// Status: active — part of `flutter test`.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dynaopsapp/core/logging/app_logger.dart';
import 'package:dynaopsapp/features/connectivity/data/connectivity_repository.dart';
import 'package:dynaopsapp/features/connectivity/data/network_status_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConnectivity extends Mock implements Connectivity {}

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockConnectivity connectivity;
  late _MockDio dio;
  late ConnectivityRepository repository;

  void probeThrows(DioExceptionType type) => when(() => dio.head<void>(any(), options: any(named: 'options')))
      .thenThrow(DioException(requestOptions: RequestOptions(), type: type));

  setUpAll(() => registerFallbackValue(Options()));

  setUp(() {
    connectivity = _MockConnectivity();
    dio = _MockDio();
    repository = ConnectivityRepository(connectivity, dio, AppLogger());
    when(() => connectivity.checkConnectivity()).thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(() => dio.head<void>(any(), options: any(named: 'options'))).thenAnswer(
      (_) async => Response<void>(requestOptions: RequestOptions(), statusCode: 405),
    );
  });

  test('any HTTP answer means online', () async {
    expect((await repository.refresh()).online, true);
  });

  test('a slow reply still means online', () async {
    probeThrows(DioExceptionType.receiveTimeout);
    expect((await repository.refresh()).online, true);
  });

  test('failing to connect means offline', () async {
    for (final type in [DioExceptionType.connectionError, DioExceptionType.connectionTimeout]) {
      probeThrows(type);
      expect((await repository.refresh()).online, false, reason: '$type');
    }
  });

  test('no transport means offline without probing', () async {
    when(() => connectivity.checkConnectivity()).thenAnswer((_) async => [ConnectivityResult.none]);
    expect(await repository.refresh(), NetworkStatusModel.unknown);
    verifyNever(() => dio.head<void>(any(), options: any(named: 'options')));
  });

  test('publishes only real changes', () async {
    final changes = <NetworkStatusModel>[];
    repository.changes.listen(changes.add);
    await repository.refresh();
    await repository.refresh();
    await pumpEventQueue();
    expect(changes, hasLength(1));
  });
}
