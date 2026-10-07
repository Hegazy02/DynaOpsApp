/// `LocationPointsDao`: hand-written SQL for the location points store (§9):
/// insert, claim a batch for upload, mark synced/pending/failed, delete
/// synced rows after upload (the only cleanup — the phone keeps no location
/// history), counts, latest fix and dead-letter requeue. Every query is
/// scoped to one `userId`.
///
/// Why it exists: raw data-source layer under `LocationRepository` and
/// `SyncManager`; claim-by-batch-id makes it safe for both isolates.
/// Status: used — by `LocationRepository`, `SyncManager`, `SyncRepository`;
/// tested in `test/features/tracking/data/location_points_dao_test.dart`.
library;

import 'package:sqflite/sqflite.dart';

import 'location_fix_model.dart';
import 'queued_fix_model.dart';

class PointCounts {
  const PointCounts({required this.pending, required this.failed});
  final int pending;
  final int failed;
}

class LocationPointsDao {
  LocationPointsDao(this._db);
  final Database _db;

  static const _table = 'location_points';

  Future<void> insert(LocationFixModel fix, {required DateTime now}) =>
      _db.insert(_table, fix.toRow(createdAt: now), conflictAlgorithm: ConflictAlgorithm.ignore);

  /// Atomically moves up to [limit] oldest pending fixes of [userId] to
  /// `uploading` under [batchId] and returns exactly those rows.
  Future<List<LocationFixModel>> claimBatch({
    required String userId,
    required String batchId,
    required int limit,
  }) {
    return _db.transaction((txn) async {
      final ids = await txn.query(
        _table,
        columns: ['id'],
        where: 'user_id = ? AND state = ?',
        whereArgs: [userId, FixState.pending.wire],
        orderBy: 'captured_at ASC',
        limit: limit,
      );
      if (ids.isEmpty) return const <LocationFixModel>[];
      final idList = ids.map((r) => r['id']! as String).toList();
      await txn.update(
        _table,
        {'state': FixState.uploading.wire, 'batch_id': batchId},
        where: 'state = ? AND id IN (${_placeholders(idList.length)})',
        whereArgs: [FixState.pending.wire, ...idList],
      );
      final rows = await txn.query(
        _table,
        where: 'batch_id = ? AND state = ?',
        whereArgs: [batchId, FixState.uploading.wire],
        orderBy: 'captured_at ASC',
      );
      return rows.map(LocationFixModel.fromRow).toList();
    });
  }

  Future<void> markSynced(String batchId) => _db.update(
        _table,
        {'state': FixState.synced.wire, 'last_error': null},
        where: 'batch_id = ? AND state = ?',
        whereArgs: [batchId, FixState.uploading.wire],
      );

  /// Deletes [userId]'s `synced` rows — the server has them — except the
  /// user's newest row, which `tracking.latest` may still answer from.
  Future<int> deleteSynced(String userId) => _db.rawDelete(
        'DELETE FROM $_table WHERE user_id = ? AND state = ? AND id != '
        '(SELECT id FROM $_table WHERE user_id = ? ORDER BY captured_at DESC LIMIT 1)',
        [userId, FixState.synced.wire, userId],
      );

  /// Back to `pending`; with [countAttempt] the attempt counts toward
  /// [maxAttempts], after which the rows are dead-lettered (`failed`, retryable).
  Future<void> releaseBatch(
    String batchId, {
    required String error,
    required bool countAttempt,
    required int maxAttempts,
  }) async {
    final increment = countAttempt ? 1 : 0;
    await _db.rawUpdate(
      'UPDATE $_table SET attempts = attempts + ?, last_error = ?, '
      "state = CASE WHEN attempts + ? >= ? THEN '${FixState.failed.wire}' ELSE '${FixState.pending.wire}' END, "
      'retryable = 1 WHERE batch_id = ? AND state = ?',
      [increment, error, increment, maxAttempts, batchId, FixState.uploading.wire],
    );
  }

  Future<void> failBatch(String batchId, {required String error, required bool retryable}) => _db.update(
        _table,
        {'state': FixState.failed.wire, 'last_error': error, 'retryable': retryable ? 1 : 0},
        where: 'batch_id = ? AND state = ?',
        whereArgs: [batchId, FixState.uploading.wire],
      );

  /// Crash recovery: anything left `uploading` goes back to `pending` (§11).
  Future<int> resetUploading() => _db.update(
        _table,
        {'state': FixState.pending.wire},
        where: 'state = ?',
        whereArgs: [FixState.uploading.wire],
      );

  /// `sync.retryFailed`: retryable dead letters back to pending.
  Future<int> requeueFailed(String userId) => _db.update(
        _table,
        {'state': FixState.pending.wire, 'attempts': 0},
        where: 'user_id = ? AND state = ? AND retryable = 1',
        whereArgs: [userId, FixState.failed.wire],
      );

  Future<PointCounts> counts(String userId) async {
    final rows = await _db.rawQuery(
      'SELECT state, COUNT(*) AS n FROM $_table WHERE user_id = ? AND state IN (?, ?, ?) GROUP BY state',
      [userId, FixState.pending.wire, FixState.uploading.wire, FixState.failed.wire],
    );
    var pending = 0;
    var failed = 0;
    for (final row in rows) {
      final n = row['n']! as int;
      if (row['state'] == FixState.failed.wire) {
        failed += n;
      } else {
        pending += n;
      }
    }
    return PointCounts(pending: pending, failed: failed);
  }

  /// Not-yet-synced fixes of [userId] (pending, uploading, failed), oldest first.
  Future<List<QueuedFixModel>> queued(String userId, {int limit = 500}) async {
    final rows = await _db.query(
      _table,
      where: 'user_id = ? AND state != ?',
      whereArgs: [userId, FixState.synced.wire],
      orderBy: 'captured_at ASC',
      limit: limit,
    );
    return rows.map(QueuedFixModel.fromRow).toList();
  }

  Future<LocationFixModel?> latest(String userId) async {
    final rows = await _db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'captured_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : LocationFixModel.fromRow(rows.first);
  }

  static String _placeholders(int n) => List.filled(n, '?').join(', ');
}
