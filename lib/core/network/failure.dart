/// The sealed `Failure` hierarchy every repository throws (network, timeout,
/// auth, validation, server, database, permission, location, input,
/// unsupported, platform) and `mapDioError`, which turns a `DioException`
/// into one of them.
///
/// Why it exists: Cubits and the bridge switch exhaustively on failure *types*
/// instead of parsing messages; §15 maps each type to a bridge error code.
/// Status: used — thrown by every repository and mapped in
/// `bridge_error_model.dart`. `LocationFailure` has no thrower yet (M2
/// tracking).
library;

import 'package:dio/dio.dart';

/// Every repository throws only these (flutter-dio-repository-setup, extended per §15).
///
/// [message] is for logs and for passing server messages through the bridge;
/// native screens map the failure *type* to an `AppLocalizations` key.
sealed class Failure implements Exception {
  const Failure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'The request timed out.']);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Your session has expired.']);
}

final class ForbiddenFailure extends Failure {
  const ForbiddenFailure([super.message = 'Not allowed.']);
}

/// 4xx other than 401/403; [message] is the server's (already localised) text.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

final class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

final class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

final class LocationFailure extends Failure {
  const LocationFailure(super.message, {this.disabled = false});
  final bool disabled;
}

/// Bad input from a caller (e.g. a malformed bridge payload).
final class InvalidInputFailure extends Failure {
  const InvalidInputFailure(super.message);
}

/// The device cannot do this (no app to open a file, unsupported setting, …).
final class UnsupportedFailure extends Failure {
  const UnsupportedFailure(super.message);
}

/// A plugin/platform call failed unexpectedly.
final class PlatformFailure extends Failure {
  const PlatformFailure(super.message);
}

Failure mapDioError(DioException e) {
  final status = e.response?.statusCode;
  return switch (e.type) {
    DioExceptionType.connectionError => const NetworkFailure(),
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const TimeoutFailure(),
    DioExceptionType.badResponse when status == 401 => const UnauthorizedFailure(),
    DioExceptionType.badResponse when status == 403 => const ForbiddenFailure(),
    DioExceptionType.badResponse when status != null && status >= 400 && status < 500 =>
      ValidationFailure(_serverMessage(e) ?? 'Request rejected ($status).'),
    DioExceptionType.badResponse => ServerFailure(_serverMessage(e) ?? 'Server error ($status).'),
    _ => ServerFailure(e.message ?? 'Unexpected error.'),
  };
}

String? _serverMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final message = data['message'] ?? data['Message'];
    if (message is String && message.isNotEmpty) return message;
  }
  return null;
}
