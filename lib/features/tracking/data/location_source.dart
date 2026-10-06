/// `LocationSource` (swappable interface, D3) and `GeolocatorLocationSource`:
/// position stream, one-shot fix, provider on/off and location-permission
/// checks, all converted to `PositionModel` and `Failure`s.
///
/// Why it exists: the engine never imports `geolocator`, so the stack can be
/// replaced (e.g. by a paid SDK) by writing one class.
/// Status: used — by `TrackingEngine` (service isolate) and
/// `LocationRepository.latestFix` (UI isolate).
library;

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../core/network/failure.dart';
import 'position_model.dart';

/// Foreground location permission as the engine needs it.
enum LocationAccess { granted, denied, permanentlyDenied }

abstract interface class LocationSource {
  /// Continuous fixes. Errors arrive as [PermissionFailure] / [LocationFailure].
  Stream<PositionModel> positions({required Duration interval, required double distanceFilter});

  /// One fix now. Throws [PermissionFailure] / [LocationFailure].
  Future<PositionModel> current({required bool highAccuracy, required Duration timeLimit});

  Future<bool> isServiceEnabled();

  Stream<bool> serviceEnabledChanges();

  Future<LocationAccess> access();
}

class GeolocatorLocationSource implements LocationSource {
  @override
  Stream<PositionModel> positions({required Duration interval, required double distanceFilter}) {
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter.round(),
      intervalDuration: interval,
    );
    return Geolocator.getPositionStream(locationSettings: settings)
        .map(_toModel)
        .handleError((Object e) => throw _toFailure(e));
  }

  @override
  Future<PositionModel> current({required bool highAccuracy, required Duration timeLimit}) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
          timeLimit: timeLimit,
        ),
      );
      return _toModel(position);
    } catch (e) {
      throw _toFailure(e);
    }
  }

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Stream<bool> serviceEnabledChanges() =>
      Geolocator.getServiceStatusStream().map((status) => status == ServiceStatus.enabled);

  @override
  Future<LocationAccess> access() async {
    return switch (await Geolocator.checkPermission()) {
      LocationPermission.always || LocationPermission.whileInUse => LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.permanentlyDenied,
      LocationPermission.denied || LocationPermission.unableToDetermine => LocationAccess.denied,
    };
  }

  static PositionModel _toModel(Position p) => PositionModel(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracy: p.accuracy,
        timestamp: p.timestamp.toUtc(),
        speed: p.hasSpeed && p.speed >= 0 ? p.speed : null,
        heading: p.hasHeading && p.heading >= 0 ? p.heading : null,
        isMocked: p.isMocked,
      );

  static Failure _toFailure(Object e) => switch (e) {
        Failure() => e,
        PermissionDeniedException() => PermissionFailure(e.message ?? 'Location permission denied.'),
        LocationServiceDisabledException() => const LocationFailure('Location services are off.', disabled: true),
        TimeoutException() => const LocationFailure('No location fix in time.'),
        _ => LocationFailure('Location error: $e'),
      };
}
