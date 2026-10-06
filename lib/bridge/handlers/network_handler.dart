/// `NetworkHandler`: `network.status` on request and the `network.changed`
/// event whenever connectivity really changes (§12).
///
/// Why it exists: the browser's `navigator.onLine` is unreliable in a
/// WebView; the shell's probe-backed status is what Angular trusts.
/// Status: used — registered in `service_locator.dart`.
library;

import '../../features/connectivity/data/connectivity_repository.dart';
import '../bridge_handler.dart';
import '../bridge_message_model.dart';

/// `network.status` + `network.changed` (§12).
class NetworkHandler extends BridgeHandler {
  NetworkHandler(this._connectivity);
  final ConnectivityRepository _connectivity;

  @override
  String get prefix => 'network';

  @override
  Future<Object?> handle(BridgeRequest request) async {
    switch (request.action) {
      case 'network.status':
        return (await _connectivity.refresh()).toJson();
      default:
        unknownAction(request);
    }
  }

  @override
  Stream<BridgeEvent> get events =>
      _connectivity.changes.map((status) => BridgeEvent('network.changed', status.toJson()));
}
