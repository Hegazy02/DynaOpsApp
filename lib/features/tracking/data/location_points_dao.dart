/// `LocationPointsDao`: hand-written SQL for the location points store (§9):
/// insert, claim a batch for upload, mark synced/pending/failed, counts,
/// latest fix, dead-letter requeue and retention purge. Every query is scoped
/// to one `userId`.
///
/// Why it exists: raw data-source layer under `LocationRepository` and
/// `SyncManager`; claim-by-batch-id makes it safe for both isolates.
/// Status: used — by `LocationRepository`, `SyncManager`, `SyncRepository`;
/// tested in `test/features/tracking/data/location_points_dao_test.dart`.
library;

import 'package:sqflite/sqflite.dart';

import 'location_fix_model.dart';

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

  /// Retention (§9): drops `synced` rows older than [syncedBefore], then the
  /// oldest `synced` rows beyond [maxRows]. Never touches pending or failed.
  Future<int> purge({required DateTime syncedBefore, required int maxRows}) async {
    var removed = await _db.delete(
      _table,
      where: 'state = ? AND captured_at < ?',
      whereArgs: [FixState.synced.wire, syncedBefore.toUtc().millisecondsSinceEpoch],
    );
    final total = Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM $_table')) ?? 0;
    if (total > maxRows) {
      removed += await _db.rawDelete(
        'DELETE FROM $_table WHERE id IN (SELECT id FROM $_table WHERE state = ? ORDER BY captured_at ASC LIMIT ?)',
        [FixState.synced.wire, total - maxRows],
      );
    }
    return removed;
  }

  static String _placeholders(int n) => List.filled(n, '?').join(', ');
}
