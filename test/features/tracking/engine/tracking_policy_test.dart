/// Tests for the auto-start rule `TrackingPolicy` (D8, §8.1): signed out,
/// disabled by admin, Shift windows on working days, outside the window,
/// midnight-crossing windows, Shift with no calendar, and Route/Continuous.
///
/// Status: active — part of `flutter test`.
library;

import 'package:dynaopsapp/features/tracking/data/tracking_policy_model.dart';
import 'package:dynaopsapp/features/tracking/engine/tracking_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-10-05 is a Monday (weekday 1 → 1 in the 0 = Sunday scheme).
  DateTime local(int day, int hour, [int minute = 0]) => DateTime(2026, 10, day, hour, minute);

  const dayShift = ShiftWindowModel(workingDays: [1, 2, 3, 4, 5], availableHoursPerDay: 8, startMinutes: 9 * 60);
  const nightShift = ShiftWindowModel(workingDays: [1], availableHoursPerDay: 8, startMinutes: 22 * 60);

  TrackingDecision decide(TrackingPolicyModel policy, DateTime now, {String? userId = 'u'}) =>
      TrackingPolicy.decide(userId: userId, policy: policy, now: now);

  test('no session → stopped, signedOut', () {
    final d = decide(TrackingPolicyModel.serverDefault, local(5, 10), userId: null);
    expect((d.collect, d.reason), (false, 'signedOut'));
  });

  test('admin flag off → stopped, disabledByAdmin', () {
    final d = decide(const TrackingPolicyModel(enabled: false, mode: 'Continuous'), local(5, 10));
    expect((d.collect, d.reason), (false, 'disabledByAdmin'));
  });

  test('Route and Continuous collect whenever signed in', () {
    expect(decide(TrackingPolicyModel.serverDefault, local(5, 3)).collect, true);
    expect(decide(const TrackingPolicyModel(enabled: true, mode: 'Continuous'), local(11, 23)).collect, true);
  });

  test('Shift with no calendar collects around the clock', () {
    expect(decide(const TrackingPolicyModel(enabled: true, mode: 'Shift'), local(11, 3)).collect, true);
  });

  test('Shift collects only inside the window on working days', () {
    const policy = TrackingPolicyModel(enabled: true, mode: 'Shift', shiftWindow: dayShift);
    expect(decide(policy, local(5, 9)).collect, true, reason: 'start is inclusive');
    expect(decide(policy, local(5, 16, 59)).collect, true);
    expect(decide(policy, local(5, 17)).reason, 'outsideShift', reason: 'end is exclusive');
    expect(decide(policy, local(5, 8, 59)).reason, 'outsideShift');
    expect(decide(policy, local(10, 10)).reason, 'outsideShift', reason: 'Saturday is not a working day');
  });

  test('a shift crossing midnight belongs to the day it started', () {
    const policy = TrackingPolicyModel(enabled: true, mode: 'Shift', shiftWindow: nightShift);
    expect(decide(policy, local(5, 23)).collect, true, reason: 'Monday 23:00');
    expect(decide(policy, local(6, 5, 59)).collect, true, reason: 'Tuesday 05:59, Monday shift');
    expect(decide(policy, local(6, 6)).reason, 'outsideShift');
    expect(decide(policy, local(6, 23)).reason, 'outsideShift', reason: 'Tuesday is not a working day');
  });

  test('RepDashboard fields parse into the model and back', () {
    final policy = TrackingPolicyModel.fromJson({
      'trackingEnabled': true,
      'trackingMode': 'Shift',
      'shiftWindow': {'workingDays': [0, 1], 'availableHoursPerDay': 7.5, 'dailyStartTime': '08:30'},
      'day': {'unrelated': true},
    });
    expect(policy.mode, 'Shift');
    expect(policy.shiftWindow!.startMinutes, 8 * 60 + 30);
    expect(TrackingPolicyModel.fromJson(policy.toJson()), policy);
  });

  test('trackingMode decides tracking: Always / Routes / Working hours on, anything else off', () {
    for (final mode in ['Continuous', 'Route', 'Shift']) {
      expect(TrackingPolicyModel.fromJson({'trackingEnabled': true, 'trackingMode': mode}).enabled, true, reason: mode);
    }
    final off = TrackingPolicyModel.fromJson({'trackingEnabled': true, 'trackingMode': 'Off'});
    expect(off.enabled, false);
    expect(decide(off, local(5, 10)).reason, 'disabledByAdmin');
    expect(TrackingPolicyModel.fromJson({'trackingEnabled': false, 'trackingMode': 'Continuous'}).enabled, false);
    expect(TrackingPolicyModel.fromJson(off.toJson()), off);
  });
}
