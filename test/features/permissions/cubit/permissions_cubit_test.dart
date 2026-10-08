/// `bloc_test` coverage for the mandatory `PermissionsCubit`: it always shows
/// the first required permission still missing, stays on a step that was
/// refused, offers Settings for a permanently denied one, re-checks after
/// Settings (also catching a revoked one), shows the maker hint only once per
/// install and lets only that be skipped, and on finish records completion
/// and restarts tracking. Approximate location and the Location switch are
/// settings-only steps, and a live status change (Location switched on) moves
/// on without a resume. Plus maker detection.
///
/// Status: active — part of `flutter test`.
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dynaopsapp/features/device/data/device_info_model.dart';
import 'package:dynaopsapp/features/device/data/device_repository.dart';
import 'package:dynaopsapp/features/permissions/cubit/permissions_cubit.dart';
import 'package:dynaopsapp/features/permissions/cubit/permissions_state.dart';
import 'package:dynaopsapp/features/permissions/data/oem_brand.dart';
import 'package:dynaopsapp/features/permissions/data/permission_status_model.dart';
import 'package:dynaopsapp/features/permissions/data/permissions_repository.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_policy_repository.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_status_model.dart';
import 'package:dynaopsapp/features/tracking/engine/tracking_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPermissions extends Mock implements PermissionsRepository {}

class _MockDevice extends Mock implements DeviceRepository {}

class _MockCoordinator extends Mock implements TrackingCoordinator {}

class _MockPolicies extends Mock implements TrackingPolicyRepository {}

PermissionStatusModel status({
  PermissionState location = PermissionState.granted,
  PermissionState background = PermissionState.granted,
  PermissionState notifications = PermissionState.granted,
  bool battery = true,
  bool precise = true,
  bool locationOn = true,
}) =>
    PermissionStatusModel(
      location: location,
      backgroundLocation: background,
      notifications: notifications,
      camera: PermissionState.denied,
      batteryOptimizationIgnored: battery,
      preciseLocation: precise,
      locationServiceEnabled: locationOn,
    );

DeviceInfoModel device(String manufacturer) =>
    DeviceInfoModel(appVersion: '1', manufacturer: manufacturer, model: 'x', androidSdk: 35);

