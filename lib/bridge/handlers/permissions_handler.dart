/// `PermissionsHandler`: `permissions.status`, `permissions.request` and the
/// `permissions.changed` event (§13).
///
/// Why it exists: Angular drives the permission flow UI; the shell performs
/// the actual Android requests and reports the wire states.
/// Status: used — registered in `service_locator.dart`.
library;

import '../../features/permissions/data/permission_status_model.dart';
import '../../features/permissions/data/permissions_repository.dart';
import '../bridge_error_model.dart';
import '../bridge_handler.dart';
import '../bridge_message_model.dart';

/// `permissions.status`, `permissions.request` (§13).
class PermissionsHandler extends BridgeHandler {
  PermissionsHandler(this._permissions);
  final PermissionsRepository _permissions;

  @override
  String get prefix => 'permissions';

  @override
  Future<Object?> handle(BridgeRequest request) async {
    switch (request.action) {
      case 'permissions.status':
        return (await _permissions.status()).toJson();
      case 'permissions.request':
        final requested = request.payload.stringList('permissions').map((name) {
          final permission = AppPermission.fromWire(name);
          if (permission == null) throw BridgeError.invalidArgument('Unknown permission "$name".');
          return permission;
        }).toList();
        return (await _permissions.request(requested)).toJson();
      default:
        unknownAction(request);
    }
  }

  @override
  Stream<BridgeEvent> get events =>
      _permissions.changes.map((status) => BridgeEvent('permissions.changed', status.toJson()));
}
