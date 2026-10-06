/// `TrackingPolicyModel` / `ShiftWindowModel`: the rep's tracking settings as
/// `GET RepDashboard` returns them (`trackingEnabled`, `trackingMode`,
/// `shiftWindow { workingDays (0 = Sunday), availableHoursPerDay,
/// dailyStartTime 'HH:mm' }`), plus the JSON used for the stored snapshot and
/// `tracking.refreshPolicy`.
///
/// Why it exists: the auto-start rule (D8, §8.1) needs the admin flag and the
/// shift window in both isolates, offline included.
/// Status: used — fetched by `TrackingPolicyRepository`, evaluated by
/// `TrackingPolicy`.
library;

import 'package:equatable/equatable.dart';

class ShiftWindowModel extends Equatable {
  const ShiftWindowModel({
    required this.workingDays,
    required this.availableHoursPerDay,
    required this.startMinutes,
  });

  /// Throws [FormatException] on a bad shape.
  factory ShiftWindowModel.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'workingDays': final List<dynamic> days,
        'availableHoursPerDay': final num hours,
        'dailyStartTime': final String start,
      } =>
        ShiftWindowModel(
          workingDays: days.whereType<num>().map((d) => d.toInt()).toList(),
          availableHoursPerDay: hours.toDouble(),
          startMinutes: _parseHhMm(start),
        ),
      _ => throw const FormatException('Bad shiftWindow'),
    };
  }

  /// Days the shift *starts* on; 0 = Sunday … 6 = Saturday.
  final List<int> workingDays;
  final double availableHoursPerDay;

  /// Minutes after local midnight.
  final int startMinutes;

  Map<String, dynamic> toJson() => {
        'workingDays': workingDays,
        'availableHoursPerDay': availableHoursPerDay,
        'dailyStartTime':
            '${(startMinutes ~/ 60).toString().padLeft(2, '0')}:${(startMinutes % 60).toString().padLeft(2, '0')}',
      };

  static int _parseHhMm(String value) {
    final parts = value.split(':');
    final hours = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final minutes = parts.length > 1 ? int.tryParse(parts[1]) : 0;
    if (hours == null || minutes == null || hours > 23 || minutes > 59) {
      throw FormatException('Bad dailyStartTime "$value"');
    }
    return hours * 60 + minutes;
  }

  @override
  List<Object?> get props => [workingDays, availableHoursPerDay, startMinutes];
}

class TrackingPolicyModel extends Equatable {
  const TrackingPolicyModel({
    required this.enabled,
    required this.mode,
    this.shiftWindow,
  });

  /// What the server assumes for a rep with no settings row: tracked, Route mode.
  static const serverDefault = TrackingPolicyModel(enabled: true, mode: 'Route');

  /// Reads the snapshot written by [toJson], or the tracking fields of a
  /// `RepDashboard` payload (`trackingEnabled` / `trackingMode`).
  factory TrackingPolicyModel.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'] ?? json['trackingEnabled'];
    final mode = json['mode'] ?? json['trackingMode'];
    final window = json['shiftWindow'];
    return TrackingPolicyModel(
      enabled: enabled is bool ? enabled : true,
      mode: mode is String && mode.isNotEmpty ? mode : 'Route',
      shiftWindow: window is Map<String, dynamic> ? ShiftWindowModel.fromJson(window) : null,
    );
  }

  final bool enabled;

  /// `Continuous | Route | Shift`.
  final String mode;

  /// Null outside Shift mode, and in Shift mode with no work calendar.
  final ShiftWindowModel? shiftWindow;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'mode': mode,
        'shiftWindow': shiftWindow?.toJson(),
      };

  @override
  List<Object?> get props => [enabled, mode, shiftWindow];
}
