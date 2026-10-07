/// Tests for `PingSampler`: first sample and every 25 m become pings, the
/// heartbeat sends the fresh newest sample but not right after another ping
/// nor from a stale one, and window speed — GPS drift reads as 0, a stop at a
/// light inside a moving window is not 0, and a receiver reporting speed 0
/// while moving falls back to the path speed.
///
/// Status: active — part of `flutter test`.
library;

import 'package:dynaopsapp/features/tracking/data/position_model.dart';
import 'package:dynaopsapp/features/tracking/engine/ping_sampler.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 10, 6, 9);

/// [north] metres north of the origin, [second]s after t0.
PositionModel at(int second, {double north = 0, double accuracy = 5, double? speed, double? heading}) =>
    PositionModel(
      latitude: 30 + north / 111195,
      longitude: 31,
      accuracy: accuracy,
      timestamp: _t0.add(Duration(seconds: second)),
      speed: speed,
      heading: heading,
    );

void main() {
  late PingSampler sampler;
  setUp(() => sampler = PingSampler(minDistanceMeters: 25, heartbeat: const Duration(seconds: 30)));

  test('the first sample is a ping, then only every 25 m', () {
    expect(sampler.add(at(0)), isNotNull);
    expect(sampler.add(at(1, north: 10)), isNull);
    expect(sampler.add(at(2, north: 20)), isNull);
    expect(sampler.add(at(3, north: 26)), isNotNull);
  });

  test('distance 0 (default): only the first sample and heartbeats, 30 s speed averaged', () {
    sampler = PingSampler(minDistanceMeters: 0, heartbeat: const Duration(seconds: 30));
    expect(sampler.add(at(0, speed: 14)), isNotNull);
    for (var s = 1; s <= 30; s++) {
      expect(sampler.add(at(s, north: s * 14.0, speed: s == 30 ? 0 : 14)), isNull); // 420 m, never a movement ping
    }
    final ping = sampler.onHeartbeat(_t0.add(const Duration(seconds: 30)))!;
    expect(ping.speed, closeTo(14, 0.5)); // ≈50 km/h, though the last reading said 0
  });

  test('a parked phone drifting at 0.2–0.9 m/s reports 0 on the heartbeat', () {
    sampler.add(at(0, speed: 0));
    for (var s = 1; s <= 30; s++) {
      sampler.add(at(s, north: (s % 3).toDouble(), speed: s.isEven ? 0.2 : 0.4));
    }
    final ping = sampler.onHeartbeat(_t0.add(const Duration(seconds: 30)))!;
    expect(ping.speed, 0);
    expect(ping.heading, isNull);
  });

  test('stopping at a light does not zero the speed of a moving window', () {
    sampler.add(at(0, speed: 10));
    PositionModel? ping;
    for (var s = 1; s <= 3; s++) {
      ping = sampler.add(at(s, north: s * 10.0, speed: s == 3 ? 0 : 10)); // 30 m, last reading 0
    }
    expect(ping, isNotNull);
    expect(ping!.speed, greaterThan(5));
  });

  test('a receiver reporting speed 0 while moving falls back to the path speed', () {
    sampler.add(at(0, speed: 0));
    PositionModel? ping;
    for (var s = 2; s <= 6 && ping == null; s += 2) {
      ping = sampler.add(at(s, north: s * 5.0, speed: 0)); // 5 m/s, Doppler says 0
    }
    expect(ping!.speed, closeTo(5, 0.2));
    expect(ping.heading, closeTo(0, 1));
  });

  test('uses the receiver course once really moving', () {
    sampler.add(at(0, speed: 12, heading: 45));
    final ping = sampler.add(at(3, north: 36, speed: 12, heading: 44))!;
    expect(ping.speed, closeTo(12, 0.1));
    expect(ping.heading, 44);
  });

  test('heartbeat: fresh newest sample, never right after a ping, never stale', () {
    sampler.add(at(0));
    sampler.add(at(10, north: 1));
    expect(sampler.onHeartbeat(_t0.add(const Duration(seconds: 11))), isNull, reason: 'ping 10 s ago');
    sampler.add(at(29, north: 2));
    expect(sampler.onHeartbeat(_t0.add(const Duration(seconds: 30)))?.timestamp, at(29).timestamp);
    sampler.add(at(31, north: 2));
    expect(sampler.onHeartbeat(_t0.add(const Duration(seconds: 90))), isNull, reason: 'newest sample is stale');
  });
}
