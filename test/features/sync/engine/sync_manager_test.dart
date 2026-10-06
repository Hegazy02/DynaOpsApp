/// Tests for `SyncManager` on a real in-memory database with a mocked
/// uploader and session: batching oldest-first with progress events,
/// 400/413/422 dropped for good, 401 pausing with rows kept and the session
/// marked expired, transient errors backing off (and `manual` bypassing it),
/// expired session / offline / nothing pending skipping, never uploading
/// another user's rows, and crash recovery.
///
/// Status: active — part of `flutter test`.
library;

import 'package:dynaopsapp/core/database/app_database.dart';
import 'package:dynaopsapp/core/logging/app_logger.dart';
import 'package:dynaopsapp/core/network/failure.dart';
import 'package:dynaopsapp/features/auth/data/session_model.dart';
import 'package:dynaopsapp/features/auth/data/session_repository.dart';
import 'package:dynaopsapp/features/sync/data/location_uploader.dart';
import 'package:dynaopsapp/features/sync/data/sync_meta_dao.dart';
import 'package:dynaopsapp/features/sync/engine/sync_manager.dart';
import 'package:dynaopsapp/features/tracking/data/location_fix_model.dart';
import 'package:dynaopsapp/features/tracking/data/location_points_dao.dart';
import 'package:dynaopsapp/features/tracking/data/position_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/test_database.dart';

class _MockUploader extends Mock implements LocationUploader {}

class _MockSession extends Mock implements SessionRepository {}

void main() {
  final now = DateTime.utc(2026, 10, 6, 12);
  final sessionA = SessionModel(token: 't', userId: 'A', expireAt: DateTime.utc(2030));
  late AppDatabase database;
  late LocationPointsDao points;
  late SyncMetaDao meta;
  late _MockUploader uploader;
  late _MockSession session;
  late bool online;
  late List<String> events;

  Future<void> seed(String userId, int count) async {
    for (var i = 0; i < count; i++) {
      await points.insert(
        LocationFixModel(
          id: '$userId$i',
          userId: userId,
          position: PositionModel(latitude: 30, longitude: 31, accuracy: 5, timestamp: now.add(Duration(seconds: i))),
        ),
        now: now,
      );
    }
  }

  SyncManager manager({int batchSize = 2}) => SyncManager(
        points,
        meta,
        uploader,
        session,
        AppLogger(),
        isOnline: () async => online,
        batchSize: batchSize,
        maxAttempts: 3,
        clock: () => now,
      )..onEvent = (event, _) => events.add(event);

  setUpAll(() => registerFallbackValue(<LocationFixModel>[]));

  setUp(() async {
    database = await openTestDatabase();
    points = LocationPointsDao(database.db);
    meta = SyncMetaDao(database.db);
    uploader = _MockUploader();
    session = _MockSession();
    online = true;
    events = [];
    when(() => session.current).thenReturn(sessionA);
    when(() => session.validToken).thenReturn('t');
    when(() => session.markExpired()).thenAnswer((_) async {});
    when(() => uploader.upload(any())).thenAnswer((_) async {});
  });

  tearDown(() => database.close());

  test('uploads everything in oldest-first batches', () async {
    await seed('A', 5);
    final uploaded = <List<String>>[];
    when(() => uploader.upload(any())).thenAnswer((call) async {
      uploaded.add((call.positionalArguments.first as List<LocationFixModel>).map((f) => f.id).toList());
    });

    final result = await manager().runCycle();

    expect(result.processed, 5);
    expect(uploaded, [['A0', 'A1'], ['A2', 'A3'], ['A4']]);
    expect((await points.counts('A')).pending, 0);
    expect(events, ['sync.started', 'sync.progress', 'sync.progress', 'sync.progress', 'sync.completed']);
    expect(await meta.getDate(SyncMetaKeys.lastSuccessAt), now);
  });

  test("never uploads another user's rows", () async {
    await seed('B', 3);
    final result = await manager().runCycle();
    expect(result.ran, false);
    verifyNever(() => uploader.upload(any()));
  });

  test('a rejected batch is dropped for good and the rest still goes', () async {
    await seed('A', 3);
    var calls = 0;
    when(() => uploader.upload(any())).thenAnswer((_) async {
      if (calls++ == 0) throw const ValidationFailure('bad payload');
    });

    final result = await manager().runCycle();

    expect((result.processed, result.failed), (1, 2));
    final counts = await points.counts('A');
    expect((counts.pending, counts.failed), (0, 2));
    expect(await points.requeueFailed('A'), 0, reason: 'not retryable');
  });

  test('401 keeps the rows, marks the session expired and stops', () async {
    await seed('A', 3);
    when(() => uploader.upload(any())).thenThrow(const UnauthorizedFailure());

    await manager().runCycle();

    expect((await points.counts('A')).pending, 3);
    verify(() => session.markExpired()).called(1);
    expect(events.last, 'sync.failed');
  });

  test('transient errors back off; manual runs ignore the backoff', () async {
    await seed('A', 1);
    when(() => uploader.upload(any())).thenThrow(const NetworkFailure());
    final m = manager();

    await m.runCycle();
    expect((await m.runCycle()).skippedBecause, 'backing off');
    expect((await m.runCycle(manual: true)).ran, true);
    final counts = await points.counts('A');
    expect((counts.pending, counts.failed), (1, 0));

    await m.runCycle(manual: true);
    expect((await points.counts('A')).failed, 1, reason: 'dead-lettered after 3 attempts');
  });

  test('skips when the session expired, offline, or nothing is pending', () async {
    expect((await manager().runCycle()).skippedBecause, 'nothing pending');
    await seed('A', 1);
    online = false;
    expect((await manager().runCycle()).skippedBecause, 'offline');
    when(() => session.validToken).thenReturn(null);
    expect((await manager().runCycle()).skippedBecause, 'session expired');
    verifyNever(() => uploader.upload(any()));
  });

  test('recover puts in-flight rows back to pending', () async {
    await seed('A', 2);
    await points.claimBatch(userId: 'A', batchId: 'crashed', limit: 2);
    await manager().recover();
    expect((await manager().runCycle()).processed, 2);
  });
}
