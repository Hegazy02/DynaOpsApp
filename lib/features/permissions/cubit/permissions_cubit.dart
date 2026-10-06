/// `PermissionsCubit`: drives the native permission walkthrough (§13) —
/// foreground location, background location ("Allow all the time"),
/// notifications, battery-optimisation exemption, then a maker-specific hint.
/// Skips steps already satisfied, never re-asks a permanently denied
/// permission (offers settings instead), and on finish records completion and
/// asks the coordinator to (re)start tracking.
///
/// Why it exists: the order and Android-version rules of the walkthrough are
/// logic, kept out of the screen.
/// Status: used — provided on `/permissions`; tested in
/// `test/features/permissions/cubit/permissions_cubit_test.dart`.
library;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../device/data/device_repository.dart';
import '../../tracking/engine/tracking_coordinator.dart';
import '../data/oem_brand.dart';
import '../data/permission_status_model.dart';
import '../data/permissions_repository.dart';
import 'permissions_state.dart';

class PermissionsCubit extends Cubit<PermissionsState> {
  PermissionsCubit(this._permissions, this._device, this._coordinator) : super(const PermissionsLoading());

  final PermissionsRepository _permissions;
  final DeviceRepository _device;
  final TrackingCoordinator _coordinator;

  List<WalkthroughStep> _steps = const [];
  OemBrand? _oem;
  int _index = 0;

  Future<void> load() async {
    try {
      _oem = OemBrand.fromManufacturer((await _device.info()).manufacturer);
    } catch (_) {
      _oem = null;
    }
    _steps = [
      WalkthroughStep.location,
      WalkthroughStep.backgroundLocation,
      WalkthroughStep.notifications,
      WalkthroughStep.battery,
      if (_oem != null) WalkthroughStep.oem,
    ];
    _index = 0;
    await _showFirstUnsatisfied(await _permissions.status());
  }

  /// The step's main button: request the permission (or open settings).
  Future<void> allow() async {
    final current = state;
    if (current is! PermissionsStepShown || current.busy) return;
    emit(current.copyWith(busy: true));
    if (current.needsSettings || current.step == WalkthroughStep.oem) {
      await _permissions.openSettings('app');
      if (current.step == WalkthroughStep.oem) return next();
      emit(current.copyWith(busy: false));
      return;
    }
    final status = await _permissions.request([_permissionFor(current.step)]);
    if (_satisfied(current.step, status)) return next();
    emit(current.copyWith(busy: false, needsSettings: _permanentlyDenied(current.step, status)));
  }

  /// "Next": move on without granting (the rep can come back later).
  Future<void> next() async {
    _index++;
    await _showFirstUnsatisfied(await _permissions.status());
  }

  /// Back from the settings screen: the rep may have granted it there.
  Future<void> recheck() async {
    if (state is! PermissionsStepShown) return;
    await _showFirstUnsatisfied(await _permissions.status());
  }

  Future<void> _showFirstUnsatisfied(PermissionStatusModel status) async {
    while (_index < _steps.length && _steps[_index] != WalkthroughStep.oem && _satisfied(_steps[_index], status)) {
      _index++;
    }
    if (_index >= _steps.length) return _finish();
    final step = _steps[_index];
    emit(PermissionsStepShown(
      step: step,
      index: _index + 1,
      total: _steps.length,
      needsSettings: _permanentlyDenied(step, status),
      oem: _oem,
    ));
  }

  Future<void> _finish() async {
    await _permissions.setWalkthroughCompleted();
    await _coordinator.retry();
    emit(const PermissionsFinished());
  }

  static AppPermission _permissionFor(WalkthroughStep step) => switch (step) {
        WalkthroughStep.location => AppPermission.location,
        WalkthroughStep.backgroundLocation => AppPermission.backgroundLocation,
        WalkthroughStep.notifications => AppPermission.notifications,
        WalkthroughStep.battery || WalkthroughStep.oem => AppPermission.batteryOptimization,
      };

  static bool _satisfied(WalkthroughStep step, PermissionStatusModel s) => switch (step) {
        WalkthroughStep.location => s.location == PermissionState.granted,
        WalkthroughStep.backgroundLocation => s.backgroundLocation == PermissionState.granted,
        WalkthroughStep.notifications => s.notifications == PermissionState.granted,
        WalkthroughStep.battery => s.batteryOptimizationIgnored,
        WalkthroughStep.oem => false,
      };

  static bool _permanentlyDenied(WalkthroughStep step, PermissionStatusModel s) => switch (step) {
        WalkthroughStep.location => s.location == PermissionState.permanentlyDenied,
        WalkthroughStep.backgroundLocation => s.backgroundLocation == PermissionState.permanentlyDenied,
        WalkthroughStep.notifications => s.notifications == PermissionState.permanentlyDenied,
        WalkthroughStep.battery || WalkthroughStep.oem => false,
      };
}
