/// `TrackingServiceClient` (interface) and `ForegroundTaskServiceClient`: the
/// UI isolate's handle on the `flutter_foreground_task` service — configure,
/// start (location type, `stopWithTask=false`, restart on boot/update), stop,
/// send commands, receive messages.
///
/// Why it exists: the plugin is a static API; wrapping it keeps
/// `TrackingRepository` testable and is the only UI-side file that knows the
/// plugin exists (§8.2).
/// Status: used — registered in `service_locator.dart`, used by
/// `TrackingRepository` and `SyncRepository`.
library;

import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../core/network/failure.dart';
import '../engine/tracking_task_handler.dart';

abstract interface class TrackingServiceClient {
  Future<bool> isRunning();

  /// Throws [PlatformFailure] when Android refuses to start the service.
  Future<void> start({required String title, required String text});

  Future<void> stop();

  void send(Map<String, Object?> command);

  /// Every message the service sends (`TaskMessage`).
  Stream<Map<Object?, Object?>> get messages;
}

class ForegroundTaskServiceClient implements TrackingServiceClient {
  ForegroundTaskServiceClient({
    required String channelName,
    required String channelDescription,
    required Duration tickInterval,
  }) {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'dynaops_tracking',
        channelName: channelName,
        channelDescription: channelDescription,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        // The engine's heartbeat tick: heartbeat ping, upload, watchdog, policy, shift edges.
        eventAction: ForegroundTaskEventAction.repeat(tickInterval.inMilliseconds),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        stopWithTask: false,
      ),
    );
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  static const _serviceId = 4711;

  final _messages = StreamController<Map<Object?, Object?>>.broadcast();

  void _onData(Object data) {
    if (data is Map) _messages.add(data);
  }

  @override
  Stream<Map<Object?, Object?>> get messages => _messages.stream;

  @override
  Future<bool> isRunning() => FlutterForegroundTask.isRunningService;

  @override
  Future<void> start({required String title, required String text}) async {
    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: title,
      notificationText: text,
      callback: startTrackingTask,
    );
    if (result case ServiceRequestFailure(:final error)) {
      throw PlatformFailure('Tracking service did not start: $error');
    }
  }

  @override
  Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }

  @override
  void send(Map<String, Object?> command) => FlutterForegroundTask.sendDataToTask(command);
}
