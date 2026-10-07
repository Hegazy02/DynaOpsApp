/// `AppConfig`: the per-tenant settings read once from compile-time defines
/// (`WEB_URL`, `API_BASE_URL`, `TENANT`, `POSTHOG_KEY`, `POSTHOG_HOST`, and the
/// tracking knobs `PING_TIMESTAMPS`, `GPS_SAMPLE_SECONDS`, `HEARTBEAT_SECONDS`,
/// `DISTANCE_FILTER_M`, `UPLOAD_BATCH_SIZE`) and `REQUEST_INSPECTOR`, plus the
/// bridge protocol version and the web-origin check the bridge trusts.
///
/// Why it exists: D9 — one APK per tenant with nothing tenant-specific
/// hard-coded; every layer reads this object instead of raw environment values.
/// Defines are compile-time constants, so the tracking-service isolate builds
/// the same object.
/// Status: used — built in `main.dart` and in the tracking service, registered
/// as a singleton in both locators. `WebSource.bundled` is declared but not
/// implemented (M4, offline web assets).
library;

import 'package:flutter/foundation.dart';

/// Where the Angular app is served from (§10.1). Only [remote] is implemented.
enum WebSource { remote, bundled }

/// Per-tenant configuration, read from `--dart-define-from-file=env/<tenant>.json` (D9).
class AppConfig {
  AppConfig({
    required this.webUrl,
    required this.apiBaseUrl,
    required this.tenant,
    this.posthogKey = '',
    this.posthogHost = '',
    this.webSource = WebSource.remote,
    this.pingTimestampsLocal = true,
    this.gpsSampleInterval = const Duration(seconds: 1),
    this.heartbeatInterval = const Duration(seconds: 30),
    this.distanceFilterMeters = 0,
    this.uploadBatchSize = 100,
    this.requestInspector = false,
  });

  factory AppConfig.fromEnvironment() {
    const webUrl = String.fromEnvironment('WEB_URL');
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (webUrl.isEmpty || apiBaseUrl.isEmpty) {
      throw StateError(
        'WEB_URL / API_BASE_URL missing: run with --dart-define-from-file=env/<tenant>.json',
      );
    }
    return AppConfig(
      webUrl: Uri.parse(webUrl),
      apiBaseUrl: Uri.parse(apiBaseUrl),
      tenant: const String.fromEnvironment('TENANT', defaultValue: 'default'),
      posthogKey: const String.fromEnvironment('POSTHOG_KEY'),
      posthogHost: const String.fromEnvironment('POSTHOG_HOST'),
      pingTimestampsLocal:
          const String.fromEnvironment('PING_TIMESTAMPS', defaultValue: 'local').toLowerCase() != 'utc',
      gpsSampleInterval: const Duration(seconds: int.fromEnvironment('GPS_SAMPLE_SECONDS', defaultValue: 1)),
      heartbeatInterval: const Duration(seconds: int.fromEnvironment('HEARTBEAT_SECONDS', defaultValue: 30)),
      distanceFilterMeters: const int.fromEnvironment('DISTANCE_FILTER_M', defaultValue: 0),
      uploadBatchSize: const int.fromEnvironment('UPLOAD_BATCH_SIZE', defaultValue: 100),
      requestInspector: const bool.fromEnvironment('REQUEST_INSPECTOR', defaultValue: kDebugMode),
    );
  }

  /// Bridge protocol version spoken by this build (§6).
  static const bridgeVersion = '1.0';

  final Uri webUrl;

  /// Ends with `/api/`, like Angular's `environment.apiUrl`; paths are relative.
  final Uri apiBaseUrl;
  final String tenant;
  final String posthogKey;
  final String posthogHost;
  final WebSource webSource;

  /// `LocationPings/batch` takes naive timestamps; the convention with the API
  /// (shared with the old tracker) is the device's local clock. `utc` flips it.
  final bool pingTimestampsLocal;

  /// How often the GPS is asked for a sample (`GPS_SAMPLE_SECONDS`, 1 s) —
  /// not how often a ping is recorded. Continuous sampling keeps the GNSS
  /// engine's Doppler (speed) solution alive; at 5 s Android duty-cycles the
  /// receiver and fixes arrive without speed. Costs some battery.
  final Duration gpsSampleInterval;

  /// Heartbeat (`HEARTBEAT_SECONDS`, 30 s): a ping even when still, and the
  /// service tick that uploads, checks the watchdog, policy and shift.
  final Duration heartbeatInterval;

  /// Movement (`DISTANCE_FILTER_M`) that records an extra ping between
  /// heartbeats, like the old tracker's 25 m. 0 (default) = heartbeat pings
  /// only: one point per `HEARTBEAT_SECONDS`.
  final int distanceFilterMeters;

  /// Fixes per upload request (§11).
  final int uploadBatchSize;

  /// Records API exchanges and shows the floating request-inspector button.
  /// `REQUEST_INSPECTOR`, on by default in debug builds only (payloads carry
  /// location history).
  final bool requestInspector;

  /// `scheme://host[:port]` of the web app — the only origin the bridge trusts.
  String get webOrigin => webUrl.origin;

  bool isWebOrigin(Uri? uri) =>
      uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.origin == webOrigin;
}
