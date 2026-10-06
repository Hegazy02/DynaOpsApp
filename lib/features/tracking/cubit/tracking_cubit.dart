/// `TrackingCubit`: follows `TrackingRepository.statuses` on the shell route
/// and decides when the native permission walkthrough must open (§13): when
/// tracking reports `permission_required`/`permission_denied`, or on the
/// first launch after login while background location is not granted and the
/// walkthrough was never completed. Prompts at most once per app session.
///
/// Why it exists: the decision is UI state, kept out of `ShellScreen`; the
/// navigation itself happens in the screen's `BlocListener`.
/// Status: used — provided on the `/` route; tested in
/// `test/features/tracking/cubit/tracking_cubit_test.dart`.
library;

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/data/session_repository.dart';
import '../../permissions/data/permissions_repository.dart';
import '../data/tracking_repository.dart';
import '../data/tracking_status_model.dart';
import 'tracking_state.dart';

class TrackingCubit extends Cubit<TrackingViewState> {
  TrackingCubit(this._tracking, this._permissions, this._session) : super(const TrackingViewInitial());

  final TrackingRepository _tracking;
  final PermissionsRepository _permissions;
  final SessionRepository _session;
  StreamSubscription<TrackingStatusModel>? _subscription;
  bool _promptedThisSession = false;

  void start() {
    _subscription = _tracking.statuses.listen(_show);
    _show(_tracking.current);
  }

  /// The screen opened the walkthrough; do not ask again until the next launch.
  void walkthroughOpened() {
    _promptedThisSession = true;
    if (state case TrackingViewReady(:final status)) emit(TrackingViewReady(status, promptWalkthrough: false));
  }

  void _show(TrackingStatusModel status) {
    if (isClosed) return;
    emit(TrackingViewReady(status, promptWalkthrough: !_promptedThisSession && _needsWalkthrough(status)));
  }

  bool _needsWalkthrough(TrackingStatusModel status) {
    if (_session.current == null) return false;
    if (status.state == TrackingState.permissionRequired || status.state == TrackingState.permissionDenied) {
      return true;
    }
    return !_permissions.walkthroughCompleted && status.backgroundPermission != 'granted' && status.backgroundService;
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
