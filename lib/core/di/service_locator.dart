/// `get_it` registration for the UI isolate: core (config, logger, analytics,
/// prefs, secure store, database, Dio) → repositories → engines (tracking
/// coordinator, local sync manager) → bridge handlers → Cubit factories.
///
/// Why it exists: the single place dependencies are wired
/// (flutter-service-locator-setup); nothing is constructed by hand elsewhere,
/// and Cubits are factories so each route gets a fresh one. The tracking
/// service isolate has its own graph in `task_locator.dart`.
/// Status: used — called by `main.dart` on launch.
library;

import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../bridge/bridge_controller.dart';
import '../../bridge/handlers/app_handler.dart';
import '../../bridge/handlers/auth_handler.dart';
import '../../bridge/handlers/files_handler.dart';
import '../../bridge/handlers/network_handler.dart';
import '../../bridge/handlers/permissions_handler.dart';
import '../../bridge/handlers/sync_handler.dart';
import '../../bridge/handlers/tracking_handler.dart';
import '../../features/auth/data/session_repository.dart';
import '../../features/connectivity/data/connectivity_repository.dart';
import '../../features/device/data/device_repository.dart';
import '../../features/diagnostics/cubit/diagnostics_cubit.dart';
import '../../features/files/data/files_repository.dart';
import '../../features/locale/cubit/locale_cubit.dart';
import '../../features/permissions/cubit/permissions_cubit.dart';
import '../../features/permissions/data/permissions_repository.dart';
import '../../features/shell/cubit/native_navigation_cubit.dart';
import '../../features/shell/cubit/shell_cubit.dart';
import '../../features/shell/data/external_link_repository.dart';
import '../../features/shell/data/native_navigation_repository.dart';
import '../../features/shell/data/web_cache_repository.dart';
import '../../features/sync/data/location_upload_api.dart';
import '../../features/sync/data/location_uploader.dart';
import '../../features/sync/data/sync_meta_dao.dart';
import '../../features/sync/data/sync_repository.dart';
import '../../features/sync/engine/sync_manager.dart';
import '../../features/tracking/cubit/tracking_cubit.dart';
import '../../features/tracking/data/location_points_dao.dart';
import '../../features/tracking/data/location_repository.dart';
import '../../features/tracking/data/location_source.dart';
import '../../features/tracking/data/tracking_api.dart';
import '../../features/tracking/data/tracking_policy_repository.dart';
import '../../features/tracking/data/tracking_repository.dart';
import '../../features/tracking/data/tracking_service_client.dart';
import '../../features/tracking/data/tracking_status_model.dart';
import '../../features/tracking/engine/foreground_task_port.dart';
import '../../features/tracking/engine/tracking_coordinator.dart';
import '../../l10n/generated/app_localizations.dart';
import '../analytics/analytics_client.dart';
import '../config/app_config.dart';
import '../database/app_database.dart';
import '../logging/app_logger.dart';
import '../network/dio_client.dart';
import '../storage/prefs_store.dart';
import '../storage/secure_store.dart';

final getIt = GetIt.instance;

/// UI isolate: core → clients → repositories → engines → bridge → Cubits (factories).
Future<void> setupServiceLocator(AppConfig config) async {
  _registerCore(config);
  _registerAuth();
  _registerConnectivity();
  _registerPermissions();
  _registerDevice();
  _registerFiles();
  _registerTracking(config);
  _registerBridge();
  _registerShell();
  _registerLocale();
  _registerDiagnostics();
}

void _registerCore(AppConfig config) {
  getIt
    ..registerSingleton(config)
    ..registerLazySingleton(AppLogger.new)
    ..registerSingletonAsync<AnalyticsClient>(() async {
      final client = AnalyticsClient(getIt());
      await client.init();
      return client;
    })
    ..registerSingletonAsync<PrefsStore>(() async => PrefsStore(await SharedPreferences.getInstance()))
    ..registerSingletonAsync<AppDatabase>(AppDatabase.open)
    ..registerLazySingleton(() => SecureStore(const FlutterSecureStorage()))
    ..registerLazySingleton<Dio>(() => createDioClient(getIt(), getIt()));
}

