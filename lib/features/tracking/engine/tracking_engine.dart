/// `TrackingEngine`: the state machine inside the tracking service (§8.2).
/// Applies the auto-start rule (D8) to the stored session + policy, checks
/// location permission and provider state, runs the 1 s GPS sample stream
/// through `FixFilter` and `PingSampler`, stores each ping first, publishes
/// status/pings, triggers sync, and on every heartbeat tick (30 s) records the
/// heartbeat ping — by default the only ping — and runs the watchdog, upload,
/// policy refresh and shift edges. Stops its own service after sign-out or
/// when an admin disables tracking. Uploaded rows are deleted by `SyncManager`.
///
/// Why it exists: collection must keep running with no UI (locked phone,
/// swiped from Recents, after reboot); this holds all of that logic behind a
/// `TrackingPort` so it is testable without Android.
/// Status: used — created by `TrackingTaskHandler` in the service isolate;
/// tested in `test/features/tracking/engine/tracking_engine_test.dart`.
library;

import 'dart:async';

import '../../../core/config/app_config.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/failure.dart';
import '../../auth/data/session_repository.dart';
import '../../connectivity/data/connectivity_repository.dart';
import '../../permissions/data/permission_status_model.dart';
import '../../permissions/data/permissions_repository.dart';
import '../../sync/data/sync_meta_dao.dart';
import '../../sync/engine/sync_manager.dart';
import '../data/location_points_dao.dart';
import '../data/location_repository.dart';
import '../data/location_source.dart';
import '../data/position_model.dart';
import '../data/tracking_policy_model.dart';
import '../data/tracking_policy_repository.dart';
import '../data/tracking_status_model.dart';
import 'fix_filter.dart';
import 'foreground_task_port.dart';
import 'ping_sampler.dart';
import 'task_protocol.dart';
import 'tracking_policy.dart';

class TrackingEngine {
  TrackingEngine({
    required this._config,
    required this._session,
    required this._policies,
    required this._source,
    required this._locations,
    required this._points,
    required this._sync,
    required this._meta,
    required this._connectivity,
    required this._permissions,
    required this._port,
    required this._logger,
    FixFilter? filter,
    DateTime Function()? clock,
  })  : _filter = filter ?? FixFilter(),
        _now = clock ?? DateTime.now;

  /// No fix for this long while collecting → restart the stream once, then error.
  static const watchdogAfter = Duration(minutes: 5);

  final AppConfig _config;
  final SessionRepository _session;
  final TrackingPolicyRepository _policies;
  final LocationSource _source;
  final LocationRepository _locations;
  final LocationPointsDao _points;
  final SyncManager _sync;
  final SyncMetaDao _meta;
  final ConnectivityRepository _connectivity;
  final PermissionsRepository _permissions;
  final TrackingPort _port;
  final AppLogger _logger;
  final FixFilter _filter;
  final DateTime Function() _now;
  late final PingSampler _sampler = PingSampler(
    minDistanceMeters: _config.distanceFilterMeters.toDouble(),
    heartbeat: _config.heartbeatInterval,
  );

  TrackingPolicyModel _policy = TrackingPolicyModel.unknown;
  TrackingStatusModel _status = const TrackingStatusModel(state: TrackingState.starting, backgroundService: true);
  StreamSubscription<PositionModel>? _positions;
  StreamSubscription<bool>? _providerChanges;
  StreamSubscription<Object?>? _networkChanges;
  String? _collectingFor;
  DateTime? _collectingSince;
  DateTime? _lastFixAt;
  bool _watchdogRestarted = false;
  bool _stopping = false;

  /// The first status is always published, even if it equals the initial one.
  bool _announced = false;

  TrackingStatusModel get status => _status;

  Future<void> start() async {
    await _meta.set(SyncMetaKeys.serviceRunning, '1');
    await _session.load();
    await _sync.recover();
    _sync.onEvent = _port.publishSync;
    _policy = await _policies.refreshIfStale();
    _providerChanges = _source.serviceEnabledChanges().listen((_) => unawaited(evaluate()));
    _networkChanges = _connectivity.changes.listen((network) {
      if (network.online) _triggerSync();
    });
    unawaited(_connectivity.start());
    await evaluate();
    _triggerSync();
  }

