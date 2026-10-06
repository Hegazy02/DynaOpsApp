/// Tests for `SessionModel`: bridge payload parsing and defaults, rejection
/// of bad shapes, storage round-trip (including a dropped token), token-free
/// public JSON and `hasValidToken`.
///
/// Status: active — part of `flutter test`.
library;

import 'package:dynaopsapp/features/auth/data/session_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final payload = {
    'token': 'jwt',
    'userId': 'u1',
    'expireAt': '2030-01-01T00:00:00Z',
    'isSuperAdmin': true,
    'lang': 'ar',
  };

  test('fromJson parses the bridge payload', () {
    final session = SessionModel.fromJson(payload);
    expect(session.token, 'jwt');
    expect(session.userId, 'u1');
    expect(session.expireAt, DateTime.utc(2030));
    expect(session.isSuperAdmin, true);
    expect(session.lang, 'ar');
  });

  test('fromJson defaults isSuperAdmin and lang', () {
    final session = SessionModel.fromJson({'token': 't', 'userId': 'u', 'expireAt': '2030-01-01T00:00:00Z'});
    expect(session.isSuperAdmin, false);
    expect(session.lang, 'en');
  });

  test('fromJson rejects bad shapes', () {
    for (final bad in [
      <String, dynamic>{},
      {...payload, 'token': ''},
      {...payload, 'userId': 42},
      {...payload, 'expireAt': 'yesterday'},
    ]) {
      expect(() => SessionModel.fromJson(bad), throwsFormatException, reason: '$bad');
    }
  });

  test('storage round-trip keeps everything, including a dropped token', () {
    final session = SessionModel.fromJson(payload);
    expect(SessionModel.fromStorageJson(session.toStorageJson()), session);
    final expired = session.withoutToken();
    expect(SessionModel.fromStorageJson(expired.toStorageJson()), expired);
  });

  test('public JSON never contains the token', () {
    expect(SessionModel.fromJson(payload).toPublicJson(), {'userId': 'u1', 'expireAt': '2030-01-01T00:00:00.000Z'});
  });

  test('hasValidToken checks presence and expiry', () {
    final session = SessionModel.fromJson(payload);
    expect(session.hasValidToken(DateTime.utc(2029)), true);
    expect(session.hasValidToken(DateTime.utc(2031)), false);
    expect(session.withoutToken().hasValidToken(DateTime.utc(2029)), false);
  });
}