void _registerAuth() {
  getIt.registerSingletonAsync<SessionRepository>(
    () async {
      final repository = SessionRepository(getIt(), getIt(), getIt());
      await repository.load();
      return repository;
    },
    dependsOn: [AnalyticsClient],
  );
}

void _registerConnectivity() {
  getIt.registerLazySingleton(() => ConnectivityRepository(Connectivity(), getIt(), getIt()));
}

void _registerPermissions() {
  getIt
    ..registerLazySingleton(() => PermissionsRepository(getIt()))
    ..registerFactory(() => PermissionsCubit(getIt(), getIt(), getIt()));
}

void _registerDevice() {
  getIt.registerLazySingleton(() => DeviceRepository(DeviceInfoPlugin()));
}

void _registerFiles() {
  getIt.registerLazySingleton(FilesRepository.new);
}

void _registerTracking(AppConfig config) {
  AppLocalizations l10nFor(String lang) => lookupAppLocalizations(Locale(lang));
  final deviceL10n = l10nFor(PlatformDispatcher.instance.locale.languageCode == 'ar' ? 'ar' : 'en');

  getIt
    ..registerLazySingleton(() => LocationPointsDao(getIt<AppDatabase>().db))
    ..registerLazySingleton(() => SyncMetaDao(getIt<AppDatabase>().db))
    ..registerLazySingleton<TrackingServiceClient>(
      () => ForegroundTaskServiceClient(
        channelName: deviceL10n.trackingChannelName,
        channelDescription: deviceL10n.trackingChannelDescription,
      ),
    )
    ..registerLazySingleton<LocationSource>(GeolocatorLocationSource.new)
    ..registerLazySingleton(() => LocationRepository(getIt(), getIt()))
    ..registerLazySingleton(() => TrackingPolicyRepository(TrackingApi(getIt()), getIt(), getIt()))
    ..registerLazySingleton<LocationUploader>(
      () => ApiLocationUploader(LocationUploadApi(getIt()), localTimestamps: config.pingTimestampsLocal),
    )
    // Uploads from the UI isolate only while the service is stopped.
    ..registerLazySingleton(
      () => SyncManager(
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        isOnline: () async => (await getIt<ConnectivityRepository>().refresh()).online,
        batchSize: config.uploadBatchSize,
      ),
    )
    ..registerLazySingleton(() => SyncRepository(getIt(), getIt(), getIt(), getIt(), getIt()))
    ..registerLazySingleton(
      () => TrackingRepository(
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        notificationText: (lang) => ForegroundTaskPort.notificationText(
          const TrackingStatusModel(state: TrackingState.starting),
          l10nFor(lang),
        ),
      ),
    )
    ..registerLazySingleton(() => TrackingCoordinator(getIt(), getIt(), getIt(), getIt(), getIt(), getIt()))
    ..registerFactory(() => TrackingCubit(getIt(), getIt(), getIt()));
}

void _registerBridge() {
  getIt.registerLazySingleton(
    () => BridgeController(
      [
        AppHandler(getIt(), getIt(), getIt(), getIt()),
        AuthHandler(getIt(), getIt()),
        PermissionsHandler(getIt()),
        NetworkHandler(getIt()),
        FilesHandler(getIt()),
        TrackingHandler(getIt(), getIt(), getIt(), getIt(), getIt()),
        SyncHandler(getIt()),
      ],
      getIt(),
    ),
  );
}

void _registerShell() {
  getIt
    ..registerLazySingleton(() => ExternalLinkRepository(getIt()))
    ..registerLazySingleton(NativeNavigationRepository.new)
    ..registerLazySingleton(WebCacheRepository.new)
    ..registerFactory(
      () => ShellCubit(getIt(), getIt(), getIt(), getIt(), getIt(), getIt(), getIt(), getIt(), getIt()),
    )
    ..registerFactory(() => NativeNavigationCubit(getIt()));
}

void _registerLocale() {
  getIt.registerFactory(() => LocaleCubit(getIt()));
}

void _registerDiagnostics() {
  getIt.registerFactory(
    () => DiagnosticsCubit(getIt(), getIt(), getIt(), getIt(), getIt(), getIt(), getIt()),
  );
}
