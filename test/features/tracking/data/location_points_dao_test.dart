/// Tests for `LocationPointsDao` on a real in-memory SQLite: per-user
/// counts and isolation, oldest-first claiming that never hands the same row
/// to two batches, synced / released / dead-lettered / permanently failed
/// transitions, requeue of retryable failures, crash recovery, latest fix,
/// and retention that never deletes pending rows.
///
/// Status: active — part of `flutter test`.
library;

import 'package:dynaopsapp/core/database/app_database.dart';
import 'package:dynaopsapp/features/tracking/data/location_fix_model.dart';
import 'package:dynaopsapp/features/tracking/data/location_points_dao.dart';
import 'package:dynaopsapp/features/tracking/data/position_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

LocationFixModel fix(String id, String userId, int minute) => LocationFixModel(
      id: id,
      userId: userId,
      position: PositionModel(
        latitude: 30,
        longitude: 31,
        accuracy: 5,
        timestamp: DateTime.utc(2026, 10, 6, 9, minute),
      ),
    );

void main() {
  final now = DateTime.utc(2026, 10, 6, 12);
  late AppDatabase database;
  late LocationPointsDao dao;

  setUp(() async {
    database = await openTestDatabase();
    dao = LocationPointsDao(database.db);
    for (final f in [fix('a1', 'A', 1), fix('a2', 'A', 2), fix('a3', 'A', 3), fix('b1', 'B', 1)]) {
      await dao.insert(f, now: now);
    }
  });

  tearDown(() => database.close());

  test('counts are per user', () async {
    expect((await dao.counts('A')).pending, 3);
    expect((await dao.counts('B')).pending, 1);
  });

  test('claims oldest first, only for that user, never twice', () async {
    final first = await dao.claimBatch(userId: 'A', batchId: 'x', limit: 2);
    expect(first.map((f) => f.id), ['a1', 'a2']);
    final second = await dao.claimBatch(userId: 'A', batchId: 'y', limit: 2);
    expect(second.map((f) => f.id), ['a3']);
    expect(await dao.claimBatch(userId: 'A', batchId: 'z', limit: 2), isEmpty);
    expect((await dao.counts('B')).pending, 1);
  });

  test('synced rows leave the pending count', () async {
    await dao.claimBatch(userId: 'A', batchId: 'x', limit: 10);
    await dao.markSynced('x');
    expect((await dao.counts('A')).pending, 0);
  });

  test('release counts attempts and dead-letters after the maximum', () async {
    await dao.claimBatch(userId: 'A', batchId: 'x', limit: 1);
    await dao.releaseBatch('x', error: 'timeout', countAttempt: true, maxAttempts: 2);
    expect((await dao.counts('A')).pending, 3);

    await dao.claimBatch(userId: 'A', batchId: 'y', limit: 1);
    await dao.releaseBatch('y', error: 'timeout', countAttempt: true, maxAttempts: 2);
    final counts = await dao.counts('A');
    expect((counts.pending, counts.failed), (2, 1));
  });

  test('requeue brings back retryable failures only', () async {
    await dao.claimBatch(userId: 'A', batchId: 'x', limit: 1);
    await dao.failBatch('x', error: '403', retryable: true);
    await dao.claimBatch(userId: 'A', batchId: 'y', limit: 1);
    await dao.failBatch('y', error: '422', retryable: false);
    expect(await dao.requeueFailed('A'), 1);
    final counts = await dao.counts('A');
    expect((counts.pending, counts.failed), (2, 1));
  });

  test('resetUploading recovers rows left in flight by a crash', () async {
    await dao.claimBatch(userId: 'A', batchId: 'x', limit: 2);
    expect(await dao.resetUploading(), 2);
    expect((await dao.claimBatch(userId: 'A', batchId: 'y', limit: 5)).length, 3);
  });

  test('latest returns the newest fix of that user', () async {
    expect((await dao.latest('A'))!.id, 'a3');
    expect(await dao.latest('C'), isNull);
  });

  test('purge drops old synced rows and never pending ones', () async {
    await dao.claimBatch(userId: 'A', batchId: 'x', limit: 2);
    await dao.markSynced('x');
    final removed = await dao.purge(syncedBefore: now, maxRows: 100);
    expect(removed, 2);
    expect((await dao.counts('A')).pending, 1);
    expect((await dao.counts('B')).pending, 1);
  });

  test('a duplicate id is ignored, not an error', () async {
    await dao.insert(fix('a1', 'A', 9), now: now);
    expect((await dao.counts('A')).pending, 3);
  });
}
