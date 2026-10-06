/// Tests for `backoffDelay`: doubling from 5 s, ±20 % jitter, 15 min cap.
///
/// Status: active — part of `flutter test`.
library;

import 'dart:math';

import 'package:dynaopsapp/features/sync/engine/backoff.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedRandom implements Random {
  _FixedRandom(this.value);
  final double value;
  @override
  double nextDouble() => value;
  @override
  bool nextBool() => false;
  @override
  int nextInt(int max) => 0;
}

void main() {
  test('doubles from 5 s with no jitter at the midpoint', () {
    final mid = _FixedRandom(0.5);
    expect(
      [1, 2, 3, 4].map((n) => backoffDelay(n, random: mid).inSeconds),
      [5, 10, 20, 40],
    );
  });

  test('jitter stays within ±20 %', () {
    expect(backoffDelay(3, random: _FixedRandom(0)).inMilliseconds, 16000);
    expect(backoffDelay(3, random: _FixedRandom(1)).inMilliseconds, 24000);
  });

  test('never exceeds 15 minutes', () {
    expect(backoffDelay(50, random: _FixedRandom(1)), maxBackoff);
  });
}
