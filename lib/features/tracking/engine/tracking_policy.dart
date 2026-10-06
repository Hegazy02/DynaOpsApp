/// `TrackingPolicy`: pure auto-start rule (D8, §8.1). No session → stopped
/// (`signedOut`); admin flag off → stopped (`disabledByAdmin`); Shift mode
/// with a window → collect only inside it (`outsideShift` otherwise,
/// midnight-crossing windows included); everything else → collect.
///
/// Why it exists: the rule decides battery use and compliance, so it is a
/// small pure function with exhaustive tests.
/// Status: used — by `TrackingEngine` on start, every tick and every command;
/// tested in `test/features/tracking/engine/tracking_policy_test.dart`.
library;

import '../data/tracking_policy_model.dart';
import '../data/tracking_status_model.dart';

class TrackingDecision {
  const TrackingDecision.collect() : collect = true, reason = null;
  const TrackingDecision.stop(String this.reason) : collect = false;

  final bool collect;
  final String? reason;
}

abstract final class TrackingPolicy {
  /// [userId] is the stored session's user (kept after expiry, D6); null when signed out.
  static TrackingDecision decide({
    required String? userId,
    required TrackingPolicyModel policy,
    required DateTime now,
  }) {
    if (userId == null) return const TrackingDecision.stop(TrackingReason.signedOut);
    if (!policy.enabled) return const TrackingDecision.stop(TrackingReason.disabledByAdmin);
    final window = policy.shiftWindow;
    if (policy.mode == 'Shift' && window != null && !isInsideShift(window, now)) {
      return const TrackingDecision.stop(TrackingReason.outsideShift);
    }
    return const TrackingDecision.collect();
  }

  /// `[start, start + hours)` in device-local time, starting on a working day
  /// (0 = Sunday). Checks today's and yesterday's shift for midnight crossings.
  static bool isInsideShift(ShiftWindowModel window, DateTime now) {
    final local = now.toLocal();
    final length = Duration(minutes: (window.availableHoursPerDay * 60).round());
    if (length <= Duration.zero) return false;
    for (final daysBack in const [0, 1]) {
      final day = DateTime(local.year, local.month, local.day - daysBack);
      if (!window.workingDays.contains(day.weekday % 7)) continue;
      final start = day.add(Duration(minutes: window.startMinutes));
      if (!local.isBefore(start) && local.isBefore(start.add(length))) return true;
    }
    return false;
  }
}
