/// `LocationRepository`: store-first writes of accepted fixes (§8.2), counts
/// and the latest fix per user, and `latestFix()` for `tracking.latest` —
/// a recent stored fix when fresh enough, otherwise a one-shot reading.
///
/// Why it exists: the points store is the source of truth; nothing is emitted
/// or uploaded before the row is written.
/// Status: used — by `TrackingEngine` (writes, service isolate) and
/// `TrackingHandler` (`tracking.latest`, UI isolate).
library;

import 'package:uuid/uuid.dart';

import '../../../core/network/failure.dart';
import 'location_fix_model.dart';
import 'location_points_dao.dart';
import 'location_source.dart';
import 'position_model.dart';

class LatestFix {
  const LatestFix(this.position, {required this.fromCache});
  final PositionModel position;
  final bool fromCache;

  /// `tracking.latest` data (§6.4).
  Map<String, dynamic> toJson() => {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': position.timestamp.toUtc().toIso8601String(),
        'source': fromCache ? 'cache' : 'fresh',
      };
}

class LocationRepository {
  LocationRepository(this._dao, this._source, {Uuid? uuid, DateTime Function()? clock})
      : _uuid = uuid ?? const Uuid(),
        _now = clock ?? DateTime.now;

  final LocationPointsDao _dao;
  final LocationSource _source;
  final Uuid _uuid;
  final DateTime Function() _now;

  /// Writes [position] for [userId] and returns the stored fix. Throws [DatabaseFailure].
  Future<LocationFixModel> store(PositionModel position, {required String userId}) async {
    final fix = LocationFixModel(id: _uuid.v4(), userId: userId, position: position);
    try {
      await _dao.insert(fix, now: _now());
    } catch (e) {
      throw DatabaseFailure('Could not store a fix: $e');
    }
    return fix;
  }

  Future<PointCounts> counts(String userId) async {
    try {
      return await _dao.counts(userId);
    } catch (e) {
      throw DatabaseFailure('Could not count fixes: $e');
    }
  }

  /// A stored fix of [userId] younger than [maxAge], else a fresh reading
  /// (15 s limit, under the 20 s Angular gives `tracking.latest`).
  /// Throws [PermissionFailure] / [LocationFailure].
  Future<LatestFix> latestFix({
    required String? userId,
    required Duration maxAge,
    required bool highAccuracy,
  }) async {
    if (userId != null) {
      final cached = await _dao.latest(userId);
      if (cached != null && _now().difference(cached.position.timestamp) <= maxAge) {
        return LatestFix(cached.position, fromCache: true);
      }
    }
    if (await _source.access() != LocationAccess.granted) {
      throw const PermissionFailure('Location permission is required.');
    }
    if (!await _source.isServiceEnabled()) {
      throw const LocationFailure('Location services are off.', disabled: true);
    }
    final fresh = await _source.current(highAccuracy: highAccuracy, timeLimit: const Duration(seconds: 15));
    return LatestFix(fresh, fromCache: false);
  }
}
