/// `AppConfig`: the per-tenant settings read once from compile-time defines
/// (`WEB_URL`, `API_BASE_URL`, `TENANT`, `POSTHOG_KEY`, `POSTHOG_HOST`, and the
/// tracking knobs `PING_TIMESTAMPS`, `TRACKING_INTERVAL_SECONDS`,
/// `UPLOAD_BATCH_SIZE`), plus the bridge protocol version and the web-origin
/// check the bridge trusts.
///
/// Why it exists: D9 — one APK per tenant with nothing tenant-specific
/// hard-coded; every layer reads this object instead of raw environment values.
/// Defines are compile-time constants, so the tracking-service isolate builds
/// the same object.
/// Status: used — built in `main.dart` and in the tracking service, registered
/// as a singleton in both locators. `WebSource.bundled` is declared but not
/// implemented (M4, offline web assets).
library;

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
    this.trackingInterval = const Duration(seconds: 5),
    this.uploadBatchSize = 100,
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
      trackingInterval: const Duration(
        seconds: int.fromEnvironment('TRACKING_INTERVAL_SECONDS', defaultValue: 5),
      ),
      uploadBatchSize: const int.fromEnvironment('UPLOAD_BATCH_SIZE', defaultValue: 100),
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

  /// How often the GPS is asked for a fix (§8.2: ~5 s).
  final Duration trackingInterval;

  /// Fixes per upload request (§11).
  final int uploadBatchSize;

  /// `scheme://host[:port]` of the web app — the only origin the bridge trusts.
  String get webOrigin => webUrl.origin;

  bool isWebOrigin(Uri? uri) =>
      uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.origin == webOrigin;
}