  /// Re-applies the rule and brings the stream and status in line with it.
  Future<void> evaluate() async {
    if (_stopping) return;
    final session = _session.current;
    final decision = TrackingPolicy.decide(userId: session?.userId, policy: _policy, now: _now());
    if (!decision.collect) {
      await _stopPositions();
      await _setStatus(state: TrackingState.stopped, reason: decision.reason);
      if (decision.reason == TrackingReason.signedOut || decision.reason == TrackingReason.disabledByAdmin) {
        // Nothing to do until the next sign-in / app open re-checks (§8.1).
        await _shutdown();
      }
      return;
    }

    final access = await _source.access();
    if (access != LocationAccess.granted) {
      await _stopPositions();
      await _setStatus(
        state: access == LocationAccess.permanentlyDenied ? TrackingState.permissionDenied : TrackingState.permissionRequired,
      );
      return;
    }
    if (!await _source.isServiceEnabled()) {
      await _stopPositions();
      await _setStatus(state: TrackingState.error, errorCode: TrackingErrorCode.locationDisabled);
      return;
    }

    if (_positions == null || _collectingFor != session!.userId) _startPositions(session!.userId);
    final hasRecentFix = _lastFixAt != null && _now().difference(_lastFixAt!) < watchdogAfter;
    await _setStatus(
      state: hasRecentFix ? TrackingState.running : TrackingState.starting,
      reason: _session.validToken == null ? TrackingReason.sessionExpired : null,
      errorCode: _status.errorCode == TrackingErrorCode.locationUnavailable ? _status.errorCode : null,
    );
  }

  /// Heartbeat tick (`HEARTBEAT_SECONDS`): watchdog, heartbeat ping, policy,
  /// shift edges, status numbers, sync.
  Future<void> tick() async {
    if (_stopping) return;
    final now = _now();
    if (_positions != null) {
      final since = _lastFixAt ?? _collectingSince ?? now;
      if (now.difference(since) >= watchdogAfter) {
        if (!_watchdogRestarted) {
          _logger.warn('No fix for ${watchdogAfter.inMinutes} min; restarting the stream');
          _watchdogRestarted = true;
          _startPositions(_collectingFor!);
        } else {
          await _setStatus(state: TrackingState.error, errorCode: TrackingErrorCode.locationUnavailable);
          return;
        }
      }
      final userId = _collectingFor;
      final heartbeat = _sampler.onHeartbeat(now);
      if (userId != null && heartbeat != null) await _record(heartbeat, userId);
    }
    if (await _policies.isStale()) _policy = await _policies.refreshIfStale();
    await evaluate();
    await _publishNumbers();
    _triggerSync();
  }

  /// A command from the UI isolate (`TaskCommand`).
  Future<void> handleCommand(Object data) async {
    if (data is! Map) return;
    switch (data[TaskCommand.key]) {
      case TaskCommand.sessionChanged:
        final previousUser = _session.current?.userId;
        await _session.load();
        if (_session.current?.userId != previousUser) {
          _policy = await _policies.refreshIfStale(force: true);
        }
        await evaluate();
        _triggerSync();
      case TaskCommand.syncNow:
        _triggerSync(manual: true);
      case TaskCommand.refreshPolicy:
        _policy = await _policies.refreshIfStale(force: true);
        await evaluate();
      case TaskCommand.permissionsChanged:
        await evaluate();
      case TaskCommand.publishStatus:
        await _publishNumbers(force: true);
      case TaskCommand.flush:
        await _flush(data['requestId'] as String? ?? '');
    }
  }

  /// Sign-out / user swap: stop collecting, upload once, report how many went.
  Future<void> _flush(String requestId) async {
    _stopping = true;
    await _stopPositions();
    await _setStatus(state: TrackingState.stopping);
    var processed = 0;
    try {
      processed = (await _sync.runCycle(manual: true)).processed;
    } catch (e) {
      _logger.warn('Flush failed: $e');
    }
    _port.publishFlushed(requestId, processed);
  }

  Future<void> stop() async {
    await _stopPositions();
    await _providerChanges?.cancel();
    await _networkChanges?.cancel();
    await _meta.set(SyncMetaKeys.serviceRunning, '0');
  }

