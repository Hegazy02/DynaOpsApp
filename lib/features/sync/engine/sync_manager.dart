/// `SyncManager`: uploads pending fixes in batches (§11). One cycle at a time;
/// oldest first; claims each batch atomically; 2xx → synced, then deleted
/// (all but the user's newest row); 400/413/422 →
/// failed for good; 403 → failed but retryable; 401 → pause and mark the
/// session expired (rows kept); transient errors → back to pending with
/// exponential backoff, dead-lettered after `maxAttempts`. Emits
/// `sync.started/progress/completed/failed`.
///
/// Why it exists: an engine, not a Cubit — it runs in the tracking-service
/// isolate with no screen (and in the UI isolate only while the service is
/// stopped); it calls repositories/DAOs and never blocks fix collection.
/// Status: used — created by both locators; tested in
/// `test/features/sync/engine/sync_manager_test.dart`.
library;

import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/failure.dart';
import '../../auth/data/session_repository.dart';
import '../../tracking/data/location_points_dao.dart';
import '../data/location_uploader.dart';
import '../data/sync_meta_dao.dart';
import '../data/sync_status_model.dart';
import 'backoff.dart';

typedef SyncEventSink = void Function(String event, Map<String, Object?> data);

class SyncManager {
  SyncManager(
    this._points,
    this._meta,
    this._uploader,
    this._session,
    this._logger, {
    required this.isOnline,
    required this.batchSize,
    this.maxAttempts = 10,
    math.Random? random,
    Uuid? uuid,
    DateTime Function()? clock,
  })  : _random = random ?? math.Random(),
        _uuid = uuid ?? const Uuid(),
        _now = clock ?? DateTime.now;

  final LocationPointsDao _points;
  final SyncMetaDao _meta;
  final LocationUploader _uploader;
  final SessionRepository _session;
  final AppLogger _logger;
  final Future<bool> Function() isOnline;
  final int batchSize;
  final int maxAttempts;
  final math.Random _random;
  final Uuid _uuid;
  final DateTime Function() _now;

  /// Receives every `sync.*` event; set by whoever forwards them to the UI.
  SyncEventSink? onEvent;

  bool _running = false;
  int _consecutiveFailures = 0;
  DateTime? _nextAllowedAt;

  bool get running => _running;

  /// Rows left `uploading` by a crash go back to `pending` (§11).
  Future<void> recover() async {
    final reset = await _points.resetUploading();
    if (reset > 0) _logger.info('Sync recovered $reset in-flight fixes');
  }

  /// One upload cycle. [manual] (`sync.now`, flush) ignores the backoff window.
  Future<SyncCycleResult> runCycle({bool manual = false}) async {
    if (_running) return const SyncCycleResult.skipped('already running');
    final session = _session.current;
    if (session == null) return const SyncCycleResult.skipped('signed out');
    if (_session.validToken == null) return const SyncCycleResult.skipped('session expired');
    final next = _nextAllowedAt;
    if (!manual && next != null && _now().isBefore(next)) return const SyncCycleResult.skipped('backing off');
    if (!await isOnline()) return const SyncCycleResult.skipped('offline');

    _running = true;
    var processed = 0;
    var failed = 0;
    try {
      final total = (await _points.counts(session.userId)).pending;
      if (total == 0) return const SyncCycleResult.skipped('nothing pending');
      _emit('sync.started', {'total': total});

      while (true) {
        final batchId = _uuid.v4();
        final batch = await _points.claimBatch(userId: session.userId, batchId: batchId, limit: batchSize);
        if (batch.isEmpty) break;
        try {
          await _uploader.upload(batch);
          await _points.markSynced(batchId);
          // The server has them now; keep no location history on the phone.
          await _points.deleteSynced(session.userId);
          processed += batch.length;
          _consecutiveFailures = 0;
          _nextAllowedAt = null;
          await _meta.setDate(SyncMetaKeys.lastSuccessAt, _now());
          await _meta.set(SyncMetaKeys.lastError, null);
        } on ValidationFailure catch (f) {
          // The server will never take these; drop them from the queue head.
          await _points.failBatch(batchId, error: f.message, retryable: false);
          failed += batch.length;
          _logger.warn('Sync: batch rejected (${batch.length}): ${f.message}');
        } on UnauthorizedFailure catch (f) {
          await _points.releaseBatch(batchId, error: f.message, countAttempt: false, maxAttempts: maxAttempts);
          await _session.markExpired();
          return await _fail('UNAUTHORIZED', f.message, processed, failed);
        } on ForbiddenFailure catch (f) {
          await _points.failBatch(batchId, error: f.message, retryable: true);
          failed += batch.length;
          return await _fail('PERMISSION_DENIED', f.message, processed, failed);
        } on Failure catch (f) {
          await _points.releaseBatch(batchId, error: f.message, countAttempt: true, maxAttempts: maxAttempts);
          _consecutiveFailures++;
          _nextAllowedAt = _now().add(backoffDelay(_consecutiveFailures, random: _random));
          return await _fail('NETWORK_ERROR', f.message, processed, failed);
        }
        _emit('sync.progress', {'processed': processed, 'total': total, 'failed': failed});
        if (batch.length < batchSize) break;
      }

      _emit('sync.completed', {'processed': processed, 'total': total, 'failed': failed});
      return SyncCycleResult(ran: true, processed: processed, failed: failed);
    } catch (e, stackTrace) {
      _logger.error('Sync cycle crashed', e, stackTrace);
      await _points.resetUploading();
      return await _fail('SYNC_ERROR', 'Unexpected sync error.', processed, failed);
    } finally {
      _running = false;
    }
  }

  Future<SyncCycleResult> _fail(String code, String message, int processed, int failed) async {
    await _meta.set(SyncMetaKeys.lastError, '$code: $message');
    _emit('sync.failed', {'code': code, 'message': message});
    return SyncCycleResult(ran: true, processed: processed, failed: failed);
  }

  void _emit(String event, Map<String, Object?> data) => onEvent?.call(event, data);
}
