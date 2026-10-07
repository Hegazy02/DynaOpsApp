/// Tests for `TrackingEngine` with every dependency mocked and a controllable
/// clock: signed out and disabled-by-admin stop the service, missing
/// permission and location-off states, store-first collection publishing the
/// fix and `running`, only pings stored (heartbeat on tick), expired session
/// still collecting, the watchdog restart
/// then `LOCATION_UNAVAILABLE`, and the sign-out flush reply.
///
/// Status: active — part of `flutter test`.
library;

import 'dart:async';

import 'package:dynaopsapp/core/config/app_config.dart';
import 'package:dynaopsapp/core/logging/app_logger.dart';
import 'package:dynaopsapp/features/auth/data/session_model.dart';
import 'package:dynaopsapp/features/auth/data/session_repository.dart';
import 'package:dynaopsapp/features/connectivity/data/connectivity_repository.dart';
import 'package:dynaopsapp/features/connectivity/data/network_status_model.dart';
import 'package:dynaopsapp/features/permissions/data/permission_status_model.dart';
import 'package:dynaopsapp/features/permissions/data/permissions_repository.dart';
import 'package:dynaopsapp/features/sync/data/sync_meta_dao.dart';
import 'package:dynaopsapp/features/sync/data/sync_status_model.dart';
import 'package:dynaopsapp/features/sync/engine/sync_manager.dart';
import 'package:dynaopsapp/features/tracking/data/location_fix_model.dart';
import 'package:dynaopsapp/features/tracking/data/location_points_dao.dart';
import 'package:dynaopsapp/features/tracking/data/location_repository.dart';
import 'package:dynaopsapp/features/tracking/data/location_source.dart';
import 'package:dynaopsapp/features/tracking/data/position_model.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_policy_model.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_policy_repository.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_status_model.dart';
import 'package:dynaopsapp/features/tracking/engine/foreground_task_port.dart';
import 'package:dynaopsapp/features/tracking/engine/task_protocol.dart';
import 'package:dynaopsapp/features/tracking/engine/tracking_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSession extends Mock implements SessionRepository {}

class _MockPolicies extends Mock implements TrackingPolicyRepository {}

class _MockSource extends Mock implements LocationSource {}

class _MockLocations extends Mock implements LocationRepository {}

class _MockPoints extends Mock implements LocationPointsDao {}

class _MockSync extends Mock implements SyncManager {}

class _MockMeta extends Mock implements SyncMetaDao {}

class _MockConnectivity extends Mock implements ConnectivityRepository {}

class _MockPermissions extends Mock implements PermissionsRepository {}

class _MockPort extends Mock implements TrackingPort {}

const _granted = PermissionStatusModel(
  location: PermissionState.granted,
  backgroundLocation: PermissionState.granted,
  notifications: PermissionState.granted,
  camera: PermissionState.granted,
  batteryOptimizationIgnored: true,
  preciseLocation: true,
  locationServiceEnabled: true,
);

