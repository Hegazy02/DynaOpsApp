/// `TrackingViewState`: sealed states of `TrackingCubit` — `TrackingViewInitial`
/// before the first status, `TrackingViewReady` with the status and whether
/// the permission walkthrough should open now.
///
/// Why it exists: sealed, value-equal states (flutter-cubit-architecture).
/// Status: used — emitted by `TrackingCubit`, read by `ShellScreen`.
library;

import 'package:equatable/equatable.dart';

import '../data/tracking_status_model.dart';

sealed class TrackingViewState extends Equatable {
  const TrackingViewState();
  @override
  List<Object?> get props => [];
}

final class TrackingViewInitial extends TrackingViewState {
  const TrackingViewInitial();
}

final class TrackingViewReady extends TrackingViewState {
  const TrackingViewReady(this.status, {required this.promptWalkthrough});
  final TrackingStatusModel status;
  final bool promptWalkthrough;

  @override
  List<Object?> get props => [status, promptWalkthrough];
}
