/// Tests that every `Failure` maps to the §15 bridge code and `retryable`
/// flag, and that server validation text passes through unchanged.
///
/// Status: active — part of `flutter test`.
library;

import 'package:dynaopsapp/bridge/bridge_error_model.dart';
import 'package:dynaopsapp/core/network/failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every Failure maps to the §15 code', () {
    final cases = <Failure, (String, bool)>{
      const NetworkFailure(): ('NETWORK_ERROR', true),
      const TimeoutFailure(): ('NETWORK_ERROR', true),
      const UnauthorizedFailure(): ('UNAUTHORIZED', false),
      const ForbiddenFailure(): ('PERMISSION_DENIED', false),
      const ValidationFailure('server says no'): ('INVALID_ARGUMENT', false),
      const ServerFailure('500'): ('NETWORK_ERROR', true),
      const DatabaseFailure('db'): ('DATABASE_ERROR', false),
      const PermissionFailure('p'): ('PERMISSION_REQUIRED', false),
      const LocationFailure('off', disabled: true): ('LOCATION_DISABLED', true),
      const LocationFailure('no fix'): ('LOCATION_UNAVAILABLE', true),
      const InvalidInputFailure('bad'): ('INVALID_ARGUMENT', false),
      const UnsupportedFailure('no'): ('UNSUPPORTED', false),
      const PlatformFailure('crash'): ('NATIVE_ERROR', false),
    };
    cases.forEach((failure, expected) {
      final error = BridgeError.fromFailure(failure);
      expect((error.code.wire, error.retryable), expected, reason: '$failure');
    });
  });

  test('server validation message passes through verbatim', () {
    final error = BridgeError.fromFailure(const ValidationFailure('الموقع خارج النطاق'));
    expect(error.toJson()['message'], 'الموقع خارج النطاق');
  });
}
