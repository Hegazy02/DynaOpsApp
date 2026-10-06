/// Tests for `FixFilter`: poor accuracy, duplicate timestamps and impossible
/// jumps are rejected and counted; missing speed/heading is derived from the
/// previous fix on short gaps only; GPS noise reads as standing still.
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

  test('derives speed and heading when the receiver gave none', () {
    filter.accept(at(0));
    final next = filter.accept(at(10, lat: 30.001))!; // ≈111 m north in 10 s
    expect(next.speed, closeTo(11.1, 0.2));
    expect(next.heading, closeTo(0, 1));
  });

  test('keeps the receiver values when present', () {
    filter.accept(at(0));
    final next = filter.accept(at(10, lat: 30.001, speed: 3, heading: 90))!;
    expect((next.speed, next.heading), (3, 90));
  });

  test('movement within GPS noise reads as standing still', () {
    filter.accept(at(0));
    final next = filter.accept(at(5, lat: 30.00002))!;
    expect(next.speed, 0);
    expect(next.heading, isNull);
  });

  test('no derivation across a long gap', () {
    filter.accept(at(0));
    expect(filter.accept(at(600, lat: 30.01))!.speed, isNull);
  });
}
