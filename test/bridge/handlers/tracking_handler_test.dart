/// Tests for `TrackingHandler`: `tracking.stop` refused while a session exists
/// (D8), `tracking.start` through the coordinator, `tracking.latest` passing
/// `maxAgeSeconds`/`highAccuracy` and the session user, `tracking.status`, and
/// `PermissionFailure` surfacing as `PERMISSION_REQUIRED` via the controller.
///
/// Status: active — part of `flutter test`.
library;

import 'dart:convert';

import 'package:dynaopsapp/bridge/bridge_controller.dart';
import 'package:dynaopsapp/bridge/bridge_error_model.dart';
import 'package:dynaopsapp/bridge/bridge_message_model.dart';
import 'package:dynaopsapp/bridge/handlers/tracking_handler.dart';
import 'package:dynaopsapp/core/logging/app_logger.dart';
import 'package:dynaopsapp/core/network/failure.dart';
import 'package:dynaopsapp/features/auth/data/session_model.dart';
import 'package:dynaopsapp/features/auth/data/session_repository.dart';
import 'package:dynaopsapp/features/tracking/data/location_repository.dart';
import 'package:dynaopsapp/features/tracking/data/position_model.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_policy_repository.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_repository.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_status_model.dart';
import 'package:dynaopsapp/features/tracking/engine/tracking_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSession extends Mock implements SessionRepository {}

class _MockTracking extends Mock implements TrackingRepository {}

class _MockCoordinator extends Mock implements TrackingCoordinator {}

class _MockLocations extends Mock implements LocationRepository {}

class _MockPolicies extends Mock implements TrackingPolicyRepository {}

BridgeRequest _request(String action, [Map<String, dynamic> payload = const {}]) =>
    BridgeRequest(version: '1.0', id: '1', action: action, payload: payload);

void main() {
  late _MockSession session;
  late _MockTracking tracking;
  late _MockCoordinator coordinator;
  late _MockLocations locations;
  late TrackingHandler handler;

  setUpAll(() => registerFallbackValue(Duration.zero));

  setUp(() {
    session = _MockSession();
    tracking = _MockTracking();
    coordinator = _MockCoordinator();
    locations = _MockLocations();
    handler = TrackingHandler(session, tracking, coordinator, locations, _MockPolicies());
    when(() => session.current).thenReturn(SessionModel(token: 't', userId: 'u1', expireAt: DateTime.utc(2030)));
    when(() => tracking.current).thenReturn(const TrackingStatusModel(state: TrackingState.running));
  });

  test('stop is refused while signed in', () {
    expect(
      () => handler.handle(_request('tracking.stop', {'reason': 'user'})),
      throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.unsupported)),
    );
  });

  test('stop just reports the state when signed out', () async {
    when(() => session.current).thenReturn(null);
    expect(await handler.handle(_request('tracking.stop', {'reason': 'x'})), {'state': 'running'});
  });

  test('start retries through the coordinator', () async {
    when(() => coordinator.retry()).thenAnswer((_) async => const TrackingStatusModel(state: TrackingState.starting));
    expect(await handler.handle(_request('tracking.start')), {'state': 'starting'});
  });

  test('latest passes the options and the session user', () async {
    when(() => locations.latestFix(
          userId: any(named: 'userId'),
          maxAge: any(named: 'maxAge'),
          highAccuracy: any(named: 'highAccuracy'),
        )).thenAnswer(
      (_) async => LatestFix(
        PositionModel(latitude: 1, longitude: 2, accuracy: 3, timestamp: DateTime.utc(2026)),
        fromCache: true,
      ),
    );
    final data = await handler.handle(_request('tracking.latest', {'maxAgeSeconds': 60, 'highAccuracy': false}));
    expect((data! as Map)['source'], 'cache');
    verify(() => locations.latestFix(userId: 'u1', maxAge: const Duration(seconds: 60), highAccuracy: false))
        .called(1);
  });

  test('missing permission reaches Angular as PERMISSION_REQUIRED', () async {
    when(() => locations.latestFix(
          userId: any(named: 'userId'),
          maxAge: any(named: 'maxAge'),
          highAccuracy: any(named: 'highAccuracy'),
        )).thenThrow(const PermissionFailure('no'));
    when(() => tracking.statuses).thenAnswer((_) => const Stream.empty());
    when(() => tracking.locations).thenAnswer((_) => const Stream.empty());
    final controller = BridgeController([handler], AppLogger());
    final raw = await controller.handleMessage(jsonEncode({
      'version': '1.0',
      'type': 'request',
      'id': 'q',
      'action': 'tracking.latest',
      'payload': <String, dynamic>{},
    }));
    expect((jsonDecode(raw) as Map)['error']['code'], 'PERMISSION_REQUIRED');
  });

  test('status returns the refreshed snapshot', () async {
    when(() => tracking.refreshStatus())
        .thenAnswer((_) async => const TrackingStatusModel(state: TrackingState.running, pendingUploads: 3));
    final data = await handler.handle(_request('tracking.status')) as Map;
    expect((data['state'], data['pendingUploads']), ('running', 3));
  });
}
