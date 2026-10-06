/// `PermissionsState`: sealed states of the permission walkthrough —
/// `PermissionsLoading`, `PermissionsStepShown` (current step, its position,
/// whether it is already granted or only fixable in settings, the phone's
/// maker), `PermissionsFinished`.
///
/// Why it exists: sealed, value-equal states (flutter-cubit-architecture).
/// Status: used — emitted by `PermissionsCubit`, rendered by
/// `PermissionWalkthroughScreen`.
library;

import 'package:equatable/equatable.dart';

import '../data/oem_brand.dart';

/// Order of the walkthrough (§13).
enum WalkthroughStep { location, backgroundLocation, notifications, battery, oem }

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
  });

  final WalkthroughStep step;

  /// 1-based.
  final int index;
  final int total;

  /// The permission is permanently denied: only the settings screen can fix it.
  final bool needsSettings;
  final OemBrand? oem;
  final bool busy;

  PermissionsStepShown copyWith({bool? needsSettings, bool? busy}) => PermissionsStepShown(
        step: step,
        index: index,
        total: total,
        needsSettings: needsSettings ?? this.needsSettings,
        oem: oem,
        busy: busy ?? this.busy,
      );

  @override
  List<Object?> get props => [step, index, total, needsSettings, oem, busy];
}

final class PermissionsFinished extends PermissionsState {
  const PermissionsFinished();
}
