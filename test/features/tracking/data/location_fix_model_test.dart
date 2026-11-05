/// Tests for `LocationFixModel`: the `POST LocationPings/batch` ping shape
/// (naive timestamp, integer km/h and degrees, `source: Gps`), row and
/// isolate-message round-trips, and the `tracking.location` JSON.
///
/// Status: active — part of `flutter test`.
library;

import 'package:dynaopsapp/features/tracking/data/location_fix_model.dart';
import 'package:dynaopsapp/features/tracking/data/position_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fix = LocationFixModel(
    id: 'f1',
    userId: 'u1',
    position: PositionModel(
      latitude: 24.7136,
      longitude: 46.6753,
      accuracy: 4.5,
      timestamp: DateTime.utc(2026, 10, 6, 9, 59, 3, 750),
      speed: 7.9,
      heading: 181.6,
    ),
  );

  test('wire ping matches the ingest contract (UTC mode)', () {
    expect(fix.toWirePing(localTimestamps: false), {
      'at': '2026-10-06T09:59:03',
      'lat': 24.7136,
      'lng': 46.6753,
      'speedKmh': 28,
      'headingDeg': 182,
      'source': 'Gps',
    });
  });

  test('default mode writes Saudi time without an offset', () {
    expect(fix.toWirePing(localTimestamps: true)['at'], '2026-10-06T12:59:03');
  });

  test('missing speed and heading are sent as 0', () {
    final still = LocationFixModel(
      id: 'f2',
      userId: 'u1',
      position: PositionModel(latitude: 1, longitude: 2, accuracy: 3, timestamp: DateTime.utc(2026)),
    );
    final ping = still.toWirePing(localTimestamps: false);
    expect((ping['speedKmh'], ping['headingDeg']), (0, 0));
  });

  test('row and message round-trips keep everything', () {
    final row = fix.toRow(createdAt: DateTime.utc(2026));
    expect(LocationFixModel.fromRow(row), fix);
    expect(LocationFixModel.fromMessage(fix.toMessage()), fix);
  });

  test('bridge JSON is the tracking.location event shape', () {
    expect(fix.toBridgeJson(), containsPair('storedLocally', true));
    expect(fix.toBridgeJson()['timestamp'], '2026-10-06T09:59:03.750Z');
  });
}
