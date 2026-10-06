/// `TrackingStatusModel`: the shell's tracking state machine snapshot (§8.2) —
/// state, why it is in that state, error code, permissions, admin flag, last
/// fix and upload numbers — with the `tracking.status` JSON and an isolate
/// message form.
///
/// Why it exists: one value the service publishes and the UI isolate, bridge,
/// notification and native screens all read.
/// Status: used — built by `TrackingEngine` / `TrackingRepository`, sent as
/// `tracking.status` and `tracking.statusChanged`.
library;

import 'package:equatable/equatable.dart';

enum TrackingState {
  stopped('stopped'),
  starting('starting'),
  running('running'),
  stopping('stopping'),
  permissionRequired('permission_required'),
  permissionDenied('permission_denied'),
  error('error');

  const TrackingState(this.wire);
  final String wire;

  static TrackingState fromWire(Object? value) =>
      values.firstWhere((s) => s.wire == value, orElse: () => TrackingState.stopped);
}

/// Why tracking is not (fully) running.
abstract final class TrackingReason {
  static const signedOut = 'signedOut';
  static const disabledByAdmin = 'disabledByAdmin';
  static const outsideShift = 'outsideShift';

  /// Still collecting; uploads paused until the rep signs in again (D6).
  static const sessionExpired = 'sessionExpired';
}

abstract final class TrackingErrorCode {
  static const locationDisabled = 'LOCATION_DISABLED';
  static const locationUnavailable = 'LOCATION_UNAVAILABLE';
  static const forceStoppedPreviously = 'FORCE_STOPPED_PREVIOUSLY';
  static const serviceStartFailed = 'SERVICE_START_FAILED';
}

class TrackingStatusModel extends Equatable {
  const TrackingStatusModel({
    required this.state,
    this.reason,
    this.errorCode,
    this.backgroundService = false,
    this.locationPermission = 'notDetermined',
    this.backgroundPermission = 'notDetermined',
    this.enabled = true,
    this.lastLocationAt,
    this.pendingUploads = 0,
    this.lastUploadAt,
  });

  factory TrackingStatusModel.fromMessage(Map<Object?, Object?> m) => TrackingStatusModel(
        state: TrackingState.fromWire(m['state']),
        reason: m['reason'] as String?,
        errorCode: m['errorCode'] as String?,
        backgroundService: m['backgroundService'] == true,
        locationPermission: m['locationPermission'] as String? ?? 'notDetermined',
        backgroundPermission: m['backgroundPermission'] as String? ?? 'notDetermined',
        enabled: m['enabled'] != false,
        lastLocationAt: _date(m['lastLocationTimestamp']),
        pendingUploads: m['pendingUploads'] as int? ?? 0,
        lastUploadAt: _date(m['lastUploadAt']),
      );

  final TrackingState state;
  final String? reason;
  final String? errorCode;

  /// The foreground service is running.
  final bool backgroundService;
  final String locationPermission;
  final String backgroundPermission;

  /// Admin flag `trackingEnabled`.
  final bool enabled;
  final DateTime? lastLocationAt;
  final int pendingUploads;
  final DateTime? lastUploadAt;

  TrackingStatusModel copyWith({
    TrackingState? state,
    String? Function()? reason,
    String? Function()? errorCode,
    bool? backgroundService,
    String? locationPermission,
    String? backgroundPermission,
    bool? enabled,
    DateTime? lastLocationAt,
    int? pendingUploads,
    DateTime? lastUploadAt,
  }) =>
      TrackingStatusModel(
        state: state ?? this.state,
        reason: reason != null ? reason() : this.reason,
        errorCode: errorCode != null ? errorCode() : this.errorCode,
        backgroundService: backgroundService ?? this.backgroundService,
        locationPermission: locationPermission ?? this.locationPermission,
        backgroundPermission: backgroundPermission ?? this.backgroundPermission,
        enabled: enabled ?? this.enabled,
        lastLocationAt: lastLocationAt ?? this.lastLocationAt,
        pendingUploads: pendingUploads ?? this.pendingUploads,
        lastUploadAt: lastUploadAt ?? this.lastUploadAt,
      );

  /// `tracking.status` / `tracking.statusChanged` data (§6.4). Also the isolate message.
  Map<String, Object?> toJson() => {
        'state': state.wire,
        'reason': reason,
        'errorCode': errorCode,
        'backgroundService': backgroundService,
        'locationPermission': locationPermission,
        'backgroundPermission': backgroundPermission,
        'enabled': enabled,
        'lastLocationTimestamp': lastLocationAt?.toUtc().toIso8601String(),
        'pendingUploads': pendingUploads,
        'lastUploadAt': lastUploadAt?.toUtc().toIso8601String(),
      };

  static DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;

  @override
  List<Object?> get props => [
        state,
        reason,
        errorCode,
        backgroundService,
        locationPermission,
        backgroundPermission,
        enabled,
        lastLocationAt,
        pendingUploads,
        lastUploadAt,
      ];
}
