/// `SyncRepository` (UI isolate): `sync.status` numbers from the shared
/// database, `sync.now` / `sync.retryFailed`, and one stream of `sync.*`
/// events — relayed from the service, or from a local `SyncManager` that only
/// runs while the service is stopped (e.g. tracking disabled by an admin with
/// fixes still queued).
///
/// Why it exists: the bridge and diagnostics screen see one sync view no
/// matter which isolate uploads; the database's claim-by-batch keeps the two
/// from sending the same rows.
/// Status: used — registered in `service_locator.dart`; used by
/// `SyncHandler`, `TrackingCoordinator` and the diagnostics screen.
library;

import 'dart:async';

import '../../auth/data/session_repository.dart';
import '../../tracking/data/location_points_dao.dart';
import '../../tracking/data/tracking_service_client.dart';
import '../../tracking/engine/task_protocol.dart';
import '../engine/sync_manager.dart';
import 'sync_meta_dao.dart';
import 'sync_status_model.dart';

class SyncEvent {
  const SyncEvent(this.name, this.data);
  final String name;
  final Map<String, Object?> data;
}

class SyncRepository {
  SyncRepository(this._client, this._points, this._meta, this._session, this._localManager) {
    _localManager.onEvent = _emit;
    _messages = _client.messages.listen((message) {
      if (message[TaskMessage.key] != TaskMessage.sync) return;
      final data = message['data'];
      _emit(
        message['event']! as String,
        data is Map ? data.map((k, v) => MapEntry(k! as String, v)) : const {},
      );
    });
  }

  final TrackingServiceClient _client;
  final LocationPointsDao _points;
  final SyncMetaDao _meta;
  final SessionRepository _session;
  final SyncManager _localManager;
  final _events = StreamController<SyncEvent>.broadcast();
  late final StreamSubscription<Map<Object?, Object?>> _messages;
  bool _running = false;

  Stream<SyncEvent> get events => _events.stream;

  Future<SyncStatusModel> status() async {
    final userId = _session.current?.userId;
    final counts = userId == null ? null : await _points.counts(userId);
    return SyncStatusModel(
      running: _running || _localManager.running,
      pending: counts?.pending ?? 0,
      failed: counts?.failed ?? 0,
      lastSuccessAt: await _meta.getDate(SyncMetaKeys.lastSuccessAt),
      lastError: await _meta.get(SyncMetaKeys.lastError),
    );
  }

  /// Returns false when a cycle is already running here.
  Future<bool> syncNow() async {
    if (await _client.isRunning()) {
      _client.send({TaskCommand.key: TaskCommand.syncNow});
      return true;
    }
    if (_localManager.running) return false;
    unawaited(_localManager.runCycle(manual: true));
    return true;
  }

  /// Dead-lettered fixes of the current user back to pending, then a cycle.
  Future<int> retryFailed() async {
    final userId = _session.current?.userId;
    if (userId == null) return 0;
    final requeued = await _points.requeueFailed(userId);
    if (requeued > 0) await syncNow();
    return requeued;
  }

  /// Bounded upload from the UI isolate when the service is not running (sign-out).
  Future<int> flushLocal({Duration timeout = const Duration(seconds: 20)}) async {
    if (await _client.isRunning()) return 0;
    final result = await _localManager
        .runCycle(manual: true)
        .timeout(timeout, onTimeout: () => const SyncCycleResult.skipped('timeout'));
    return result.processed;
  }

  void _emit(String name, Map<String, Object?> data) {
    if (name == 'sync.started') _running = true;
    if (name == 'sync.completed' || name == 'sync.failed') _running = false;
    _events.add(SyncEvent(name, data));
  }

  Future<void> dispose() async {
    await _messages.cancel();
    await _events.close();
  }
}
