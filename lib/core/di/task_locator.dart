/// `setupTaskLocator()`: wiring for the tracking-service isolate — config,
/// logger (lines forwarded to the UI), secure session, prefs, database + DAOs,
/// Dio, connectivity, permissions, location source, policy, uploader,
/// `SyncManager` and `TrackingEngine`. No Cubits, no analytics. Returns the
/// engine. `disposeTaskLocator()` closes the database on destroy.
///
/// Why it exists: the service isolate has its own `get_it` instance and starts
/// without the UI (also after a reboot), so it builds its graph itself
/// (flutter-service-locator-setup; §3 "setupTaskLocator").
/// Status: used — called by `TrackingTaskHandler.onStart`.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/session_repository.dart';
import '../../features/connectivity/data/connectivity_repository.dart';
import '../../features/permissions/data/permissions_repository.dart';
import '../../features/request_inspector/data/request_log_dao.dart';
import '../../features/sync/data/location_upload_api.dart';
import '../../features/sync/data/location_uploader.dart';
import '../../features/sync/data/sync_meta_dao.dart';
import '../../features/sync/engine/sync_manager.dart';
import '../../features/tracking/data/location_points_dao.dart';
import '../../features/tracking/data/location_repository.dart';
import '../../features/tracking/data/location_source.dart';
import '../../features/tracking/data/tracking_api.dart';
import '../../features/tracking/data/tracking_policy_repository.dart';
import '../../features/tracking/engine/foreground_task_port.dart';
import '../../features/tracking/engine/tracking_engine.dart';
import '../analytics/analytics_client.dart';
import '../config/app_config.dart';
import '../database/app_database.dart';
import '../logging/app_logger.dart';
import '../network/dio_client.dart';
import '../storage/prefs_store.dart';
import '../storage/secure_store.dart';

final _taskGetIt = GetIt.asNewInstance();

Future<TrackingEngine> setupTaskLocator(AppConfig config) async {
  final g = _taskGetIt;
  await g.reset();
  final port = ForegroundTaskPort();
  final logger = AppLogger(onLine: port.publishLog);
  final database = await AppDatabase.open();

  g
    ..registerSingleton(config)
    ..registerSingleton(logger)
    ..registerSingleton<TrackingPort>(port)
    ..registerSingleton(database)
    ..registerSingleton(LocationPointsDao(database.db))
    ..registerSingleton(SyncMetaDao(database.db))
    ..registerSingleton(PrefsStore(await SharedPreferences.getInstance()))
    // Analytics stays in the UI isolate: the client is never initialised here.
    ..registerSingleton(SessionRepository(SecureStore(const FlutterSecureStorage()), AnalyticsClient(config), logger))
    ..registerLazySingleton<Dio>(
      () => createDioClient(
        g(),
        g(),
        requestLog: config.requestInspector ? RequestLogDao(database.db) : null,
        source: 'service',
      ),
    )
    ..registerLazySingleton(() => ConnectivityRepository(Connectivity(), g(), g()))
    ..registerLazySingleton(() => PermissionsRepository(g(), g()))
    ..registerLazySingleton<LocationSource>(GeolocatorLocationSource.new)
    ..registerLazySingleton(() => LocationRepository(g(), g()))
    ..registerLazySingleton(() => TrackingPolicyRepository(TrackingApi(g()), g(), g()))
    ..registerLazySingleton<LocationUploader>(
      () => ApiLocationUploader(LocationUploadApi(g()), localTimestamps: config.pingTimestampsLocal),
    )
    ..registerLazySingleton(
      () => SyncManager(
        g(),
        g(),
        g(),
        g(),
        g(),
        isOnline: () async => (await g<ConnectivityRepository>().refresh()).online,
        batchSize: config.uploadBatchSize,
      ),
    )
    ..registerLazySingleton(
      () => TrackingEngine(
        config: g(),
        session: g(),
        policies: g(),
        source: g(),
        locations: g(),
        points: g(),
        sync: g(),
        meta: g(),
        connectivity: g(),
        permissions: g(),
        port: g(),
        logger: g(),
      ),
    );
  return g<TrackingEngine>();
}

Future<void> disposeTaskLocator() async {
  if (_taskGetIt.isRegistered<AppDatabase>()) await _taskGetIt<AppDatabase>().close();
  await _taskGetIt.reset();
}
