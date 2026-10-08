/// Tests for `PermissionGate`: for a tracked rep every app route redirects to
/// `/permissions` until tracking has all it needs (incl. the Location switch
/// on and precise location); a rep whose tracking is off, or whose
/// `RepDashboard` has not answered yet, is never blocked and
/// is let out of a walkthrough the gate forced; the walkthrough, diagnostics
/// and the request inspector stay open; an unreadable status fails closed;
/// each permission or policy change notifies the router.
///
/// Status: active — part of `flutter test`.
library;

import 'dart:async';

import 'package:dynaopsapp/core/router/permission_gate.dart';
import 'package:dynaopsapp/features/permissions/data/permission_status_model.dart';
import 'package:dynaopsapp/features/permissions/data/permissions_repository.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_policy_model.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_policy_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPermissions extends Mock implements PermissionsRepository {}

class _MockPolicies extends Mock implements TrackingPolicyRepository {}

PermissionStatusModel status({bool background = true, bool locationOn = true, bool precise = true}) =>
    PermissionStatusModel(
      location: PermissionState.granted,
      backgroundLocation: background ? PermissionState.granted : PermissionState.denied,
      notifications: PermissionState.granted,
      camera: PermissionState.denied,
      batteryOptimizationIgnored: true,
      preciseLocation: precise,
      locationServiceEnabled: locationOn,
    );

const untracked = TrackingPolicyModel(enabled: false, mode: 'Continuous');

void main() {
  late _MockPermissions permissions;
  late _MockPolicies policies;
  late StreamController<PermissionStatusModel> changes;
  late StreamController<TrackingPolicyModel> policyChanges;
  late PermissionGate gate;

  setUp(() {
    permissions = _MockPermissions();
    policies = _MockPolicies();
    changes = StreamController.broadcast();
    policyChanges = StreamController.broadcast();
    when(() => permissions.changes).thenAnswer((_) => changes.stream);
    when(() => policies.changes).thenAnswer((_) => policyChanges.stream);
    when(() => policies.trackingRequired()).thenAnswer((_) async => true);
    gate = PermissionGate(permissions, policies);
  });

  tearDown(() async {
    gate.dispose();
    await changes.close();
    await policyChanges.close();
  });

  test('a tracked rep is blocked while anything tracking needs is missing', () async {
    when(() => permissions.status()).thenAnswer((_) async => status(background: false));
    expect(await gate.redirect('/'), '/permissions');
  });

  test('the phone\'s Location switch off or approximate location blocks a tracked rep', () async {
    when(() => permissions.status()).thenAnswer((_) async => status(locationOn: false));
    expect(await gate.redirect('/'), '/permissions');
    when(() => permissions.status()).thenAnswer((_) async => status(precise: false));
    expect(await gate.redirect('/'), '/permissions');
  });

  test('the app opens once everything is granted', () async {
    when(() => permissions.status()).thenAnswer((_) async => status());
    expect(await gate.redirect('/'), isNull);
  });

  test('a rep whose tracking is off is never blocked', () async {
    when(() => policies.trackingRequired()).thenAnswer((_) async => false);
    when(() => permissions.status()).thenAnswer((_) async => status(background: false, locationOn: false));
    expect(await gate.redirect('/'), isNull);
  });

  test('a forced walkthrough lets the rep out once tracking turns out to be off', () async {
    when(() => permissions.status()).thenAnswer((_) async => status(locationOn: false));
    expect(await gate.redirect('/'), '/permissions');
    expect(await gate.redirect('/permissions'), isNull, reason: 'still tracked');
    when(() => policies.trackingRequired()).thenAnswer((_) async => false);
    expect(await gate.redirect('/permissions'), '/');
  });

  test('a walkthrough Angular opened stays open for an untracked rep', () async {
    when(() => policies.trackingRequired()).thenAnswer((_) async => false);
    expect(await gate.redirect('/permissions'), isNull);
  });

  test('walkthrough, diagnostics and the request inspector are never blocked', () async {
    when(() => permissions.status()).thenAnswer((_) async => status(background: false));
    for (final path in ['/permissions', '/diagnostics', '/requests']) {
      expect(await gate.redirect(path), isNull, reason: path);
    }
  });

  test('fails closed when permissions cannot be read', () async {
    when(() => permissions.status()).thenThrow(Exception('plugin down'));
    expect(await gate.redirect('/'), '/permissions');
  });

  test('a permission or policy change makes the router re-check', () async {
    var notified = 0;
    gate.addListener(() => notified++);
    changes.add(status(background: false));
    policyChanges.add(untracked);
    await pumpEventQueue();
    expect(notified, 2);
  });
}
