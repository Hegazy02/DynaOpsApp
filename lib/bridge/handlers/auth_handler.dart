/// `AuthHandler`: `auth.setSession`, `auth.getSession`, `auth.signOut` (§7)
/// and the `auth.sessionChanged` / `auth.sessionExpired` / `auth.signedOut`
/// events. Never returns the token to JavaScript.
///
/// Why it exists: Angular owns login; this is how it hands the session to the
/// shell so tracking and uploads can authenticate natively (D6). Setting and
/// ending a session go through `TrackingCoordinator`, which runs the user-swap
/// and sign-out flush rules before the session changes.
/// Status: used — registered in `service_locator.dart`; tested in
/// `test/bridge/handlers/auth_handler_test.dart`.
library;

import '../../features/auth/data/session_change_model.dart';
import '../../features/auth/data/session_model.dart';
import '../../features/auth/data/session_repository.dart';
import '../../features/tracking/engine/tracking_coordinator.dart';
import '../bridge_error_model.dart';
import '../bridge_handler.dart';
import '../bridge_message_model.dart';

/// `auth.setSession`, `auth.getSession`, `auth.signOut` (§7). Never returns the token.
class AuthHandler extends BridgeHandler {
  AuthHandler(this._session, this._tracking);
  final SessionRepository _session;
  final TrackingCoordinator _tracking;

  @override
  String get prefix => 'auth';

  @override
  Future<Object?> handle(BridgeRequest request) async {
    switch (request.action) {
      case 'auth.setSession':
        final SessionModel session;
        try {
          session = SessionModel.fromJson(request.payload);
        } on FormatException catch (e) {
          throw BridgeError.invalidArgument(e.message);
        }
        await _tracking.setSession(session);
        return const {'accepted': true};
      case 'auth.getSession':
        return _session.current?.toPublicJson();
      case 'auth.signOut':
        // Only a deliberate sign-out ends the native session; 401/expiry never
        // reach here (§7).
        if (!request.payload.optionalBool('deliberate')) return const {'flushed': 0};
        return {'flushed': await _tracking.signOut()};
      default:
        unknownAction(request);
    }
  }

  @override
  Stream<BridgeEvent> get events => _session.changes.map(
        (change) => switch (change) {
          SessionAdopted(:final session) => BridgeEvent('auth.sessionChanged', session.toPublicJson()),
          SessionExpired(:final expireAt) =>
            BridgeEvent('auth.sessionExpired', {'expireAt': expireAt.toUtc().toIso8601String()}),
          SessionSignedOut() => const BridgeEvent('auth.signedOut'),
        },
      );
}
