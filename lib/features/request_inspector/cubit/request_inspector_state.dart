/// `RequestInspectorState`: sealed states of the request inspector —
/// `RequestInspectorLoading`, `RequestInspectorLoaded` (recorded requests,
/// upload queue, sync numbers, plus a one-off `notice`) and
/// `RequestInspectorError`.
///
/// Why it exists: sealed, value-equal states (flutter-cubit-architecture).
/// Status: used — emitted by `RequestInspectorCubit`, rendered by
/// `RequestInspectorScreen`.
library;

import 'package:equatable/equatable.dart';

import '../../sync/data/sync_status_model.dart';
import '../../tracking/data/queued_fix_model.dart';
import '../data/request_log_entry_model.dart';

enum RequestInspectorNoticeKind { syncStarted, syncBusy, requeued, cleared, actionFailed }

class RequestInspectorNotice extends Equatable {
  const RequestInspectorNotice(this.kind, {this.count = 0, required this.sequence});
  final RequestInspectorNoticeKind kind;
  final int count;

  /// Makes two identical notices in a row still distinct states.
  final int sequence;

  @override
  List<Object?> get props => [kind, count, sequence];
}

sealed class RequestInspectorState extends Equatable {
  const RequestInspectorState();
  @override
  List<Object?> get props => [];
}

final class RequestInspectorLoading extends RequestInspectorState {
  const RequestInspectorLoading();
}

final class RequestInspectorLoaded extends RequestInspectorState {
  const RequestInspectorLoaded({
    required this.requests,
    required this.queue,
    required this.sync,
    required this.localTimestamps,
    this.notice,
  });

  /// Newest first.
  final List<RequestLogEntryModel> requests;

  /// Oldest first — the order they will be uploaded in.
  final List<QueuedFixModel> queue;
  final SyncStatusModel sync;

  /// Passed to `toWirePing` to preview a queued fix's payload exactly as sent.
  final bool localTimestamps;
  final RequestInspectorNotice? notice;

  RequestInspectorLoaded withNotice(RequestInspectorNotice notice) => RequestInspectorLoaded(
        requests: requests,
        queue: queue,
        sync: sync,
        localTimestamps: localTimestamps,
        notice: notice,
      );

  @override
  List<Object?> get props => [requests, queue, sync, localTimestamps, notice];
}

final class RequestInspectorError extends RequestInspectorState {
  const RequestInspectorError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
