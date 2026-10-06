/// `DiagnosticsState`: sealed states of the diagnostics screen —
/// `DiagnosticsLoading` and `DiagnosticsLoaded` (a snapshot of tracking,
/// sync, policy, device and log, plus a one-off `notice` from the last
/// action), with the `DiagnosticsNotice` kinds the screen shows as snackbars.
///
/// Why it exists: sealed, value-equal states (flutter-cubit-architecture).
/// Status: used — emitted by `DiagnosticsCubit`, rendered by
/// `DiagnosticsScreen`.
library;

import 'package:equatable/equatable.dart';

import '../../device/data/device_info_model.dart';
import '../../sync/data/sync_status_model.dart';
import '../../tracking/data/tracking_policy_model.dart';
import '../../tracking/data/tracking_status_model.dart';

enum DiagnosticsNoticeKind { syncStarted, requeued, cacheCleared, actionFailed }

class DiagnosticsNotice extends Equatable {
  const DiagnosticsNotice(this.kind, {this.count = 0, required this.sequence});
  final DiagnosticsNoticeKind kind;
  final int count;

  /// Makes two identical notices in a row still distinct states.
  final int sequence;

  @override
  List<Object?> get props => [kind, count, sequence];
}

sealed class DiagnosticsState extends Equatable {
  const DiagnosticsState();
  @override
  List<Object?> get props => [];
}

final class DiagnosticsLoading extends DiagnosticsState {
  const DiagnosticsLoading();
}

final class DiagnosticsLoaded extends DiagnosticsState {
  const DiagnosticsLoaded({
    required this.tracking,
    required this.sync,
    required this.policy,
    required this.device,
    required this.log,
    this.notice,
  });

  final TrackingStatusModel tracking;
  final SyncStatusModel sync;
  final TrackingPolicyModel policy;
  final DeviceInfoModel? device;

  /// Newest first.
  final List<String> log;
  final DiagnosticsNotice? notice;

  DiagnosticsLoaded withNotice(DiagnosticsNotice notice) => DiagnosticsLoaded(
        tracking: tracking,
        sync: sync,
        policy: policy,
        device: device,
        log: log,
        notice: notice,
      );

  @override
  List<Object?> get props => [tracking, sync, policy, device, log, notice];
}
