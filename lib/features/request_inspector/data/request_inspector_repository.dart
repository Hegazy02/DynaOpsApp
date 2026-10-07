/// `RequestInspectorRepository`: everything the request inspector shows —
/// recorded API exchanges (both isolates), the current user's upload queue,
/// sync numbers — plus clear log / upload now / retry failed, and a stream
/// that ticks on every `sync.*` event.
///
/// Why it exists: keeps the inspector Cubit off DAOs and the sync plumbing;
/// database errors surface as `DatabaseFailure`.
/// Status: used — registered in `service_locator.dart`, used by
/// `RequestInspectorCubit`.
library;

import 'package:sqflite/sqflite.dart';

import '../../../core/network/failure.dart';
import '../../auth/data/session_repository.dart';
import '../../sync/data/sync_repository.dart';
import '../../sync/data/sync_status_model.dart';
import '../../tracking/data/location_points_dao.dart';
import '../../tracking/data/queued_fix_model.dart';
import 'request_log_dao.dart';
import 'request_log_entry_model.dart';

class RequestInspectorRepository {
  RequestInspectorRepository(this._log, this._points, this._sync, this._session, {required this.localTimestamps});

  final RequestLogDao _log;
  final LocationPointsDao _points;
  final SyncRepository _sync;
  final SessionRepository _session;

  /// How queued fixes' `at` will be formatted on the wire (`AppConfig.pingTimestampsLocal`).
  final bool localTimestamps;

  Stream<void> get syncEvents => _sync.events;

  /// Newest first.
  Future<List<RequestLogEntryModel>> requests() => _guard(_log.recent);

  /// Oldest first; empty when signed out.
  Future<List<QueuedFixModel>> queue() => _guard(() async {
        final userId = _session.current?.userId;
        return userId == null ? const <QueuedFixModel>[] : _points.queued(userId);
      });

  Future<SyncStatusModel> syncStatus() => _guard(_sync.status);

  Future<void> clearLog() => _guard(_log.clear);

  Future<bool> syncNow() => _sync.syncNow();

  Future<int> retryFailed() => _guard(_sync.retryFailed);

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DatabaseException catch (e) {
      throw DatabaseFailure(e.toString());
    }
  }
}
