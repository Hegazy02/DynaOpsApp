/// Permission wire types (§6.4): `PermissionState` (granted | denied |
/// permanentlyDenied | notDetermined | restricted), `AppPermission` (what the
/// bridge can request) and `PermissionStatusModel`, the snapshot
/// `permissions.status` returns.
///
/// Why it exists: a fixed vocabulary shared with Angular, independent of
/// `permission_handler`'s own enums.
/// Status: used — by `PermissionsRepository` and `PermissionsHandler`.
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
  });

  final PermissionState location;
  final PermissionState backgroundLocation;
  final PermissionState notifications;
  final PermissionState camera;
  final bool batteryOptimizationIgnored;

  Map<String, dynamic> toJson() => {
        'location': location.wire,
        'backgroundLocation': backgroundLocation.wire,
        'notifications': notifications.wire,
        'camera': camera.wire,
        'batteryOptimizationIgnored': batteryOptimizationIgnored,
      };

  @override
  List<Object?> get props =>
      [location, backgroundLocation, notifications, camera, batteryOptimizationIgnored];
}
