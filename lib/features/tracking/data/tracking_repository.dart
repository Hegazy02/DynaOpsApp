/// `TrackingRepository` (UI isolate): starts the tracking service when the
/// rules allow (foreground location granted, session present), forwards
/// commands, keeps the latest `TrackingStatusModel` from the service (or a
/// local one while it is stopped), relays fixes, flushes and stops it on
/// sign-out, and detects a previous Force Stop / kill (§8.2).
///
/// Why it exists: the bridge, Cubits and coordinator need one place that knows
/// whether tracking runs and why not, without touching the plugin directly.
/// Status: used — registered in `service_locator.dart`; used by
/// `TrackingCoordinator`, `TrackingHandler`, `TrackingCubit`, diagnostics.
library;

import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/failure.dart';
import '../../auth/data/session_repository.dart';
import '../../permissions/data/permission_status_model.dart';
import '../../permissions/data/permissions_repository.dart';
import '../../sync/data/sync_meta_dao.dart';
import '../engine/task_protocol.dart';
import 'location_fix_model.dart';
import 'location_points_dao.dart';
import 'tracking_service_client.dart';
import 'tracking_status_model.dart';

/// Title and text of the notification shown when the service starts, in [lang].
typedef NotificationTextFor = (String, String) Function(String lang);

class TrackingRepository {
  TrackingRepository(
    this._client,
    this._permissions,
    this._session,
    this._meta,
    this._points,
    this._logger, {
    required this._notificationText,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final TrackingServiceClient _client;
  final PermissionsRepository _permissions;
  final SessionRepository _session;
  final SyncMetaDao _meta;
  final LocationPointsDao _points;
  final AppLogger _logger;
  final NotificationTextFor _notificationText;
  final Uuid _uuid;

  final _statuses = StreamController<TrackingStatusModel>.broadcast();
  final _locations = StreamController<LocationFixModel>.broadcast();
  final _flushWaiters = <String, Completer<int>>{};
  StreamSubscription<Map<Object?, Object?>>? _messages;
  TrackingStatusModel _status = const TrackingStatusModel(state: TrackingState.stopped);

  TrackingStatusModel get current => _status;

  Stream<TrackingStatusModel> get statuses => _statuses.stream;

  /// Fixes as the service stores them (`tracking.location`).
  Stream<LocationFixModel> get locations => _locations.stream;

  /// Connects to a running service, or reports a previous Force Stop. Returns
  /// true when the service had been stopped uncleanly.
  Future<bool> init() async {
    _messages ??= _client.messages.listen(_onMessage);
    if (await _client.isRunning()) {
      _status = _status.copyWith(backgroundService: true);
      _client.send({TaskCommand.key: TaskCommand.publishStatus});
      return false;
    }
    final wasRunning = await _meta.get(SyncMetaKeys.serviceRunning) == '1';
    if (wasRunning) {
      await _meta.set(SyncMetaKeys.serviceRunning, '0');
      _logger.warn('Tracking service was stopped without a clean shutdown (Force Stop or kill)');
    }
    await _setLocal(
      state: TrackingState.stopped,
      reason: _session.current == null ? 'signedOut' : null,
      errorCode: wasRunning ? TrackingErrorCode.forceStoppedPreviously : null,
    );
    return wasRunning;
  }

  /// Starts the service, or tells a running one to re-read the session (D8).
  Future<TrackingStatusModel> ensureRunning() async {
    final session = _session.current;
    if (session == null) return _setLocal(state: TrackingState.stopped, reason: 'signedOut');
    final permissions = await _permissions.status();
    if (permissions.location != PermissionState.granted) {
      return _setLocal(
        state: permissions.location == PermissionState.permanentlyDenied
            ? TrackingState.permissionDenied
            : TrackingState.permissionRequired,
        permissions: permissions,
      );
    }
    if (await _client.isRunning()) {
      _client.send({TaskCommand.key: TaskCommand.sessionChanged});
      return _status;
    }
    final (title, text) = _notificationText(session.lang);
    await _setLocal(state: TrackingState.starting, permissions: permissions);
    try {
      await _client.start(title: title, text: text);
      _status = _status.copyWith(backgroundService: true);
    } on Failure catch (f) {
      _logger.error('Tracking service did not start', f);
      await _setLocal(state: TrackingState.error, errorCode: TrackingErrorCode.serviceStartFailed);
    }
    return _status;
  }

  /// Sends [command] (`TaskCommand`) when the service is running.
  Future<void> notify(String command) async {
    if (await _client.isRunning()) _client.send({TaskCommand.key: command});
  }

  /// Sign-out / user swap: the service stops collecting, uploads once (bounded
  /// by [timeout]) and is stopped. Returns how many fixes went up.
  Future<int> stopAndFlush({Duration timeout = const Duration(seconds: 20)}) async {
    if (!await _client.isRunning()) return 0;
    final requestId = _uuid.v4();
    final waiter = Completer<int>();
    _flushWaiters[requestId] = waiter;
    _client.send({TaskCommand.key: TaskCommand.flush, 'requestId': requestId});
    final processed = await waiter.future.timeout(timeout, onTimeout: () => 0);
    _flushWaiters.remove(requestId);
    await _client.stop();
    await _setLocal(state: TrackingState.stopped, reason: 'signedOut');
    return processed;
  }

  /// Fresh numbers: asks a running service, or recomputes locally.
  Future<TrackingStatusModel> refreshStatus() async {
    if (await _client.isRunning()) {
      _client.send({TaskCommand.key: TaskCommand.publishStatus});
      return _status;
    }
    return _setLocal(state: _status.state, reason: _status.reason, errorCode: _status.errorCode);
  }

  void _onMessage(Map<Object?, Object?> message) {
    switch (message[TaskMessage.key]) {
      case TaskMessage.status:
        if (message['status'] case final Map<Object?, Object?> raw) {
          _status = TrackingStatusModel.fromMessage(raw);
          _statuses.add(_status);
        }
      case TaskMessage.location:
        if (message['fix'] case final Map<Object?, Object?> raw) {
          _locations.add(LocationFixModel.fromMessage(raw));
        }
      case TaskMessage.flushed:
        _flushWaiters.remove(message['requestId'])?.complete(message['processed'] as int? ?? 0);
      case TaskMessage.log:
        if (message['line'] case final String line) _logger.external(line);
    }
  }

  /// Status computed in the UI isolate while the service is not running.
  Future<TrackingStatusModel> _setLocal({
    required TrackingState state,
    String? reason,
    String? errorCode,
    PermissionStatusModel? permissions,
  }) async {
    PermissionStatusModel? perms = permissions;
    try {
      perms ??= await _permissions.status();
    } catch (_) {}
    final userId = _session.current?.userId;
    final next = _status.copyWith(
      state: state,
      reason: () => reason,
      errorCode: () => errorCode,
      backgroundService: false,
      locationPermission: perms?.location.wire,
      backgroundPermission: perms?.backgroundLocation.wire,
      pendingUploads: userId == null ? 0 : (await _points.counts(userId)).pending,
      lastUploadAt: await _meta.getDate(SyncMetaKeys.lastSuccessAt),
    );
    if (next != _status) {
      _status = next;
      _statuses.add(next);
    }
    return _status;
  }

  Future<void> dispose() async {
    await _messages?.cancel();
    await _statuses.close();
    await _locations.close();
  }
}
