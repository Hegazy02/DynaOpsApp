/// Permission wire types (§6.4): `PermissionState` (granted | denied |
/// permanentlyDenied | notDetermined | restricted), `AppPermission` (what the
/// bridge can request) and `PermissionStatusModel`, the snapshot
/// `permissions.status` returns (incl. precise location and the phone's
/// Location switch), with `trackingReady` — the single rule for "everything
/// tracking needs is in place".
///
/// Why it exists: a fixed vocabulary shared with Angular, independent of
/// `permission_handler`'s own enums.
/// Status: used — by `PermissionsRepository`, `PermissionsHandler`,
/// `PermissionGate` and `PermissionsCubit`.
library;

import 'package:equatable/equatable.dart';

/// Wire values of `permissions.status` (§6.4).
enum PermissionState {
  granted('granted'),
  denied('denied'),
  permanentlyDenied('permanentlyDenied'),
  notDetermined('notDetermined'),
  restricted('restricted');

  const PermissionState(this.wire);
  final String wire;
}

/// Permissions the bridge can be asked about.
enum AppPermission {
  location('location'),
  backgroundLocation('backgroundLocation'),
  notifications('notifications'),
  camera('camera'),
  batteryOptimization('batteryOptimization');

  const AppPermission(this.wire);
  final String wire;

  static AppPermission? fromWire(String value) {
    for (final p in values) {
      if (p.wire == value) return p;
    }
    return null;
  }
}

class PermissionStatusModel extends Equatable {
  const PermissionStatusModel({
    required this.location,
    required this.backgroundLocation,
    required this.notifications,
    required this.camera,
    required this.batteryOptimizationIgnored,
    required this.preciseLocation,
    required this.locationServiceEnabled,
  });

  final PermissionState location;
  final PermissionState backgroundLocation;
  final PermissionState notifications;
  final PermissionState camera;
  final bool batteryOptimizationIgnored;

  /// "Precise" rather than "Approximate" (Android 12+). Approximate fixes are
  /// 1–3 km off; the fix filter drops them, so nothing would be recorded.
  final bool preciseLocation;

  /// The phone's Location switch (quick settings) is on.
  final bool locationServiceEnabled;

  /// Everything background tracking needs, i.e. what the permission gate
  /// requires before the app can be used: precise location "all the time"
  /// with the phone's Location switch on, notifications (the tracking
  /// notification must be visible) and the battery-optimisation exemption.
  /// Camera is not required.
  bool get trackingReady =>
      location == PermissionState.granted &&
      preciseLocation &&
      backgroundLocation == PermissionState.granted &&
      locationServiceEnabled &&
      notifications == PermissionState.granted &&
      batteryOptimizationIgnored;

  Map<String, dynamic> toJson() => {
        'location': location.wire,
        'backgroundLocation': backgroundLocation.wire,
        'notifications': notifications.wire,
        'camera': camera.wire,
        'batteryOptimizationIgnored': batteryOptimizationIgnored,
        'preciseLocation': preciseLocation,
        'locationServiceEnabled': locationServiceEnabled,
      };

  @override
  List<Object?> get props => [
        location,
        backgroundLocation,
        notifications,
        camera,
        batteryOptimizationIgnored,
        preciseLocation,
        locationServiceEnabled,
      ];
}
