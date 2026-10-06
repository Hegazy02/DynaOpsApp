/// `FixFilter`: cleans raw positions before they are stored (§8.2) — drops
/// fixes with poor accuracy, exact duplicates and impossible jumps (counting
/// each reason for diagnostics), and derives speed/heading from the previous
/// fix when the receiver reported none (short gaps only).
///
/// Why it exists: bad fixes waste uploads and draw false routes; the server
/// stores speed, and Android often omits it when GPS is duty-cycled.
/// Status: used — by `TrackingEngine` for every fix; tested in
/// `test/features/tracking/engine/fix_filter_test.dart`.
library;

import 'dart:math' as math;

import '../data/position_model.dart';

class FixFilter {
  FixFilter({this.maxAccuracyMeters = 100, this.maxSpeedMps = 70});

  final double maxAccuracyMeters;

  /// ~250 km/h: anything faster between two fixes is a GPS jump.
  final double maxSpeedMps;

  static const _maxDerivationGap = Duration(minutes: 2);
  static const _minDerivationMeters = 10.0;

  PositionModel? _last;
  final Map<String, int> rejected = {};

  /// The fix to store, or null when it was rejected.
  PositionModel? accept(PositionModel next) {
    final last = _last;
    if (next.accuracy > maxAccuracyMeters) return _reject('accuracy');
    if (last != null) {
      if (!next.timestamp.isAfter(last.timestamp)) return _reject('duplicate');
      final seconds = next.timestamp.difference(last.timestamp).inMilliseconds / 1000;
      final meters = distanceMeters(last, next);
      if (meters / seconds > maxSpeedMps) return _reject('jump');
    }
    final enriched = _deriveVelocity(next, last);
    _last = enriched;
    return enriched;
  }

  void reset() => _last = null;

  PositionModel _deriveVelocity(PositionModel next, PositionModel? last) {
    if (last == null || (next.speed != null && next.heading != null)) return next;
    final gap = next.timestamp.difference(last.timestamp);
    if (gap > _maxDerivationGap) return next;
    final meters = distanceMeters(last, next);
    if (meters < math.max(_minDerivationMeters, next.accuracy)) {
      return next.copyWith(speed: next.speed ?? 0);
    }
    return next.copyWith(
      speed: next.speed ?? meters / (gap.inMilliseconds / 1000),
      heading: next.heading ?? bearingDegrees(last, next),
    );
  }

  PositionModel? _reject(String reason) {
    rejected[reason] = (rejected[reason] ?? 0) + 1;
    return null;
  }

  static double distanceMeters(PositionModel a, PositionModel b) {
    const earthRadius = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
  }

  static double bearingDegrees(PositionModel a, PositionModel b) {
    final y = math.sin(_rad(b.longitude - a.longitude)) * math.cos(_rad(b.latitude));
    final x = math.cos(_rad(a.latitude)) * math.sin(_rad(b.latitude)) -
        math.sin(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * math.cos(_rad(b.longitude - a.longitude));
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double _rad(double degrees) => degrees * math.pi / 180;
}
