/// `bloc_test` coverage for `TrackingCubit`: prompts the walkthrough on
/// `permission_required`, on first run while background location is missing,
/// never when signed out or already completed, and only once per session.
///
/// Status: active — part of `flutter test`.
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dynaopsapp/features/auth/data/session_model.dart';
import 'package:dynaopsapp/features/auth/data/session_repository.dart';
import 'package:dynaopsapp/features/permissions/data/permissions_repository.dart';
import 'package:dynaopsapp/features/tracking/cubit/tracking_cubit.dart';
import 'package:dynaopsapp/features/tracking/cubit/tracking_state.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_repository.dart';
import 'package:dynaopsapp/features/tracking/data/tracking_status_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTracking extends Mock implements TrackingRepository {}

class _MockPermissions extends Mock implements PermissionsRepository {}

class _MockSession extends Mock implements SessionRepository {}

void main() {
  const blocked = TrackingStatusModel(state: TrackingState.permissionRequired);
  const runningNoBackground =
      TrackingStatusModel(state: TrackingState.running, backgroundService: true, backgroundPermission: 'denied');
  const runningAll =
      TrackingStatusModel(state: TrackingState.running, backgroundService: true, backgroundPermission: 'granted');

  late _MockTracking tracking;
  late _MockPermissions permissions;
  late _MockSession session;
  late StreamController<TrackingStatusModel> statuses;

  setUp(() {
    tracking = _MockTracking();
    permissions = _MockPermissions();
    session = _MockSession();
    statuses = StreamController.broadcast();
    when(() => tracking.statuses).thenAnswer((_) => statuses.stream);
    when(() => tracking.current).thenReturn(blocked);
    when(() => permissions.walkthroughCompleted).thenReturn(false);
    when(() => session.current).thenReturn(SessionModel(token: 't', userId: 'u', expireAt: DateTime.utc(2030)));
  });

  tearDown(() => statuses.close());

  TrackingCubit build() => TrackingCubit(tracking, permissions, session);

  blocTest<TrackingCubit, TrackingViewState>(
    'prompts when tracking needs location permission, then only once',
    build: build,
    act: (cubit) async {
      cubit
        ..start()
        ..walkthroughOpened();
      statuses.add(const TrackingStatusModel(state: TrackingState.permissionDenied));
      await pumpEventQueue();
    },
    expect: () => [
      const TrackingViewReady(blocked, promptWalkthrough: true),
      const TrackingViewReady(blocked, promptWalkthrough: false),
      const TrackingViewReady(TrackingStatusModel(state: TrackingState.permissionDenied), promptWalkthrough: false),
    ],
  );

  blocTest<TrackingCubit, TrackingViewState>(
    'prompts on first run while background location is missing',
    setUp: () => when(() => tracking.current).thenReturn(runningNoBackground),
    build: build,
    act: (cubit) => cubit.start(),
    expect: () => [const TrackingViewReady(runningNoBackground, promptWalkthrough: true)],
  );

  blocTest<TrackingCubit, TrackingViewState>(
    'does not prompt once completed, or when everything is granted',
    setUp: () {
      when(() => permissions.walkthroughCompleted).thenReturn(true);
      when(() => tracking.current).thenReturn(runningNoBackground);
    },
    build: build,
    act: (cubit) async {
      cubit.start();
      statuses.add(runningAll);
      await pumpEventQueue();
    },
    expect: () => [
      const TrackingViewReady(runningNoBackground, promptWalkthrough: false),
      const TrackingViewReady(runningAll, promptWalkthrough: false),
    ],
  );

  blocTest<TrackingCubit, TrackingViewState>(
    'never prompts when signed out',
    setUp: () => when(() => session.current).thenReturn(null),
    build: build,
    act: (cubit) => cubit.start(),
    expect: () => [const TrackingViewReady(blocked, promptWalkthrough: false)],
  );
}
