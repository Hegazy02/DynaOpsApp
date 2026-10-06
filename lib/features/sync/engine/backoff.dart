/// `backoffDelay`: exponential retry delay for failed upload cycles (§11) —
/// 5 s, 10 s, 20 s … capped at 15 min, with ±20 % jitter so a fleet coming
/// back online does not retry in lockstep.
///
/// Why it exists: a pure function the sync engine and its tests share.
/// Status: used — by `SyncManager`; tested in
/// `test/features/sync/engine/backoff_test.dart`.
library;

import 'dart:math' as math;

const _base = Duration(seconds: 5);
const maxBackoff = Duration(minutes: 15);

/// Delay before the next automatic cycle after [failures] consecutive failures (≥ 1).
Duration backoffDelay(int failures, {math.Random? random}) {
  final exponent = math.min(math.max(failures - 1, 0), 20);
  final raw = _base.inMilliseconds * math.pow(2, exponent);
  final capped = math.min(raw, maxBackoff.inMilliseconds.toDouble());
  final jitter = 0.8 + (random ?? math.Random()).nextDouble() * 0.4;
  return Duration(milliseconds: math.min(capped * jitter, maxBackoff.inMilliseconds.toDouble()).round());
}
