/// `SyncHandler`: `sync.status`, `sync.now`, `sync.retryFailed` and the
/// `sync.started | progress | completed | failed` events (§6.4, §11).
///
/// Why it exists: Angular shows how many points are waiting and can retry
/// dead-lettered uploads; the queue itself lives natively.
/// Status: used — registered in `service_locator.dart`.
library;

import '../../features/sync/data/sync_repository.dart';
import '../bridge_handler.dart';
import '../bridge_message_model.dart';

class SyncHandler extends BridgeHandler {
  SyncHandler(this._sync);
  final SyncRepository _sync;

  @override
  String get prefix => 'sync';

  @override
  Future<Object?> handle(BridgeRequest request) async {
    switch (request.action) {
      case 'sync.status':
        return (await _sync.status()).toJson();
      case 'sync.now':
        return {'started': await _sync.syncNow()};
      case 'sync.retryFailed':
        return {'requeued': await _sync.retryFailed()};
      default:
        unknownAction(request);
    }
  }

  @override
  Stream<BridgeEvent> get events => _sync.events.map((e) => BridgeEvent(e.name, e.data));
}
