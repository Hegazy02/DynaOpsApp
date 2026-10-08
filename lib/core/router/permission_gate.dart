/// `PermissionGate`: the router's guard that keeps the app unusable for a rep
/// whose tracking is on until every permission tracking needs is granted
/// (`trackingReady`: precise location "all the time", the phone's Location
/// switch, notifications, battery-optimisation exemption). A rep whose
/// tracking is off (`TrackingPolicyModel.enabled` false) is never blocked,
/// nor is anyone before `RepDashboard` has answered once.
/// Any other route redirects to `/permissions`; the walkthrough, diagnostics
/// and the request inspector stay reachable. It notifies the router on every
/// permission or policy change, so revoking one in Settings sends the rep
/// straight back to the walkthrough on return, and a rep the gate sent there
/// is let out once their tracking turns out to be off.
///
/// Why it exists: tracking is a condition of using the app for tracked reps
/// (product decision, 2026-10-07); a router `redirect` enforces it in one
/// place instead of on every screen.
/// Status: used — `redirect` and `refreshListenable` of `createAppRouter`;
/// tested in `test/core/router/permission_gate_test.dart`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/permissions/data/permissions_repository.dart';
import '../../features/tracking/data/tracking_policy_repository.dart';

class PermissionGate extends ChangeNotifier {
  PermissionGate(this._permissions, this._policies) {
    _subscriptions = [
      _permissions.changes.listen((_) => notifyListeners()),
      _policies.changes.listen((_) => notifyListeners()),
    ];
  }

  static const walkthroughPath = '/permissions';

  /// Reachable without the permissions: the walkthrough itself and support tools.
  static const openPaths = {walkthroughPath, '/diagnostics', '/requests'};

  final PermissionsRepository _permissions;
  final TrackingPolicyRepository _policies;
  late final List<StreamSubscription<Object?>> _subscriptions;

  /// The last redirect sent the rep to the walkthrough (as opposed to Angular
  /// opening it with `app.openNativeScreen`).
  bool _sentToWalkthrough = false;

  /// `/permissions` while the rep is tracked and anything tracking needs is
  /// missing; `/` to leave a walkthrough the gate forced on an untracked rep;
  /// else null.
  Future<String?> redirect(String path) async {
    if (path == walkthroughPath) {
      if (!_sentToWalkthrough || await _trackingRequired()) return null;
      _sentToWalkthrough = false;
      return '/';
    }
    if (openPaths.contains(path)) return null;
    _sentToWalkthrough = await _trackingRequired() && !await _ready();
    return _sentToWalkthrough ? walkthroughPath : null;
  }

  /// From the stored policy (offline-safe); false until `RepDashboard` answers.
  Future<bool> _trackingRequired() => _policies.trackingRequired();

  Future<bool> _ready() async {
    try {
      return (await _permissions.status()).trackingReady;
    } catch (_) {
      // Cannot read permissions: fail closed, the walkthrough re-checks.
      return false;
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
