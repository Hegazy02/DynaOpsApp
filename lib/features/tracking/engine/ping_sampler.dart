/// `PingSampler`: turns the 1 s GPS sample stream into the pings that are
/// stored and uploaded — one heartbeat ping every [heartbeat] (plus the first
/// sample), and optionally, like the old tracker (dyn_gis), a ping whenever the
/// device has moved [minDistanceMeters] (0 = off, the default) — with each
/// ping's speed measured over the whole window since the previous ping instead
/// of one instant reading.
///
/// Window speed is the larger of the mean Doppler speed of every sample in the
/// window and the path length over its duration, where the path only grows by
/// moves larger than the fixes' accuracy (so a parked phone adds nothing).
/// Below [stationaryMps] the ping reports 0.
///
/// Why it exists: one instant reading is 0 at every light or turn, Android
/// often reports `speed = 0` for fixes with no Doppler solution, and a parked
/// phone drifts at 0.2–0.9 m/s — all of which reached the server as wrong
/// speeds in the old tracker.
/// Status: used — by `TrackingEngine`; tested in
/// `test/features/tracking/engine/ping_sampler_test.dart`.
library;

import 'dart:math' as math;

import '../data/position_model.dart';
import 'fix_filter.dart';

class PingSampler {
  PingSampler({
    required this.minDistanceMeters,
    required this.heartbeat,
    this.stationaryMps = 0.5,
    this.noiseFloorMeters = 10,
  });

  final double minDistanceMeters;
  final Duration heartbeat;

  /// Window speeds under this (≈1.8 km/h) are GPS drift, reported as 0.
  final double stationaryMps;

  /// A path step must be at least this long, or the fixes' accuracy if larger.
  final double noiseFloorMeters;

  /// Path speed needs a window this long; shorter ones amplify one bad fix.
  static const _minPathWindow = Duration(seconds: 2);

  PositionModel? _lastPing;
  PositionModel? _latest;
  PositionModel? _anchor;
  DateTime? _windowStart;
  double _pathMeters = 0;
  double _dopplerSum = 0;
  int _dopplerCount = 0;

  /// Feeds one cleaned sample. Returns the ping to record when this is the
  /// first sample or (when enabled) the device moved [minDistanceMeters]
  /// since the last ping.
  PositionModel? add(PositionModel sample) {
    _latest = sample;
    _windowStart ??= sample.timestamp;
    final speed = sample.speed;
    if (speed != null) {
      _dopplerSum += speed;
      _dopplerCount++;
    }
    final anchor = _anchor;
    if (anchor == null) {
      _anchor = sample;
    } else {
      final step = FixFilter.distanceMeters(anchor, sample);
      if (step >= math.max(noiseFloorMeters, math.max(anchor.accuracy, sample.accuracy))) {
        _pathMeters += step;
        _anchor = sample;
      }
    }
    final last = _lastPing;
    if (last == null) return _emit(sample);
    if (minDistanceMeters > 0 && FixFilter.distanceMeters(last, sample) >= minDistanceMeters) return _emit(sample);
    return null;
  }

  /// The heartbeat ping: the newest sample, when it is fresh (younger than
  /// half the heartbeat) and no ping went out in the last half heartbeat.
  PositionModel? onHeartbeat(DateTime now) {
    final latest = _latest;
    if (latest == null || now.difference(latest.timestamp) * 2 > heartbeat) return null;
    final last = _lastPing;
    if (last != null && latest.timestamp.difference(last.timestamp) * 2 < heartbeat) return null;
    return _emit(latest);
  }

  void reset() {
    _lastPing = null;
    _latest = null;
    _resetWindow(null);
  }

  PositionModel _emit(PositionModel sample) {
    final window = sample.timestamp.difference(_windowStart ?? sample.timestamp);
    final doppler = _dopplerCount == 0 ? 0.0 : _dopplerSum / _dopplerCount;
    // The stretch since the last anchor is real once the window shows movement;
    // in a still window it is only noise and stays out.
    final anchor = _anchor;
    final tail = _pathMeters > 0 && anchor != null ? FixFilter.distanceMeters(anchor, sample) : 0.0;
    final path = window >= _minPathWindow ? (_pathMeters + tail) / (window.inMilliseconds / 1000) : 0.0;
    var speed = math.max(doppler, path);
    if (speed < stationaryMps) speed = 0;

    final last = _lastPing;
    final double? heading;
    if (speed == 0) {
      heading = null;
    } else if (sample.heading != null && (sample.speed ?? 0) >= 1) {
      heading = sample.heading; // receiver course is reliable once really moving
    } else if (last != null && FixFilter.distanceMeters(last, sample) >= noiseFloorMeters) {
      heading = FixFilter.bearingDegrees(last, sample);
    } else {
      heading = sample.heading;
    }

    final ping = sample.withVelocity(speed: speed, heading: heading);
    _lastPing = ping;
    _resetWindow(sample);
    return ping;
  }

  void _resetWindow(PositionModel? from) {
    _anchor = from;
    _windowStart = from?.timestamp;
    _pathMeters = 0;
    _dopplerSum = 0;
    _dopplerCount = 0;
  }
}
