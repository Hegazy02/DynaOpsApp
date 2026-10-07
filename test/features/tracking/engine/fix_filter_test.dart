/// Tests for `FixFilter`: poor accuracy, duplicate timestamps and impossible
/// jumps are rejected and counted; accepted fixes pass through unchanged (no
/// invented speed); distance and bearing helpers.
///
/// Status: active — part of `flutter test`.
library;

import 'package:dynaopsapp/features/tracking/data/position_model.dart';
import 'package:dynaopsapp/features/tracking/engine/fix_filter.dart';
import 'package:flutter_test/flutter_test.dart';

PositionModel at(int second, {double lat = 30, double lng = 31, double accuracy = 5, double? speed, double? heading}) =>
    PositionModel(
      latitude: lat,
      longitude: lng,
      accuracy: accuracy,
      timestamp: DateTime.utc(2026, 10, 6, 9).add(Duration(seconds: second)),
      speed: speed,
      heading: heading,
    );

void main() {
  late FixFilter filter;
  setUp(() => filter = FixFilter());

  test('rejects poor accuracy', () {
    expect(filter.accept(at(0, accuracy: 150)), isNull);
    expect(filter.rejected, {'accuracy': 1});
  });

  test('rejects duplicates and out-of-order fixes', () {
    filter.accept(at(10));
    expect(filter.accept(at(10)), isNull);
    expect(filter.accept(at(5)), isNull);
    expect(filter.rejected['duplicate'], 2);
  });

  test('rejects impossible jumps (≈1 km in 5 s)', () {
    filter.accept(at(0));
    expect(filter.accept(at(5, lat: 30.009)), isNull);
    expect(filter.rejected['jump'], 1);
  });

  test('passes accepted fixes through unchanged — no invented speed', () {
    filter.accept(at(0));
    expect(filter.accept(at(10, lat: 30.001))!.speed, isNull);
    expect(filter.accept(at(20, lat: 30.002, speed: 3, heading: 90)), at(20, lat: 30.002, speed: 3, heading: 90));
  });

  test('distance and bearing helpers', () {
    expect(FixFilter.distanceMeters(at(0), at(0, lat: 30.001)), closeTo(111.2, 0.5));
    expect(FixFilter.bearingDegrees(at(0), at(0, lng: 31.001)), closeTo(90, 1));
  });
}
