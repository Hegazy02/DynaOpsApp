/// `TrackingHandler`: `tracking.start | stop | status | latest |
/// refreshPolicy` and the `tracking.statusChanged` / `tracking.location`
/// events (§6.4, §8). `tracking.stop` is refused with `UNSUPPORTED` while a
/// session exists — tracking stops only on sign-out (D8).
///
/// Why it exists: Angular reads tracking state, retries after a permission
/// fix, and uses `tracking.latest` instead of the browser's
/// `getCurrentPosition` for geofence, check-in and day start.
/// Status: used — registered in `service_locator.dart`; tested in
/// `test/bridge/handlers/tracking_handler_test.dart`.
library;

import '../../features/auth/data/session_repository.dart';
import '../../features/tracking/data/location_repository.dart';
import '../../features/tracking/data/tracking_policy_repository.dart';
import '../../features/tracking/data/tracking_repository.dart';
import '../../features/tracking/engine/task_protocol.dart';
import '../../features/tracking/engine/tracking_coordinator.dart';
import '../bridge_error_model.dart';
import '../bridge_handler.dart';
import '../bridge_message_model.dart';

class TrackingHandler extends BridgeHandler {
  TrackingHandler(this._session, this._tracking, this._coordinator, this._locations, this._policies);

  final SessionRepository _session;
  final TrackingRepository _tracking;
  final TrackingCoordinator _coordinator;
  final LocationRepository _locations;
  final TrackingPolicyRepository _policies;

  @override
  String get prefix => 'tracking';

  @override
  Future<Object?> handle(BridgeRequest request) async {
    switch (request.action) {
      case 'tracking.start':
        return {'state': (await _coordinator.retry()).state.wire};
      case 'tracking.stop':
        if (_session.current != null) {
          throw BridgeError.unsupported('Tracking stops only when the rep signs out.');
        }
        return {'state': _tracking.current.state.wire};
      case 'tracking.status':
        return (await _tracking.refreshStatus()).toJson();
      case 'tracking.latest':
        final payload = request.payload;
        final fix = await _locations.latestFix(
          userId: _session.current?.userId,
          maxAge: Duration(seconds: payload.optionalNum('maxAgeSeconds', fallback: 30).round()),
          highAccuracy: payload.optionalBool('highAccuracy', fallback: true),
        );
        return fix.toJson();
      case 'tracking.refreshPolicy':
        final policy = await _policies.refresh();
        await _tracking.notify(TaskCommand.refreshPolicy);
        return policy.toJson();
      default:
        unknownAction(request);
    }
  }

  @override
  Stream<BridgeEvent> get events => mergeEvents([
        _tracking.statuses.map((status) => BridgeEvent('tracking.statusChanged', status.toJson())),
        _tracking.locations.map((fix) => BridgeEvent('tracking.location', fix.toBridgeJson())),
      ]);
}
