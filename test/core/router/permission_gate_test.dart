/// Tests for `PermissionGate`: every app route redirects to `/permissions`
/// until tracking has all it needs (incl. the Location switch on and precise
/// location); the walkthrough, diagnostics and the
/// request inspector stay open; an unreadable status fails closed; each
/// permission change notifies the router.
///
/// Status: active — part of `flutter test`.
library;

import 'dart:async';

import 'package:dynaopsapp/core/router/permission_gate.dart';
import 'package:dynaopsapp/features/permissions/data/permission_status_model.dart';
import 'package:dynaopsapp/features/permissions/data/permissions_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPermissions extends Mock implements PermissionsRepository {}

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

void main() {
  late _MockPermissions permissions;
  late StreamController<PermissionStatusModel> changes;
  late PermissionGate gate;

  setUp(() {
    permissions = _MockPermissions();
    changes = StreamController.broadcast();
    when(() => permissions.changes).thenAnswer((_) => changes.stream);
    gate = PermissionGate(permissions);
  });

  tearDown(() async {
    gate.dispose();
    await changes.close();
  });

  test('the app is blocked while anything tracking needs is missing', () async {
    when(() => permissions.status()).thenAnswer((_) async => status(background: false));
    expect(await gate.redirect('/'), '/permissions');
  });

  test('the phone\'s Location switch off or approximate location blocks the app', () async {
    when(() => permissions.status()).thenAnswer((_) async => status(locationOn: false));
    expect(await gate.redirect('/'), '/permissions');
    when(() => permissions.status()).thenAnswer((_) async => status(precise: false));
    expect(await gate.redirect('/'), '/permissions');
  });

  test('the app opens once everything is granted', () async {
    when(() => permissions.status()).thenAnswer((_) async => status());
    expect(await gate.redirect('/'), isNull);
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

  test('a permission change makes the router re-check', () async {
    var notified = 0;
    gate.addListener(() => notified++);
    changes.add(status(background: false));
    await pumpEventQueue();
    expect(notified, 1);
  });
}
