/// `startTrackingTask` (the service's entry point) and `TrackingTaskHandler`:
/// the `flutter_foreground_task` `TaskHandler` that builds the service
/// isolate's own locator and forwards start / tick / commands / destroy to
/// `TrackingEngine`. Tapping the notification opens the app.
///
/// Why it exists: the plugin starts this isolate itself (also after a reboot,
/// with no UI), so it must bootstrap everything from scratch.
/// Status: used — `startTrackingTask` is passed to `startService` by
/// `ForegroundTaskServiceClient`.
library;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/task_locator.dart';
import 'tracking_engine.dart';

@pragma('vm:entry-point')
void startTrackingTask() {
  FlutterForegroundTask.setTaskHandler(TrackingTaskHandler());
}

class TrackingTaskHandler extends TaskHandler {
  TrackingEngine? _engine;
  final _pending = <Object>[];

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final engine = await setupTaskLocator(AppConfig.fromEnvironment());
    await engine.start();
    _engine = engine;
    for (final command in _pending) {
      await engine.handleCommand(command);
    }
    _pending.clear();
  }

  @override
  void onRepeatEvent(DateTime timestamp) => _engine?.tick();

  @override
  void onReceiveData(Object data) {
    final engine = _engine;
    if (engine == null) {
      _pending.add(data); // Commands sent while the engine was still starting.
    } else {
      engine.handleCommand(data);
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _engine?.stop();
    await disposeTaskLocator();
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();
}
