/// `TrackingCoordinator` (UI isolate): applies the session rules of §7 to
/// tracking. On launch it reports a previous Force Stop and auto-starts when a
/// session exists (D8). `setSession` handles the user swap (stop and flush A
/// with A's token, forget A's policy) before adopting and starting for B.
/// `signOut` stops collection, flushes (bounded) and only then clears the
/// session. Re-checks when permissions or the session change, and on resume.
/// Never starts the service for a rep whose tracking is off, or before
/// `RepDashboard` has answered once (`disabledByAdmin`); retries when the
/// device comes back online.
///
/// Why it exists: an engine, not a Cubit — these rules must run whatever
/// screen is open (or none), and they span the session, tracking, sync and
/// policy repositories; the auth bridge handler stays a thin adapter.
/// Status: used — registered in `service_locator.dart`, started from
/// `main.dart`, called by `AuthHandler`, `TrackingHandler` and `ShellCubit`.
library;

import 'dart:async';

import '../../../core/analytics/analytics_client.dart';
import '../../auth/data/session_change_model.dart';
import '../../auth/data/session_model.dart';
import '../../auth/data/session_repository.dart';
import '../../connectivity/data/connectivity_repository.dart';
import '../../permissions/data/permission_status_model.dart';
import '../../permissions/data/permissions_repository.dart';
import '../../sync/data/sync_repository.dart';
import '../data/tracking_policy_repository.dart';
import '../data/tracking_repository.dart';
import '../data/tracking_status_model.dart';
import 'task_protocol.dart';

class TrackingCoordinator {
  TrackingCoordinator(
    this._session,
    this._tracking,
    this._sync,
    this._policies,
    this._permissions,
    this._analytics,
    this._connectivity,
  );

  static const flushTimeout = Duration(seconds: 20);

  final SessionRepository _session;
  final TrackingRepository _tracking;
  final SyncRepository _sync;
  final TrackingPolicyRepository _policies;
  final PermissionsRepository _permissions;
  final AnalyticsClient _analytics;
  final ConnectivityRepository _connectivity;
  final _subscriptions = <StreamSubscription<Object?>>[];

  Future<void> start() async {
    _subscriptions
      ..add(_permissions.changes.listen(_onPermissions))
      ..add(_session.changes.listen((change) {
        if (change is SessionExpired) unawaited(_tracking.notify(TaskCommand.sessionChanged));
      }))
      ..add(_connectivity.changes.listen((network) {
        // Not tracked for want of a RepDashboard answer (or tracking off): ask again.
        final notTracked = !_tracking.current.backgroundService &&
            _tracking.current.reason == TrackingReason.disabledByAdmin;
        if (network.online && notTracked && _session.current != null) unawaited(_start());
      }));
    if (await _tracking.init()) unawaited(_analytics.capture('force_stop_detected'));
    if (_session.current != null) await _start();
  }

  /// `auth.setSession`.
  Future<void> setSession(SessionModel session) async {
    final previous = _session.current;
    if (previous != null && previous.userId != session.userId) {
      // User swap (§7.1): A's queue is uploaded with A's token, never B's.
      await _flush();
      await _policies.clear();
    }
    await _session.adopt(session);
    await _start();
  }

  /// `auth.signOut{deliberate:true}`: returns how many fixes were uploaded.
  Future<int> signOut() async {
    final flushed = await _flush();
    await _session.signOut();
    unawaited(_analytics.capture('tracking_stopped', {'reason': 'signedOut'}));
    return flushed;
  }

  /// `tracking.start` and the permission walkthrough's "done".
  Future<TrackingStatusModel> retry() => _start();

  Future<void> onAppResumed() async {
    if (_session.current == null) return;
    if (_tracking.current.backgroundService) {
      await _tracking.notify(TaskCommand.refreshPolicy);
      await _tracking.refreshStatus();
    } else {
      await _start();
    }
  }

  /// Starts the service only for a rep whose tracking is on (Always, Routes or
  /// Working hours); an "off" rep never gets the service or a GPS stream.
  Future<TrackingStatusModel> _start() async {
    if (_session.current != null) {
      final policy = await _policies.refreshIfStale(force: true);
      if (!policy.enabled) {
        if (_tracking.current.backgroundService) {
          // A running service shuts itself down once it reads the new policy.
          await _tracking.notify(TaskCommand.refreshPolicy);
          return _tracking.current;
        }
        return _tracking.markDisabled();
      }
    }
    final status = await _tracking.ensureRunning();
    if (status.backgroundService) unawaited(_analytics.capture('tracking_started'));
    if (status.state == TrackingState.permissionRequired || status.state == TrackingState.permissionDenied) {
      unawaited(_analytics.capture('permission_denied', {'permission': 'location'}));
    }
    return status;
  }

  Future<int> _flush() async {
    if (_tracking.current.backgroundService) {
      return _tracking.stopAndFlush(timeout: flushTimeout);
    }
    return _sync.flushLocal(timeout: flushTimeout);
  }

  void _onPermissions(PermissionStatusModel status) {
    if (_session.current == null) return;
    final blocked = _tracking.current.state == TrackingState.permissionRequired ||
        _tracking.current.state == TrackingState.permissionDenied;
    if (blocked && status.location == PermissionState.granted) {
      unawaited(_start()); // Auto-resume once re-granted (§13).
    } else {
      unawaited(_tracking.notify(TaskCommand.permissionsChanged));
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}
