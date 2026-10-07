/// `RequestInspectorCubit`: loads the recorded API exchanges, the upload queue
/// and sync numbers, refreshes on every `sync.*` event and on a short poll
/// (the service isolate writes to the shared database without telling this
/// one), and runs upload now / retry failed / clear log.
///
/// Why it exists: the inspector screen only renders state and forwards taps.
/// Status: used — provided on `/requests`.
library;

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/failure.dart';
import '../data/request_inspector_repository.dart';
import 'request_inspector_state.dart';

class RequestInspectorCubit extends Cubit<RequestInspectorState> {
  RequestInspectorCubit(this._repository, {this.pollEvery = const Duration(seconds: 3)})
      : super(const RequestInspectorLoading());

  final RequestInspectorRepository _repository;
  final Duration pollEvery;
  StreamSubscription<void>? _events;
  Timer? _poll;
  int _sequence = 0;
  bool _refreshing = false;

  Future<void> load() async {
    _events ??= _repository.syncEvents.listen((_) => refresh());
    _poll ??= Timer.periodic(pollEvery, (_) => refresh());
    await refresh();
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final requests = await _repository.requests();
      final queue = await _repository.queue();
      final sync = await _repository.syncStatus();
      if (isClosed) return;
      final notice = switch (state) {
        RequestInspectorLoaded(:final notice) => notice,
        _ => null,
      };
      emit(RequestInspectorLoaded(
        requests: requests,
        queue: queue,
        sync: sync,
        localTimestamps: _repository.localTimestamps,
        notice: notice,
      ));
    } on Failure catch (f) {
      if (!isClosed) emit(RequestInspectorError(f.message));
    } finally {
      _refreshing = false;
    }
  }

  Future<void> syncNow() async {
    try {
      final started = await _repository.syncNow();
      await refresh();
      _notify(started ? RequestInspectorNoticeKind.syncStarted : RequestInspectorNoticeKind.syncBusy);
    } on Failure {
      _notify(RequestInspectorNoticeKind.actionFailed);
    }
  }

  Future<void> retryFailed() async {
    try {
      final count = await _repository.retryFailed();
      await refresh();
      _notify(RequestInspectorNoticeKind.requeued, count: count);
    } on Failure {
      _notify(RequestInspectorNoticeKind.actionFailed);
    }
  }

  Future<void> clearLog() async {
    try {
      await _repository.clearLog();
      await refresh();
      _notify(RequestInspectorNoticeKind.cleared);
    } on Failure {
      _notify(RequestInspectorNoticeKind.actionFailed);
    }
  }

  void _notify(RequestInspectorNoticeKind kind, {int count = 0}) {
    if (state case final RequestInspectorLoaded loaded when !isClosed) {
      emit(loaded.withNotice(RequestInspectorNotice(kind, count: count, sequence: ++_sequence)));
    }
  }

  @override
  Future<void> close() async {
    _poll?.cancel();
    await _events?.cancel();
    return super.close();
  }
}
