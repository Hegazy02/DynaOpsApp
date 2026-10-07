/// `TrackingPort` (what the engine needs from its host) and
/// `ForegroundTaskPort` (the `flutter_foreground_task` implementation):
/// publish status / fixes / sync events / logs to the UI isolate, update the
/// persistent notification in the rep's language, and stop the service.
///
/// Why it exists: keeps `TrackingEngine` free of the plugin's static API so
/// the engine is unit-testable with a fake port.
/// Status: used — created by `TrackingTaskHandler` in the service isolate.
library;

import 'dart:ui';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/location_fix_model.dart';
import '../data/tracking_status_model.dart';
import 'task_protocol.dart';

abstract interface class TrackingPort {
  void publishStatus(TrackingStatusModel status);

  void publishLocation(LocationFixModel fix);

  void publishSync(String event, Map<String, Object?> data);

  void publishFlushed(String requestId, int processed);

  void publishLog(String line);

  Future<void> updateNotification(TrackingStatusModel status, {required String lang});

  Future<void> stopService();
}

class ForegroundTaskPort implements TrackingPort {
  @override
  void publishStatus(TrackingStatusModel status) =>
      FlutterForegroundTask.sendDataToMain({TaskMessage.key: TaskMessage.status, 'status': status.toJson()});

  @override
  void publishLocation(LocationFixModel fix) =>
      FlutterForegroundTask.sendDataToMain({TaskMessage.key: TaskMessage.location, 'fix': fix.toMessage()});

  @override
  void publishSync(String event, Map<String, Object?> data) =>
      FlutterForegroundTask.sendDataToMain({TaskMessage.key: TaskMessage.sync, 'event': event, 'data': data});

  @override
  void publishFlushed(String requestId, int processed) => FlutterForegroundTask.sendDataToMain(
        {TaskMessage.key: TaskMessage.flushed, 'requestId': requestId, 'processed': processed},
      );

  @override
  void publishLog(String line) =>
      FlutterForegroundTask.sendDataToMain({TaskMessage.key: TaskMessage.log, 'line': line});

  @override
  Future<void> updateNotification(TrackingStatusModel status, {required String lang}) async {
    final (title, text) = notificationText(status, lookupAppLocalizations(Locale(lang)));
    await FlutterForegroundTask.updateService(notificationTitle: title, notificationText: text);
  }

  @override
  Future<void> stopService() async {
    await FlutterForegroundTask.stopService();
  }

  /// Title and text for [status] (shared with the UI's first notification).
  static (String, String) notificationText(TrackingStatusModel status, AppLocalizations l10n) {
    final text = switch (status) {
      TrackingStatusModel(errorCode: TrackingErrorCode.locationDisabled) => l10n.trackingNotificationLocationOff,
      TrackingStatusModel(state: TrackingState.permissionRequired || TrackingState.permissionDenied) =>
        l10n.trackingNotificationPermission,
      TrackingStatusModel(reason: TrackingReason.outsideShift) => l10n.trackingNotificationOutsideShift,
      TrackingStatusModel(state: TrackingState.stopped) => l10n.trackingNotificationPaused,
      _ => l10n.trackingNotificationRunning,
    };
    return (l10n.trackingNotificationTitle, text);
  }
}
