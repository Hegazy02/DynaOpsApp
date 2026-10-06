/// `AnalyticsClient`: thin wrapper over `posthog_flutter` (D15) — setup with
/// the tenant's key/host, `identify`/`reset` on session changes, `capture`
/// and `captureException` for shell events. A tenant without a key gets a
/// silent no-op client.
///
/// Why it exists: analytics stay behind one class so no feature imports
/// PostHog directly and the token can never leak into an event.
/// Status: used — registered in `service_locator.dart`; `identify`/`reset`
/// are called by `SessionRepository`. `capture`/`captureException` have no
/// callers yet: the M2 shell events (`tracking_started`,
/// `sync_batch_uploaded`, …) will be the first.
library;

import 'package:posthog_flutter/posthog_flutter.dart';

import '../config/app_config.dart';

/// PostHog wrapper (D15). Same project as the web app; never receives the token.
/// A tenant without a key gets a silent no-op client.
class AnalyticsClient {
  AnalyticsClient(this._config);
  final AppConfig _config;
  bool _enabled = false;

  Future<void> init() async {
    if (_config.posthogKey.isEmpty) return;
    final config = PostHogConfig(_config.posthogKey);
    if (_config.posthogHost.isNotEmpty) config.host = _config.posthogHost;
    config.errorTrackingConfig
      ..captureFlutterErrors = true
      ..capturePlatformDispatcherErrors = true
      ..captureIsolateErrors = true;
    await Posthog().setup(config);
    await Posthog().register('app', 'dynaopsapp');
    await Posthog().register('tenant', _config.tenant);
    _enabled = true;
  }

  Future<void> identify(String userId) async {
    if (_enabled) await Posthog().identify(userId: userId);
  }

  Future<void> reset() async {
    if (_enabled) await Posthog().reset();
  }

  Future<void> capture(String event, [Map<String, Object>? properties]) async {
    if (_enabled) await Posthog().capture(eventName: event, properties: properties);
  }

  Future<void> captureException(Object error, StackTrace? stackTrace) async {
    if (_enabled) await Posthog().captureException(error: error, stackTrace: stackTrace);
  }
}
