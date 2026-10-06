/// App entry point: boots Flutter, opens the channel to the tracking service,
/// builds `AppConfig` from the compile-time
/// `--dart-define-from-file=env/<tenant>.json` values, registers everything
/// in `get_it`, waits for the async singletons (analytics, prefs, database,
/// stored session), starts the tracking coordinator (auto-start, D8) and runs
/// `DynaOpsApp`.
///
/// Why it exists: Flutter needs a `main()`, and the project keeps it free of
/// UI, routing and business logic.
/// Status: used — the entry point of every build. The tracking service has
/// its own entry point, `startTrackingTask`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/di/service_locator.dart';
import 'features/tracking/engine/tracking_coordinator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  await setupServiceLocator(AppConfig.fromEnvironment());
  await getIt.allReady();
  // Not awaited: starting the service may show no UI and must not delay the first frame.
  unawaited(getIt<TrackingCoordinator>().start());
  runApp(const DynaOpsApp());
}
