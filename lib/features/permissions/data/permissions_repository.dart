/// `PermissionsRepository`: wraps `permission_handler` (§13) — reads the
/// status snapshot, requests permissions one at a time without looping on
/// `permanentlyDenied`, asks for CAMERA once per install so the WebView file
/// chooser can offer the camera, opens system settings, and publishes changes.
///
/// Why it exists: Android permission rules (background location only after
/// foreground, battery exemption dialog) live here, not in handlers or Cubits.
/// Status: used — registered in both locators; called by `ShellCubit`,
/// `AppHandler`, `PermissionsHandler`, the walkthrough (`PermissionsCubit`),
/// `TrackingCubit`, `TrackingRepository` and `TrackingEngine`.
library;

import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/failure.dart';
import '../../../core/storage/prefs_store.dart';
import 'permission_status_model.dart';

/// `permission_handler` wrapper (§13). Requests are sequential and never loop
/// on `permanentlyDenied` — callers offer `app.openSettings` instead.
class PermissionsRepository {
  PermissionsRepository(this._prefs);

  static const _cameraAskedKey = 'camera_permission_asked';
  static const _walkthroughDoneKey = 'permission_walkthrough_done';

  /// The rep finished (or skipped through) the walkthrough once (§13).
  bool get walkthroughCompleted => _prefs.getBool(_walkthroughDoneKey);

  Future<void> setWalkthroughCompleted() => _prefs.setBool(_walkthroughDoneKey, true);

  final PrefsStore _prefs;
  final _changes = StreamController<PermissionStatusModel>.broadcast();
  PermissionStatusModel? _last;

  Stream<PermissionStatusModel> get changes => _changes.stream;

  Future<PermissionStatusModel> status() async {
    try {
      return PermissionStatusModel(
        location: _map(await Permission.location.status),
        backgroundLocation: _map(await Permission.locationAlways.status),
        notifications: _map(await Permission.notification.status),
        camera: _map(await Permission.camera.status),
        batteryOptimizationIgnored: await Permission.ignoreBatteryOptimizations.isGranted,
      );
    } catch (e) {
      throw PlatformFailure('Could not read permissions: $e');
    }
  }

  /// Requests [permissions] one at a time, in the order given.
  Future<PermissionStatusModel> request(List<AppPermission> permissions) async {
    try {
      for (final permission in permissions) {
        final handle = _handleFor(permission);
        if (permission == AppPermission.backgroundLocation &&
            !await Permission.location.isGranted) {
          continue; // Android only offers "all the time" after foreground location.
        }
        if (await handle.isPermanentlyDenied) continue;
        await handle.request();
      }
    } catch (e) {
      throw PlatformFailure('Permission request failed: $e');
    }
    return refresh();
  }

  /// Re-reads the status and publishes it when it changed (called on resume).
  Future<PermissionStatusModel> refresh() async {
    final current = await status();
    if (current != _last) {
      final hadPrevious = _last != null;
      _last = current;
      if (hadPrevious) _changes.add(current);
    }
    return current;
  }

  /// Asks for CAMERA once per install. The WebView's file chooser only offers
  /// the camera when CAMERA is granted, and its prompt cannot be intercepted (§5.4).
  Future<void> requestCameraOnce() async {
    if (_prefs.getBool(_cameraAskedKey)) return;
    await _prefs.setBool(_cameraAskedKey, true);
    try {
      await Permission.camera.request();
    } catch (_) {
      // Gallery upload still works without it.
    }
  }

  Future<bool> isLocationGranted() => Permission.location.isGranted;

  Future<bool> requestLocation() async {
    final result = await request(const [AppPermission.location]);
    return result.location == PermissionState.granted;
  }

  /// Opens the system screen for [screen] (`app | location | battery | notifications`).
  ///
  /// `permission_handler` can only open the app's own settings page, so every
  /// screen lands there except battery, which raises the exemption dialog.
  Future<void> openSettings(String screen) async {
    try {
      if (screen == 'battery') {
        await Permission.ignoreBatteryOptimizations.request();
        return;
      }
      if (!await openAppSettings()) {
        throw const UnsupportedFailure('Could not open the settings screen.');
      }
    } on Failure {
      rethrow;
    } catch (e) {
      throw PlatformFailure('Could not open settings: $e');
    }
  }

  static Permission _handleFor(AppPermission permission) => switch (permission) {
        AppPermission.location => Permission.location,
        AppPermission.backgroundLocation => Permission.locationAlways,
        AppPermission.notifications => Permission.notification,
        AppPermission.camera => Permission.camera,
        AppPermission.batteryOptimization => Permission.ignoreBatteryOptimizations,
      };

  static PermissionState _map(PermissionStatus status) => switch (status) {
        PermissionStatus.granted || PermissionStatus.limited || PermissionStatus.provisional =>
          PermissionState.granted,
        PermissionStatus.denied => PermissionState.denied,
        PermissionStatus.permanentlyDenied => PermissionState.permanentlyDenied,
        PermissionStatus.restricted => PermissionState.restricted,
      };

  Future<void> dispose() => _changes.close();
}
