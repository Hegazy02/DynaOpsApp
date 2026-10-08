/// `PermissionsState`: sealed states of the permission walkthrough —
/// `PermissionsLoading`, `PermissionsStepShown` (current step, its position,
/// whether it is already granted or only fixable in settings, the phone's
/// maker, whether the rep's tracking makes it mandatory), `PermissionsFinished`.
///
/// Why it exists: sealed, value-equal states (flutter-cubit-architecture).
/// Status: used — emitted by `PermissionsCubit`, rendered by
/// `PermissionWalkthroughScreen`.
library;

import 'package:equatable/equatable.dart';

import '../data/oem_brand.dart';

/// Order of the walkthrough (§13).
enum WalkthroughStep {
  location,
  preciseLocation,
  backgroundLocation,
  locationService,
  notifications,
  battery,
  oem,
}

sealed class PermissionsState extends Equatable {
  const PermissionsState();
  @override
  List<Object?> get props => [];
}

final class PermissionsLoading extends PermissionsState {
  const PermissionsLoading();
}

final class PermissionsStepShown extends PermissionsState {
  const PermissionsStepShown({
    required this.step,
    required this.index,
    required this.total,
    required this.needsSettings,
    this.oem,
    this.busy = false,
    this.mandatory = true,
  });

  final WalkthroughStep step;

  /// 1-based.
  final int index;
  final int total;

  /// Only a settings screen can fix it: the permission is permanently denied,
  /// or the step is precise location / the phone's Location switch.
  final bool needsSettings;
  final OemBrand? oem;
  final bool busy;

  /// The rep's tracking is on, so the app may not be used without the step;
  /// false for an untracked rep, whose back button simply closes the screen.
  final bool mandatory;

  PermissionsStepShown copyWith({bool? needsSettings, bool? busy}) => PermissionsStepShown(
        step: step,
        index: index,
        total: total,
        needsSettings: needsSettings ?? this.needsSettings,
        oem: oem,
        busy: busy ?? this.busy,
        mandatory: mandatory,
      );

  @override
  List<Object?> get props => [step, index, total, needsSettings, oem, busy, mandatory];
}

final class PermissionsFinished extends PermissionsState {
  const PermissionsFinished();
}
