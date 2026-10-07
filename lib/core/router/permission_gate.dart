/// `PermissionGate`: the router's guard that keeps the app unusable until
/// every permission tracking needs is granted (`trackingReady`: precise
/// location "all the time", notifications, battery-optimisation exemption).
/// Any other route redirects to `/permissions`; the walkthrough, diagnostics
/// and the request inspector stay reachable. It notifies the router on every
/// permission change, so revoking one in Settings sends the rep straight back
/// to the walkthrough on return.
///
/// Why it exists: tracking is a condition of using the app (product decision,
/// 2026-10-07); a router `redirect` enforces it in one place instead of on
/// every screen.
/// Status: used — `redirect` and `refreshListenable` of `createAppRouter`;
/// tested in `test/core/router/permission_gate_test.dart`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/permissions/data/permission_status_model.dart';
import '../../features/permissions/data/permissions_repository.dart';

class PermissionGate extends ChangeNotifier {
  PermissionGate(this._permissions) {
    _subscription = _permissions.changes.listen((_) => notifyListeners());
  }

  static const walkthroughPath = '/permissions';

  /// Reachable without the permissions: the walkthrough itself and support tools.
  static const openPaths = {walkthroughPath, '/diagnostics', '/requests'};

  final PermissionsRepository _permissions;
  late final StreamSubscription<PermissionStatusModel> _subscription;

  /// `/permissions` while anything tracking needs is missing, else null.
  Future<String?> redirect(String path) async {
    if (openPaths.contains(path)) return null;
    try {
      return (await _permissions.status()).trackingReady ? null : walkthroughPath;
    } catch (_) {
      // Cannot read permissions: fail closed, the walkthrough re-checks.
      return walkthroughPath;
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