  void _startPositions(String userId) {
    unawaited(_positions?.cancel());
    _filter.reset();
    _sampler.reset();
    _collectingFor = userId;
    _collectingSince = _now();
    _lastFixAt = null;
    _positions = _source
        .positions(interval: _config.gpsSampleInterval, distanceFilter: 0)
        .listen(_onPosition, onError: _onPositionError, onDone: () => _positions = null);
  }

  Future<void> _stopPositions() async {
    await _positions?.cancel();
    _positions = null;
    _collectingFor = null;
    _watchdogRestarted = false;
  }

  /// Every GPS sample: cleaned, fed to the sampler, stored only when it
  /// becomes a (movement) ping. Any accepted sample proves the GPS is alive.
  Future<void> _onPosition(PositionModel raw) async {
    final userId = _collectingFor;
    final accepted = _filter.accept(raw);
    if (userId == null || accepted == null) return;
    _lastFixAt = _now();
    _watchdogRestarted = false;
    final ping = _sampler.add(accepted);
    if (ping != null) await _record(ping, userId);
    if (_status.state != TrackingState.running) await evaluate();
  }

  /// Store first, then publish; uploads early once a full batch is waiting.
  Future<void> _record(PositionModel ping, String userId) async {
    try {
      final fix = await _locations.store(ping, userId: userId);
      _port.publishLocation(fix);
      final pending = (await _points.counts(userId)).pending;
      if (pending >= _config.uploadBatchSize) _triggerSync();
    } on Failure catch (f) {
      _logger.error('Could not store a fix', f);
    }
  }

  void _onPositionError(Object error) {
    _logger.warn('Position stream error: $error');
    if (error is LocationFailure && error.disabled) {
      // isLocationServiceEnabled() can say "on" while the fused provider says
      // "off" (e.g. emulator with GPS off): re-evaluating now would restart the
      // stream in a tight loop. Wait for a provider change or the next tick.
      unawaited(_stopPositions().then(
        (_) => _setStatus(state: TrackingState.error, errorCode: TrackingErrorCode.locationDisabled),
      ));
      return;
    }
    unawaited(_stopPositions().then((_) => evaluate()));
  }

  void _triggerSync({bool manual = false}) {
    if (_stopping) return;
    unawaited(_sync.runCycle(manual: manual).then((_) => _publishNumbers()));
  }

  Future<void> _setStatus({required TrackingState state, String? reason, String? errorCode}) async {
    final permissions = await _safePermissions();
    final next = _status.copyWith(
      state: state,
      reason: () => reason,
      errorCode: () => errorCode,
      backgroundService: true,
      enabled: _policy.enabled,
      locationPermission: permissions?.location.wire,
      backgroundPermission: permissions?.backgroundLocation.wire,
    );
    final changed = next.state != _status.state || next.reason != _status.reason || next.errorCode != _status.errorCode;
    _status = next;
    if (!changed && _announced) return;
    _announced = true;
    _logger.info('Tracking ${next.state.wire}${reason != null ? ' ($reason)' : ''}${errorCode != null ? ' [$errorCode]' : ''}');
    _port.publishStatus(next);
    final lang = _session.current?.lang ?? 'en';
    try {
      await _port.updateNotification(next, lang: lang);
    } catch (_) {
      // The service may be shutting down.
    }
  }

  /// Pending count, last fix, last upload — published on ticks, not per fix.
  Future<void> _publishNumbers({bool force = false}) async {
    final userId = _session.current?.userId;
    final pending = userId == null ? 0 : (await _points.counts(userId)).pending;
    final lastUploadAt = await _meta.getDate(SyncMetaKeys.lastSuccessAt);
    // Read _status only after the awaits, so a state change made meanwhile
    // (e.g. flush → stopping) is not overwritten by a stale copy.
    final next = _status.copyWith(pendingUploads: pending, lastLocationAt: _lastFixAt, lastUploadAt: lastUploadAt);
    if (force || next != _status) {
      _status = next;
      _port.publishStatus(next);
    }
  }

  Future<PermissionStatusModel?> _safePermissions() async {
    try {
      return await _permissions.status();
    } catch (_) {
      return null;
    }
  }

  Future<void> _shutdown() async {
    if (_stopping) return;
    _stopping = true;
    await _sync.runCycle(manual: true);
    await _port.stopService();
  }
}
