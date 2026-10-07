/// `PositionModel`: one raw reading from the location provider (UTC time,
/// speed in m/s, heading in degrees; null when the provider gave none).
///
/// Why it exists: keeps `geolocator` types out of the engine and tests;
/// `LocationSource` converts to it, `FixFilter` cleans it, and only then does
/// it become a stored `LocationFixModel`.
/// Status: used — by `LocationSource`, `FixFilter`, `TrackingEngine`.
library;

import 'package:equatable/equatable.dart';

class PositionModel extends Equatable {
  const PositionModel({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.speed,
    this.heading,
    this.isMocked = false,
  });

  final double latitude;
  final double longitude;

  /// Metres (68 % confidence radius).
  final double accuracy;

  /// UTC.
  final DateTime timestamp;

  /// Metres per second.
  final double? speed;

  /// Degrees clockwise from true north.
  final double? heading;

  final bool isMocked;

  PositionModel copyWith({double? speed, double? heading}) => PositionModel(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        timestamp: timestamp,
        speed: speed ?? this.speed,
        heading: heading ?? this.heading,
        isMocked: isMocked,
      );

  /// Same fix with [speed] and [heading] replaced, nulls included.
  PositionModel withVelocity({required double? speed, required double? heading}) => PositionModel(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        timestamp: timestamp,
        speed: speed,
        heading: heading,
        isMocked: isMocked,
      );

  @override
  List<Object?> get props => [latitude, longitude, accuracy, timestamp, speed, heading, isMocked];
}