void main() {
  final config = AppConfig(
    webUrl: Uri.parse('https://app.example/'),
    apiBaseUrl: Uri.parse('https://api.example/api/'),
    tenant: 't',
  );
  final validSession = SessionModel(token: 'jwt', userId: 'u1', expireAt: DateTime.utc(2030));
  late DateTime now;
  late _MockSession session;
  late _MockPolicies policies;
  late _MockSource source;
  late _MockLocations locations;
  late _MockPoints points;
  late _MockSync sync;
  late _MockMeta meta;
  late _MockConnectivity connectivity;
  late _MockPermissions permissions;
  late _MockPort port;
  late StreamController<PositionModel> positions;
  late List<TrackingStatusModel> published;
  late int streamsOpened;

  TrackingEngine engine() => TrackingEngine(
        config: config,
        session: session,
        policies: policies,
        source: source,
        locations: locations,
        points: points,
        sync: sync,
        meta: meta,
        connectivity: connectivity,
        permissions: permissions,
        port: port,
        logger: AppLogger(),
        clock: () => now,
      );

  setUpAll(() {
    registerFallbackValue(const TrackingStatusModel(state: TrackingState.stopped));
    registerFallbackValue(PositionModel(latitude: 0, longitude: 0, accuracy: 0, timestamp: DateTime.utc(2026)));
    registerFallbackValue(LocationFixModel(
      id: 'x',
      userId: 'x',
      position: PositionModel(latitude: 0, longitude: 0, accuracy: 0, timestamp: DateTime.utc(2026)),
    ));
    registerFallbackValue(Duration.zero);
    registerFallbackValue(DateTime.utc(2026));
  });

  setUp(() {
    now = DateTime.utc(2026, 10, 6, 9);
    session = _MockSession();
    policies = _MockPolicies();
    source = _MockSource();
    locations = _MockLocations();
    points = _MockPoints();
    sync = _MockSync();
    meta = _MockMeta();
    connectivity = _MockConnectivity();
    permissions = _MockPermissions();
    port = _MockPort();
    published = [];
    streamsOpened = 0;
    positions = StreamController<PositionModel>.broadcast();

    when(() => session.load()).thenAnswer((_) async {});
    when(() => session.current).thenReturn(validSession);
    when(() => session.validToken).thenReturn('jwt');
    when(() => policies.refreshIfStale(force: any(named: 'force')))
        .thenAnswer((_) async => TrackingPolicyModel.serverDefault);
    when(() => policies.isStale()).thenAnswer((_) async => false);
    when(() => source.access()).thenAnswer((_) async => LocationAccess.granted);
    when(() => source.isServiceEnabled()).thenAnswer((_) async => true);
    when(() => source.serviceEnabledChanges()).thenAnswer((_) => const Stream.empty());
    when(() => source.positions(interval: any(named: 'interval'), distanceFilter: any(named: 'distanceFilter')))
        .thenAnswer((_) {
      streamsOpened++;
      return positions.stream;
    });
    when(() => locations.store(any(), userId: any(named: 'userId'))).thenAnswer(
      (call) async => LocationFixModel(
        id: 'f$streamsOpened',
        userId: call.namedArguments[#userId] as String,
        position: call.positionalArguments.first as PositionModel,
      ),
    );
    when(() => points.counts(any())).thenAnswer((_) async => const PointCounts(pending: 1, failed: 0));
    when(() => sync.recover()).thenAnswer((_) async {});
    when(() => sync.runCycle(manual: any(named: 'manual')))
        .thenAnswer((_) async => const SyncCycleResult(ran: true, processed: 4));
    when(() => meta.set(any(), any())).thenAnswer((_) async {});
    when(() => meta.setDate(any(), any())).thenAnswer((_) async {});
    when(() => meta.getDate(any())).thenAnswer((_) async => null);
    when(() => connectivity.changes).thenAnswer((_) => const Stream<NetworkStatusModel>.empty());
    when(() => connectivity.start()).thenAnswer((_) async {});
    when(() => permissions.status()).thenAnswer((_) async => _granted);
    when(() => port.publishStatus(any())).thenAnswer((call) {
      published.add(call.positionalArguments.first as TrackingStatusModel);
    });
    when(() => port.updateNotification(any(), lang: any(named: 'lang'))).thenAnswer((_) async {});
    when(() => port.stopService()).thenAnswer((_) async {});
  });

  tearDown(() => positions.close());

  test('signed out → stopped and the service stops itself', () async {
    when(() => session.current).thenReturn(null);
    await engine().start();
    expect(published.last.state, TrackingState.stopped);
    expect(published.last.reason, 'signedOut');
    verify(() => port.stopService()).called(1);
    expect(streamsOpened, 0);
  });

  test('disabled by an admin → stopped and the service stops itself', () async {
    when(() => policies.refreshIfStale(force: any(named: 'force')))
        .thenAnswer((_) async => const TrackingPolicyModel(enabled: false, mode: 'Route'));
    await engine().start();
    expect(published.last.reason, 'disabledByAdmin');
    verify(() => port.stopService()).called(1);
  });

  test('no location permission → permission_required, no stream', () async {
    when(() => source.access()).thenAnswer((_) async => LocationAccess.denied);
    await engine().start();
    expect(published.last.state, TrackingState.permissionRequired);
    expect(streamsOpened, 0);
    verifyNever(() => port.stopService());
  });

  test('location turned off → error LOCATION_DISABLED', () async {
    when(() => source.isServiceEnabled()).thenAnswer((_) async => false);
    await engine().start();
    expect((published.last.state, published.last.errorCode), (TrackingState.error, 'LOCATION_DISABLED'));
  });

  test('stores each fix first, publishes it and reports running', () async {
    final e = engine();
    await e.start();
    expect(published.last.state, TrackingState.starting);

    positions.add(PositionModel(latitude: 30, longitude: 31, accuracy: 5, timestamp: now));
    await pumpEventQueue();

    verify(() => locations.store(any(), userId: 'u1')).called(1);
    verify(() => port.publishLocation(any())).called(1);
    expect(published.last.state, TrackingState.running);
  });

  test('stores only pings: small moves wait, the heartbeat tick records the newest sample', () async {
    final e = engine();
    await e.start();
    positions.add(PositionModel(latitude: 30, longitude: 31, accuracy: 5, timestamp: now));
    await pumpEventQueue();
    positions.add(PositionModel(latitude: 30.00005, longitude: 31, accuracy: 5, timestamp: now.add(const Duration(seconds: 20))));
    await pumpEventQueue();
    verify(() => locations.store(any(), userId: 'u1')).called(1); // ≈5 m: no movement ping

    now = now.add(const Duration(seconds: 30));
    await e.tick();
    final stored = verify(() => locations.store(captureAny(), userId: 'u1')).captured.single as PositionModel;
    expect(stored.latitude, 30.00005);
    expect(stored.speed, 0);
  });

  test('an expired session keeps collecting with reason sessionExpired', () async {
    when(() => session.validToken).thenReturn(null);
    await engine().start();
    expect(streamsOpened, 1);
    expect(published.last.reason, 'sessionExpired');
  });

  test('watchdog restarts the stream once, then reports LOCATION_UNAVAILABLE', () async {
    final e = engine();
    await e.start();
    now = now.add(const Duration(minutes: 6));
    await e.tick();
    expect(streamsOpened, 2);
    now = now.add(const Duration(minutes: 6));
    await e.tick();
    expect((published.last.state, published.last.errorCode), (TrackingState.error, 'LOCATION_UNAVAILABLE'));
  });

  test('flush stops collecting, uploads once and replies with the count', () async {
    final e = engine();
    await e.start();
    await e.handleCommand({TaskCommand.key: TaskCommand.flush, 'requestId': 'r1'});
    verify(() => port.publishFlushed('r1', 4)).called(1);
    expect(published.last.state, TrackingState.stopping);
  });
}
