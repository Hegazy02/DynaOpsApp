/// `PermissionsCubit`: drives the mandatory permission walkthrough (§13) —
/// foreground location, precise (not approximate) location, background
/// location ("Allow all the time"), the phone's Location switch on,
/// notifications and the battery-optimisation exemption are **required**: the
/// rep cannot skip them, and the walkthrough always shows the first one still
/// missing (re-checked on every return from Settings and on every status
/// change, e.g. Location switched on from quick settings). A permanently denied
/// permission offers Settings instead of asking again. After the required
/// steps, a maker-specific hint is shown once per install and can be skipped.
/// Finishing records completion and asks the coordinator to (re)start tracking.
///
/// Why it exists: the app may not be used until tracking has every permission
/// it needs (product decision, 2026-10-07; enforced by `PermissionGate`); the
/// order and Android rules of the walkthrough are logic, kept out of the screen.
/// Status: used — provided on `/permissions`; tested in
/// `test/features/permissions/cubit/permissions_cubit_test.dart`.
library;

import 'dart:async';

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

  static const required = [
    WalkthroughStep.location,
    WalkthroughStep.preciseLocation,
    WalkthroughStep.backgroundLocation,
    WalkthroughStep.locationService,
    WalkthroughStep.notifications,
    WalkthroughStep.battery,
  ];

  StreamSubscription<PermissionStatusModel>? _changes;

  OemBrand? _oem;

  /// The maker hint was seen (this run, or the walkthrough was finished before).
  bool _oemSeen = true;

  List<WalkthroughStep> get _steps => [...required, if (_oem != null && !_oemSeen) WalkthroughStep.oem];

  Future<void> load() async {
    try {
      _oem = OemBrand.fromManufacturer((await _device.info()).manufacturer);
    } catch (_) {
      _oem = null;
    }
    _oemSeen = _permissions.walkthroughCompleted;
    // E.g. Location turned on from quick settings: move on without a resume.
    _changes ??= _permissions.changes.listen((_) => recheck());
    await _showNext(await _permissions.status());
  }

  /// The step's main button: request the permission (or open Settings).
  Future<void> allow() async {
    final current = state;
    if (current is! PermissionsStepShown || current.busy) return;
    emit(current.copyWith(busy: true));
    if (current.step == WalkthroughStep.oem) {
      await _permissions.openSettings('app');
      return skipHint();
    }
    if (current.needsSettings) {
      await _permissions.openSettings(current.step == WalkthroughStep.locationService ? 'location' : 'app');
      emit(current.copyWith(busy: false)); // recheck() runs when the rep comes back.
      return;
    }
    final status = await _permissions.request([_permissionFor(current.step)]);
    if (_satisfied(current.step, status)) return _showNext(status);
    emit(current.copyWith(busy: false, needsSettings: _permanentlyDenied(current.step, status)));
  }

  /// "Next" on the maker hint — the only step that can be skipped.
  Future<void> skipHint() async {
    _oemSeen = true;
    await _showNext(await _permissions.status());
  }

  /// Back from Settings: anything may have been granted — or revoked.
  Future<void> recheck() async {
    if (state is PermissionsFinished) return;
    await _showNext(await _permissions.status());
  }

  /// The first required step still missing, then the maker hint, then done.
  Future<void> _showNext(PermissionStatusModel status) async {
    final steps = _steps;
    final missing = required.where((step) => !_satisfied(step, status));
    final WalkthroughStep step;
    if (missing.isNotEmpty) {
      step = missing.first;
    } else if (steps.contains(WalkthroughStep.oem)) {
      step = WalkthroughStep.oem;
    } else {
      return _finish();
    }
    emit(PermissionsStepShown(
      step: step,
      index: steps.indexOf(step) + 1,
      total: steps.length,
      needsSettings: _permanentlyDenied(step, status),
      oem: _oem,
    ));
  }

  Future<void> _finish() async {
    await _permissions.setWalkthroughCompleted();
    await _coordinator.retry();
    if (!isClosed) emit(const PermissionsFinished());
  }

  @override
  Future<void> close() async {
    await _changes?.cancel();
    return super.close();
  }

  static AppPermission _permissionFor(WalkthroughStep step) => switch (step) {
        // Precise location and the Location switch are settings-only (needsSettings).
        WalkthroughStep.location || WalkthroughStep.preciseLocation || WalkthroughStep.locationService =>
          AppPermission.location,
        WalkthroughStep.backgroundLocation => AppPermission.backgroundLocation,
        WalkthroughStep.notifications => AppPermission.notifications,
        WalkthroughStep.battery || WalkthroughStep.oem => AppPermission.batteryOptimization,
      };

  static bool _satisfied(WalkthroughStep step, PermissionStatusModel s) => switch (step) {
        WalkthroughStep.location => s.location == PermissionState.granted,
        WalkthroughStep.preciseLocation => s.preciseLocation,
        WalkthroughStep.backgroundLocation => s.backgroundLocation == PermissionState.granted,
        WalkthroughStep.locationService => s.locationServiceEnabled,
        WalkthroughStep.notifications => s.notifications == PermissionState.granted,
        WalkthroughStep.battery => s.batteryOptimizationIgnored,
        WalkthroughStep.oem => false,
      };

  /// True when only a settings screen can fix [step]. Android re-asks for
  /// approximate → precise unreliably, so precise always goes to app settings;
  /// the Location switch has no in-app dialog at all.
  static bool _permanentlyDenied(WalkthroughStep step, PermissionStatusModel s) => switch (step) {
        WalkthroughStep.location => s.location == PermissionState.permanentlyDenied,
        WalkthroughStep.preciseLocation || WalkthroughStep.locationService => true,
        WalkthroughStep.backgroundLocation => s.backgroundLocation == PermissionState.permanentlyDenied,
        WalkthroughStep.notifications => s.notifications == PermissionState.permanentlyDenied,
        WalkthroughStep.battery || WalkthroughStep.oem => false,
      };
}
