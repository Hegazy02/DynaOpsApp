/// Tests for `AuthHandler` with mocked `SessionRepository` and
/// `TrackingCoordinator`: setSession goes through the coordinator (user swap /
/// auto-start) and `INVALID_ARGUMENT` on a bad payload, getSession never
/// returning the token, signOut (flush count) only when deliberate, and
/// `SessionChange` → `auth.*` event mapping.
///
/// Status: active — part of `flutter test`.
library;

import 'dart:async';

import 'package:dynaopsapp/bridge/bridge_error_model.dart';
import 'package:dynaopsapp/bridge/bridge_message_model.dart';
import 'package:dynaopsapp/bridge/handlers/auth_handler.dart';
import 'package:dynaopsapp/features/auth/data/session_change_model.dart';
import 'package:dynaopsapp/features/auth/data/session_model.dart';
import 'package:dynaopsapp/features/auth/data/session_repository.dart';
import 'package:dynaopsapp/features/tracking/engine/tracking_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockCoordinator extends Mock implements TrackingCoordinator {}

BridgeRequest _request(String action, [Map<String, dynamic> payload = const {}]) =>
    BridgeRequest(version: '1.0', id: '1', action: action, payload: payload);

void main() {
  final session = SessionModel(token: 'jwt', userId: 'u1', expireAt: DateTime.utc(2030));
  late _MockSessionRepository repository;
  late _MockCoordinator coordinator;
  late StreamController<SessionChange> changes;
  late AuthHandler handler;

  setUpAll(() => registerFallbackValue(session));

  setUp(() {
    repository = _MockSessionRepository();
    coordinator = _MockCoordinator();
    changes = StreamController<SessionChange>.broadcast();
    when(() => repository.changes).thenAnswer((_) => changes.stream);
    handler = AuthHandler(repository, coordinator);
  });

  tearDown(() => changes.close());

  test('setSession hands a valid payload to the coordinator', () async {
    when(() => coordinator.setSession(any())).thenAnswer((_) async {});
    final data = await handler.handle(_request('auth.setSession', {
      'token': 'jwt',
      'userId': 'u1',
      'expireAt': '2030-01-01T00:00:00Z',
    }));
    expect(data, {'accepted': true});
    verify(() => coordinator.setSession(session)).called(1);
  });

  test('setSession with a bad payload → INVALID_ARGUMENT', () {
    expect(
      () => handler.handle(_request('auth.setSession', {'userId': 'u1'})),
      throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.invalidArgument)),
    );
  });

  test('getSession never returns the token', () async {
    when(() => repository.current).thenReturn(session);
    final data = await handler.handle(_request('auth.getSession'));
    expect(data, {'userId': 'u1', 'expireAt': '2030-01-01T00:00:00.000Z'});
  });

  test('signOut flushes and clears only when deliberate', () async {
    when(() => coordinator.signOut()).thenAnswer((_) async => 42);
    await handler.handle(_request('auth.signOut', {'deliberate': false}));
    verifyNever(() => coordinator.signOut());
    expect(await handler.handle(_request('auth.signOut', {'deliberate': true})), {'flushed': 42});
    verify(() => coordinator.signOut()).called(1);
  });

  test('session changes become auth.* events', () async {
    final events = <BridgeEvent>[];
    handler.events.listen(events.add);
    changes
      ..add(SessionAdopted(session, userSwapped: false))
      ..add(SessionExpired(DateTime.utc(2030)))
      ..add(const SessionSignedOut());
    await Future<void>.delayed(Duration.zero);
    expect(events.map((e) => e.event), ['auth.sessionChanged', 'auth.sessionExpired', 'auth.signedOut']);
    expect(events.first.data, {'userId': 'u1', 'expireAt': '2030-01-01T00:00:00.000Z'});
  });
}
