/// `bloc_test` coverage for `ShellCubit` with every repository and the
/// `WebViewPort` mocked: start → loading → ready (camera asked once), offline
/// error and retry on reconnect, a load error not hidden by a later page
/// finish, renderer-crash recreation, bridge events delivered only once the
/// page is ready, refusal of bridge messages from other origins, external
/// link hand-off, geolocation granted only to the web origin, and
/// `app.resumed` carrying the real tracking state and pending count.
///
/// Status: active — part of `flutter test`.
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dynaopsapp/bridge/bridge_controller.dart';
import 'package:dynaopsapp/bridge/bridge_message_model.dart';
import 'package:dynaopsapp/core/config/app_config.dart';
import 'package:dynaopsapp/core/logging/app_logger.dart';
import 'package:dynaopsapp/features/connectivity/data/connectivity_repository.dart';
import 'package:dynaopsapp/features/connectivity/data/network_status_model.dart';
import 'package:dynaopsapp/features/device/data/device_info_model.dart';
import 'package:dynaopsapp/features/device/data/device_repository.dart';
import 'package:dynaopsapp/features/permissions/data/permission_status_model.dart';
import 'package:dynaopsapp/features/permissions/data/permissions_repository.dart';
import 'package:dynaopsapp/features/shell/cubit/shell_cubit.dart';
import 'package:dynaopsapp/features/shell/cubit/shell_state.dart';
import 'package:dynaopsapp/features/shell/cubit/web_view_port.dart';
import 'package:dynaopsapp/features/shell/data/external_link_repository.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_repository.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_status_model.dart';
import 'package:dynaopsapp/features/tracking/engine/tracking_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBridge extends Mock implements BridgeController {}

class _MockConnectivity extends Mock implements ConnectivityRepository {}

class _MockPermissions extends Mock implements PermissionsRepository {}

class _MockDevice extends Mock implements DeviceRepository {}

class _MockLinks extends Mock implements ExternalLinkRepository {}

class _MockPort extends Mock implements WebViewPort {}

class _MockTracking extends Mock implements TrackingRepository {}

class _MockCoordinator extends Mock implements TrackingCoordinator {}

const _online = NetworkStatusModel(connectionType: 'wifi', reachable: true);
const _offline = NetworkStatusModel(connectionType: 'none', reachable: false);
const _permissions = PermissionStatusModel(
  location: PermissionState.granted,
  backgroundLocation: PermissionState.denied,
  notifications: PermissionState.denied,
  camera: PermissionState.granted,
  batteryOptimizationIgnored: false,
);

