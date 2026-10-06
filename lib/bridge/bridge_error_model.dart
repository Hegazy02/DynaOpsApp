/// `BridgeErrorCode` (the wire codes of §15) and `BridgeError`, the exception
/// handlers throw; `BridgeError.fromFailure` is the one mapping from a
/// repository `Failure` to a bridge code and its `retryable` flag.
///
/// Why it exists: Angular reacts to stable codes, not to Dart exception text;
/// centralising the mapping keeps every handler consistent.
/// Status: used — by the controller, every handler and the shell; covered by
/// `test/bridge/bridge_error_model_test.dart`.
library;

import 'package:equatable/equatable.dart';

import '../core/network/failure.dart';

/// Bridge error codes (§15). The wire name is the enum name in SCREAMING_CASE.
enum BridgeErrorCode {
  permissionDenied('PERMISSION_DENIED'),
  permissionRequired('PERMISSION_REQUIRED'),
  locationDisabled('LOCATION_DISABLED'),
  locationUnavailable('LOCATION_UNAVAILABLE'),
  networkError('NETWORK_ERROR'),
  unauthorized('UNAUTHORIZED'),
  databaseError('DATABASE_ERROR'),
  syncError('SYNC_ERROR'),
  invalidArgument('INVALID_ARGUMENT'),
  notFound('NOT_FOUND'),
  unsupported('UNSUPPORTED'),
  nativeError('NATIVE_ERROR');

  const BridgeErrorCode(this.wire);
  final String wire;
}

class BridgeError extends Equatable implements Exception {
  const BridgeError(this.code, this.message, {this.retryable = false});

  factory BridgeError.invalidArgument(String message) =>
      BridgeError(BridgeErrorCode.invalidArgument, message);

  factory BridgeError.unsupported(String message) =>
      BridgeError(BridgeErrorCode.unsupported, message);

  /// The one place a [Failure] becomes a bridge error (§15).
  factory BridgeError.fromFailure(Failure failure) {
    final (code, retryable) = switch (failure) {
      NetworkFailure() || TimeoutFailure() => (BridgeErrorCode.networkError, true),
      UnauthorizedFailure() => (BridgeErrorCode.unauthorized, false),
      ForbiddenFailure() => (BridgeErrorCode.permissionDenied, false),
      ValidationFailure() => (BridgeErrorCode.invalidArgument, false),
      ServerFailure() => (BridgeErrorCode.networkError, true),
      DatabaseFailure() => (BridgeErrorCode.databaseError, false),
      PermissionFailure() => (BridgeErrorCode.permissionRequired, false),
      LocationFailure(:final disabled) => disabled
          ? (BridgeErrorCode.locationDisabled, true)
          : (BridgeErrorCode.locationUnavailable, true),
      InvalidInputFailure() => (BridgeErrorCode.invalidArgument, false),
      UnsupportedFailure() => (BridgeErrorCode.unsupported, false),
      PlatformFailure() => (BridgeErrorCode.nativeError, false),
    };
    return BridgeError(code, failure.message, retryable: retryable);
  }

  final BridgeErrorCode code;
  final String message;
  final bool retryable;

  Map<String, dynamic> toJson() => {'code': code.wire, 'message': message, 'retryable': retryable};

  @override
  List<Object?> get props => [code, message, retryable];
}
