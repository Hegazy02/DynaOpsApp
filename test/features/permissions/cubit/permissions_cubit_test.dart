/// `bloc_test` coverage for `PermissionsCubit`: skips steps already granted,
/// advances after a grant, offers settings for a permanently denied
/// permission, adds the maker step only for known makers, and on finish
/// records completion and restarts tracking.
///
/// Status: active — part of `flutter test`.
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:dynaopsapp/features/device/data/device_info_model.dart';
import 'package:dynaopsapp/features/device/data/device_repository.dart';
import 'package:dynaopsapp/features/permissions/cubit/permissions_cubit.dart';
import 'package:dynaopsapp/features/permissions/cubit/permissions_state.dart';
import 'package:dynaopsapp/features/permissions/data/oem_brand.dart';
import 'package:dynaopsapp/features/permissions/data/permission_status_model.dart';
import 'package:dynaopsapp/features/permissions/data/permissions_repository.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_status_model.dart';
import 'package:dynaopsapp/features/tracking/engine/tracking_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPermissions extends Mock implements PermissionsRepository {}

class _MockDevice extends Mock implements DeviceRepository {}

class _MockCoordinator extends Mock implements TrackingCoordinator {}

PermissionStatusModel status({
  PermissionState location = PermissionState.granted,
  PermissionState background = PermissionState.denied,
  PermissionState notifications = PermissionState.granted,
  bool battery = true,
}) =>
    PermissionStatusModel(
      location: location,
      backgroundLocation: background,
      notifications: notifications,
      camera: PermissionState.granted,
      batteryOptimizationIgnored: battery,
    );

void main() {
  late _MockPermissions permissions;
  late _MockDevice device;
  late _MockCoordinator coordinator;

  setUpAll(() => registerFallbackValue(<AppPermission>[]));

  setUp(() {
    permissions = _MockPermissions();
    device = _MockDevice();
    coordinator = _MockCoordinator();
    when(() => device.info()).thenAnswer(
      (_) async => const DeviceInfoModel(appVersion: '1', manufacturer: 'Google', model: 'Pixel', androidSdk: 35),
    );
    when(() => permissions.setWalkthroughCompleted()).thenAnswer((_) async {});
    when(() => permissions.openSettings(any())).thenAnswer((_) async {});
    when(() => coordinator.retry()).thenAnswer((_) async => const TrackingStatusModel(state: TrackingState.running));
  });

  PermissionsCubit build() => PermissionsCubit(permissions, device, coordinator);

  blocTest<PermissionsCubit, PermissionsState>(
    'starts at the first missing step (background) on a stock phone',
    setUp: () => when(() => permissions.status()).thenAnswer((_) async => status()),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      const PermissionsStepShown(step: WalkthroughStep.backgroundLocation, index: 2, total: 4, needsSettings: false),
    ],
  );

  blocTest<PermissionsCubit, PermissionsState>(
    'granting the last missing step finishes and restarts tracking',
    setUp: () {
      when(() => permissions.status()).thenAnswer((_) async => status());
      when(() => permissions.request(any()))
          .thenAnswer((_) async => status(background: PermissionState.granted));
    },
    build: build,
    act: (cubit) async {
      await cubit.load();
      when(() => permissions.status()).thenAnswer((_) async => status(background: PermissionState.granted));
      await cubit.allow();
    },
    skip: 1,
    expect: () => [
      const PermissionsStepShown(
        step: WalkthroughStep.backgroundLocation,
        index: 2,
        total: 4,
        needsSettings: false,
        busy: true,
      ),
      const PermissionsFinished(),
    ],
    verify: (_) {
      verify(() => permissions.setWalkthroughCompleted()).called(1);
      verify(() => coordinator.retry()).called(1);
    },
  );

  blocTest<PermissionsCubit, PermissionsState>(
    'a permanently denied step offers settings instead of asking again',
    setUp: () => when(() => permissions.status())
        .thenAnswer((_) async => status(location: PermissionState.permanentlyDenied)),
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.allow();
    },
    verify: (_) {
      verify(() => permissions.openSettings('app')).called(1);
      verifyNever(() => permissions.request(any()));
    },
  );

  blocTest<PermissionsCubit, PermissionsState>(
    'Samsung phones get the maker step even when everything is granted',
    setUp: () {
      when(() => permissions.status()).thenAnswer((_) async => status(background: PermissionState.granted));
      when(() => device.info()).thenAnswer(
        (_) async => const DeviceInfoModel(appVersion: '1', manufacturer: 'samsung', model: 'A54', androidSdk: 34),
      );
    },
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      const PermissionsStepShown(
        step: WalkthroughStep.oem,
        index: 5,
        total: 5,
        needsSettings: false,
        oem: OemBrand.samsung,
      ),
    ],
  );

  test('maker detection', () {
    expect(OemBrand.fromManufacturer('Redmi'), OemBrand.xiaomi);
    expect(OemBrand.fromManufacturer('HONOR'), OemBrand.huawei);
    expect(OemBrand.fromManufacturer('OnePlus'), OemBrand.oppo);
    expect(OemBrand.fromManufacturer('Google'), isNull);
  });
}
