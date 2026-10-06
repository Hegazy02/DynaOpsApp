/// Tests for `SessionRepository` with mocked `SecureStore` and
/// `AnalyticsClient` and a fixed clock: adopt (store, identify, publish),
/// idempotent re-adopt, user swap, refusal of an expired session,
/// markExpired keeping `userId`, signOut, and load restoring or dropping a
/// stored session.
///
/// Status: active — part of `flutter test`.
library;

import 'dart:convert';

import 'package:dynaopsapp/core/analytics/analytics_client.dart';
import 'package:dynaopsapp/core/logging/app_logger.dart';
import 'package:dynaopsapp/core/network/failure.dart';
import 'package:dynaopsapp/core/storage/secure_store.dart';
import 'package:dynaopsapp/features/auth/data/session_change_model.dart';
import 'package:dynaopsapp/features/auth/data/session_model.dart';
import 'package:dynaopsapp/features/auth/data/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStore extends Mock implements SecureStore {}

class _MockAnalytics extends Mock implements AnalyticsClient {}

void main() {
  final now = DateTime.utc(2026, 10, 5);
  late _MockSecureStore store;
  late _MockAnalytics analytics;
  late SessionRepository repository;

  SessionModel session(String userId, {String token = 'jwt'}) =>
      SessionModel(token: token, userId: userId, expireAt: now.add(const Duration(days: 1)));

  setUp(() {
    store = _MockSecureStore();
    analytics = _MockAnalytics();
    when(() => store.read(any())).thenAnswer((_) async => null);
    when(() => store.write(any(), any())).thenAnswer((_) async {});
    when(() => store.delete(any())).thenAnswer((_) async {});
    when(() => analytics.identify(any())).thenAnswer((_) async {});
    when(() => analytics.reset()).thenAnswer((_) async {});
    repository = SessionRepository(store, analytics, AppLogger(), clock: () => now);
  });

  tearDown(() => repository.dispose());

  test('adopt stores, identifies and publishes', () async {
    final changes = <SessionChange>[];
    repository.changes.listen(changes.add);

    await repository.adopt(session('a'));
    await Future<void>.delayed(Duration.zero);

    expect(repository.validToken, 'jwt');
    verify(() => store.write('session', any())).called(1);
    verify(() => analytics.identify('a')).called(1);
    expect(changes, [SessionAdopted(session('a'), userSwapped: false)]);
  });

  test('adopting the same session twice is a no-op', () async {
    await repository.adopt(session('a'));
    await repository.adopt(session('a'));
    verify(() => store.write('session', any())).called(1);
  });

  test('a different user is reported as a swap', () async {
    await repository.adopt(session('a'));
    final change = await repository.adopt(session('b'));
    expect(change.userSwapped, true);
    expect(repository.current!.userId, 'b');
  });

  test('an expired session is refused', () async {
    final expired = SessionModel(token: 't', userId: 'a', expireAt: now.subtract(const Duration(minutes: 1)));
    expect(() => repository.adopt(expired), throwsA(isA<InvalidInputFailure>()));
  });

  test('markExpired drops the token but keeps the user', () async {
    final changes = <SessionChange>[];
    repository.changes.listen(changes.add);
    await repository.adopt(session('a'));

    await repository.markExpired();
    await Future<void>.delayed(Duration.zero);

    expect(repository.validToken, isNull);
    expect(repository.current!.userId, 'a');
    expect(changes.last, isA<SessionExpired>());
  });

  test('signOut clears storage, resets analytics and publishes', () async {
    final changes = <SessionChange>[];
    repository.changes.listen(changes.add);
    await repository.adopt(session('a'));

    await repository.signOut();
    await Future<void>.delayed(Duration.zero);

    expect(repository.current, isNull);
    verify(() => store.delete('session')).called(1);
    verify(() => analytics.reset()).called(1);
    expect(changes.last, const SessionSignedOut());
  });

  test('load restores a stored session and drops a corrupt one', () async {
    when(() => store.read('session')).thenAnswer((_) async => jsonEncode(session('a').toStorageJson()));
    await repository.load();
    expect(repository.current!.userId, 'a');

    final other = SessionRepository(store, analytics, AppLogger(), clock: () => now);
    when(() => store.read('session')).thenAnswer((_) async => '{"nope":1}');
    await other.load();
    expect(other.current, isNull);
    verify(() => store.delete('session')).called(1);
    await other.dispose();
  });
}