void main() {
  final config = AppConfig(
    webUrl: Uri.parse('https://app.dynaops.example/'),
    apiBaseUrl: Uri.parse('https://api.dynaops.example/'),
    tenant: 'test',
  );
  late _MockBridge bridge;
  late _MockConnectivity connectivity;
  late _MockPermissions permissions;
  late _MockDevice device;
  late _MockLinks links;
  late _MockPort port;
  late _MockTracking tracking;
  late _MockCoordinator coordinator;
  late StreamController<BridgeEvent> bridgeEvents;
  late StreamController<NetworkStatusModel> networkChanges;

  setUpAll(() => registerFallbackValue(Uri()));

  setUp(() {
    bridge = _MockBridge();
    connectivity = _MockConnectivity();
    permissions = _MockPermissions();
    device = _MockDevice();
    links = _MockLinks();
    port = _MockPort();
    tracking = _MockTracking();
    coordinator = _MockCoordinator();
    when(() => coordinator.onAppResumed()).thenAnswer((_) async {});
    when(() => tracking.refreshStatus()).thenAnswer(
      (_) async => const TrackingStatusModel(state: TrackingState.running, pendingUploads: 7),
    );
    bridgeEvents = StreamController.broadcast();
    networkChanges = StreamController.broadcast();
    when(() => bridge.events).thenAnswer((_) => bridgeEvents.stream);
    when(() => connectivity.changes).thenAnswer((_) => networkChanges.stream);
    when(() => connectivity.start()).thenAnswer((_) async {});
    when(() => connectivity.refresh()).thenAnswer((_) async => _online);
    when(() => permissions.refresh()).thenAnswer((_) async => _permissions);
    when(() => permissions.requestCameraOnce()).thenAnswer((_) async {});
    when(() => device.info()).thenAnswer(
      (_) async => const DeviceInfoModel(appVersion: '1.0.0+1', manufacturer: 'm', model: 'x', androidSdk: 34),
    );
    when(() => links.open(any())).thenAnswer((_) async => true);
    when(() => port.evaluate(any())).thenAnswer((_) async {});
    when(() => port.reload()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await bridgeEvents.close();
    await networkChanges.close();
  });

  ShellCubit build() =>
      ShellCubit(config, bridge, connectivity, permissions, device, links, tracking, coordinator, AppLogger());

  blocTest<ShellCubit, ShellState>(
    'start prepares the bridge script and starts loading',
    build: build,
    act: (cubit) => cubit.start(),
    expect: () => [const ShellLoading(0)],
    verify: (cubit) {
      expect(cubit.bridgeScript, contains('"1.0.0+1"'));
      expect(cubit.userAgentSuffix, 'DynaOpsApp/1.0.0+1 (Android)');
    },
  );

  blocTest<ShellCubit, ShellState>(
    'progress then page finished → ready, asks for camera once',
    build: build,
    act: (cubit) async {
      await cubit.start();
      cubit
        ..onProgress(40)
        ..onPageFinished();
    },
    expect: () => [const ShellLoading(0), const ShellLoading(0, progress: 40), const ShellReady(0)],
    verify: (_) => verify(() => permissions.requestCameraOnce()).called(1),
  );

  blocTest<ShellCubit, ShellState>(
    'main-frame error while offline → offline error; coming back online retries',
    build: build,
    act: (cubit) async {
      await cubit.start();
      cubit.attachWebView(port);
      when(() => connectivity.refresh()).thenAnswer((_) async => _offline);
      await cubit.onMainFrameError('net::ERR_INTERNET_DISCONNECTED');
      networkChanges.add(_online);
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [const ShellLoading(0), const ShellLoadError(0, offline: true), const ShellLoading(0)],
    verify: (_) => verify(() => port.reload()).called(1),
  );

  blocTest<ShellCubit, ShellState>(
    'a load error is not hidden by the following onPageFinished',
    build: build,
    act: (cubit) async {
      await cubit.start();
      await cubit.onMainFrameError('net::ERR_CONNECTION_REFUSED');
      cubit.onPageFinished();
    },
    expect: () => [const ShellLoading(0), const ShellLoadError(0, offline: false)],
  );

  blocTest<ShellCubit, ShellState>(
    'renderer crash recreates the WebView',
    build: build,
    act: (cubit) async {
      await cubit.start();
      cubit.onRenderProcessGone();
    },
    expect: () => [const ShellLoading(0), const ShellLoading(1)],
  );

  test('bridge events reach the page only once it is ready', () async {
    final cubit = build();
    await cubit.start();
    cubit.attachWebView(port);

    bridgeEvents.add(const BridgeEvent('network.changed'));
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => port.evaluate(any()));

    cubit.onPageFinished();
    bridgeEvents.add(const BridgeEvent('network.changed'));
    await Future<void>.delayed(Duration.zero);
    verify(() => port.evaluate(any(that: contains('network.changed')))).called(1);
    await cubit.close();
  });

  test('bridge messages from another origin are refused', () async {
    final cubit = build();
    expect(await cubit.onBridgeMessage('{}', Uri.parse('https://evil.example/')), isNull);
    verifyNever(() => bridge.handleMessage(any()));

    when(() => bridge.handleMessage(any())).thenAnswer((_) async => '{"ok":true}');
    expect(await cubit.onBridgeMessage('{}', Uri.parse('https://app.dynaops.example/x')), '{"ok":true}');
    await cubit.close();
  });

  test('external links are handed off and not loaded', () async {
    final cubit = build();
    expect(await cubit.shouldLoad(Uri.parse('tel:123'), isMainFrame: true), false);
    verify(() => links.open(Uri.parse('tel:123'))).called(1);
    expect(await cubit.shouldLoad(Uri.parse('https://app.dynaops.example/a'), isMainFrame: true), true);
    await cubit.close();
  });

  test('geolocation is granted only to the web origin', () async {
    when(() => permissions.isLocationGranted()).thenAnswer((_) async => true);
    final cubit = build();
    expect(await cubit.onGeolocationPrompt('https://app.dynaops.example/'), true);
    expect(await cubit.onGeolocationPrompt('https://evil.example/'), false);
    await cubit.close();
  });

  test('resume re-checks tracking and reports its state and pending count', () async {
    final cubit = build();
    await cubit.start();
    cubit
      ..attachWebView(port)
      ..onPageFinished();
    await cubit.onAppResumed();
    verify(() => coordinator.onAppResumed()).called(1);
    final script = verify(() => port.evaluate(captureAny())).captured.single as String;
    expect(script, contains(r'\"trackingState\":\"running\"'));
    expect(script, contains(r'\"pendingCount\":7'));
    await cubit.close();
  });
}