void main() {
  late _MockPermissions permissions;
  late _MockDevice deviceRepo;
  late _MockCoordinator coordinator;
  late _MockPolicies policies;
  late StreamController<PermissionStatusModel> changes;

  setUpAll(() => registerFallbackValue(<AppPermission>[]));

  setUp(() {
    permissions = _MockPermissions();
    deviceRepo = _MockDevice();
    coordinator = _MockCoordinator();
    policies = _MockPolicies();
    when(() => policies.trackingRequired()).thenAnswer((_) async => true);
    changes = StreamController.broadcast();
    when(() => permissions.changes).thenAnswer((_) => changes.stream);
    when(() => deviceRepo.info()).thenAnswer((_) async => device('Google'));
    when(() => permissions.walkthroughCompleted).thenReturn(false);
    when(() => permissions.setWalkthroughCompleted()).thenAnswer((_) async {});
    when(() => permissions.openSettings(any())).thenAnswer((_) async {});
    when(() => coordinator.retry()).thenAnswer((_) async => const TrackingStatusModel(state: TrackingState.running));
  });

  tearDown(() => changes.close());

  PermissionsCubit build() => PermissionsCubit(permissions, deviceRepo, coordinator, policies);

  blocTest<PermissionsCubit, PermissionsState>(
    'approximate location → precise step, which opens app settings',
    setUp: () => when(() => permissions.status()).thenAnswer((_) async => status(precise: false)),
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.allow();
    },
    expect: () => [
      const PermissionsStepShown(step: WalkthroughStep.preciseLocation, index: 2, total: 6, needsSettings: true),
      const PermissionsStepShown(
          step: WalkthroughStep.preciseLocation, index: 2, total: 6, needsSettings: true, busy: true),
      const PermissionsStepShown(step: WalkthroughStep.preciseLocation, index: 2, total: 6, needsSettings: true),
    ],
    verify: (_) {
      verify(() => permissions.openSettings('app')).called(1);
      verifyNever(() => permissions.request(any()));
    },
  );

  blocTest<PermissionsCubit, PermissionsState>(
    'Location switch off → its step opens the Location settings screen',
    setUp: () => when(() => permissions.status()).thenAnswer((_) async => status(locationOn: false)),
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.allow();
    },
    skip: 1,
    expect: () => [
      const PermissionsStepShown(
          step: WalkthroughStep.locationService, index: 4, total: 6, needsSettings: true, busy: true),
      const PermissionsStepShown(step: WalkthroughStep.locationService, index: 4, total: 6, needsSettings: true),
    ],
    verify: (_) => verify(() => permissions.openSettings('location')).called(1),
  );

  blocTest<PermissionsCubit, PermissionsState>(
    'turning Location on from quick settings moves on without a resume',
    setUp: () => when(() => permissions.status()).thenAnswer((_) async => status(locationOn: false)),
    build: build,
    act: (cubit) async {
      await cubit.load();
      when(() => permissions.status()).thenAnswer((_) async => status());
      changes.add(status());
      await pumpEventQueue();
    },
    expect: () => [
      const PermissionsStepShown(step: WalkthroughStep.locationService, index: 4, total: 6, needsSettings: true),
      const PermissionsFinished(),
    ],
  );

  blocTest<PermissionsCubit, PermissionsState>(
    'shows the first required permission still missing',
    setUp: () => when(() => permissions.status())
        .thenAnswer((_) async => status(background: PermissionState.denied, battery: false)),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      const PermissionsStepShown(step: WalkthroughStep.backgroundLocation, index: 3, total: 6, needsSettings: false),
    ],
  );

  blocTest<PermissionsCubit, PermissionsState>(
    'a refused permission keeps the rep on that step',
    setUp: () {
      when(() => permissions.status()).thenAnswer((_) async => status(notifications: PermissionState.denied));
      when(() => permissions.request(any()))
          .thenAnswer((_) async => status(notifications: PermissionState.denied));
    },
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.allow();
    },
    expect: () => [
      const PermissionsStepShown(step: WalkthroughStep.notifications, index: 5, total: 6, needsSettings: false),
      const PermissionsStepShown(
          step: WalkthroughStep.notifications, index: 5, total: 6, needsSettings: false, busy: true),
      const PermissionsStepShown(step: WalkthroughStep.notifications, index: 5, total: 6, needsSettings: false),
    ],
    verify: (_) => verifyNever(() => permissions.setWalkthroughCompleted()),
  );

  blocTest<PermissionsCubit, PermissionsState>(
    'granting the last missing permission finishes and restarts tracking',
    setUp: () {
      when(() => permissions.status()).thenAnswer((_) async => status(battery: false));
      when(() => permissions.request(any())).thenAnswer((_) async => status());
    },
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.allow();
    },
    skip: 2,
    expect: () => [const PermissionsFinished()],
    verify: (_) {
      verify(() => permissions.setWalkthroughCompleted()).called(1);
      verify(() => coordinator.retry()).called(1);
    },
  );

  blocTest<PermissionsCubit, PermissionsState>(
    'a permanently denied permission offers Settings instead of asking again',
    setUp: () => when(() => permissions.status())
        .thenAnswer((_) async => status(location: PermissionState.permanentlyDenied)),
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.allow();
    },
    expect: () => [
      const PermissionsStepShown(step: WalkthroughStep.location, index: 1, total: 6, needsSettings: true),
      const PermissionsStepShown(step: WalkthroughStep.location, index: 1, total: 6, needsSettings: true, busy: true),
      const PermissionsStepShown(step: WalkthroughStep.location, index: 1, total: 6, needsSettings: true),
    ],
    verify: (_) {
      verify(() => permissions.openSettings('app')).called(1);
      verifyNever(() => permissions.request(any()));
    },
  );

  blocTest<PermissionsCubit, PermissionsState>(
    'recheck after Settings catches a permission revoked meanwhile',
    setUp: () => when(() => permissions.status()).thenAnswer((_) async => status(battery: false)),
    build: build,
    act: (cubit) async {
      await cubit.load();
      when(() => permissions.status()).thenAnswer(
        (_) async => status(location: PermissionState.denied, battery: false),
      );
      await cubit.recheck();
    },
    expect: () => [
      const PermissionsStepShown(step: WalkthroughStep.battery, index: 6, total: 6, needsSettings: false),
      const PermissionsStepShown(step: WalkthroughStep.location, index: 1, total: 6, needsSettings: false),
    ],
  );

  blocTest<PermissionsCubit, PermissionsState>(
    'the maker hint comes after the required steps and is the only skippable one',
    setUp: () {
      when(() => permissions.status()).thenAnswer((_) async => status());
      when(() => deviceRepo.info()).thenAnswer((_) async => device('samsung'));
    },
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.skipHint();
    },
    expect: () => [
      const PermissionsStepShown(
        step: WalkthroughStep.oem,
        index: 7,
        total: 7,
        needsSettings: false,
        oem: OemBrand.samsung,
      ),
      const PermissionsFinished(),
    ],
  );

  blocTest<PermissionsCubit, PermissionsState>(
    'the maker hint is not shown again once the walkthrough was completed',
    setUp: () {
      when(() => permissions.status()).thenAnswer((_) async => status());
      when(() => permissions.walkthroughCompleted).thenReturn(true);
      when(() => deviceRepo.info()).thenAnswer((_) async => device('Xiaomi'));
    },
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [const PermissionsFinished()],
  );

  blocTest<PermissionsCubit, PermissionsState>(
    'steps are not mandatory for a rep whose tracking is off',
    setUp: () {
      when(() => permissions.status()).thenAnswer((_) async => status(locationOn: false));
      when(() => policies.trackingRequired()).thenAnswer((_) async => false);
    },
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      const PermissionsStepShown(
        step: WalkthroughStep.locationService,
        index: 4,
        total: 6,
        needsSettings: true,
        mandatory: false,
      ),
    ],
  );

  test('trackingReady needs precise location all the time, Location on, notifications and battery', () {
    expect(status().trackingReady, true);
    expect(status(precise: false).trackingReady, false);
    expect(status(locationOn: false).trackingReady, false);
    expect(status(background: PermissionState.denied).trackingReady, false);
    expect(status(notifications: PermissionState.denied).trackingReady, false);
    expect(status(battery: false).trackingReady, false);
  });

  test('maker detection', () {
    expect(OemBrand.fromManufacturer('Redmi'), OemBrand.xiaomi);
    expect(OemBrand.fromManufacturer('HONOR'), OemBrand.huawei);
    expect(OemBrand.fromManufacturer('OnePlus'), OemBrand.oppo);
    expect(OemBrand.fromManufacturer('Google'), isNull);
  });
}
