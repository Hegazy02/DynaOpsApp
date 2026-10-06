/// `ShellCubit`: the brain of the WebView screen (§5, §6). Owns the load state
/// (`ShellState`), decides what each navigation does via `UrlPolicy`, hands
/// external links off, guards the bridge so only the web origin may talk to
/// it, forwards bridge events to the page, retries on reconnect, recreates
/// the WebView after a renderer crash and answers hardware back.
///
/// Why it exists: flutter-cubit-architecture — all shell logic sits here,
/// free of plugin types (it talks to the view through `WebViewPort`), so it
/// is unit-tested without a WebView.
/// Status: used — created per route in `app_router.dart`; tested in
/// `test/features/shell/cubit/shell_cubit_test.dart`. On resume it asks
/// `TrackingCoordinator` to re-check tracking and sends `app.resumed` with the
/// real tracking state and pending count.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bridge/bridge_controller.dart';
import '../../../bridge/bridge_message_model.dart';
import '../../../bridge/bridge_script.dart';
import '../../../core/config/app_config.dart';
import '../../../core/logging/app_logger.dart';
import '../../connectivity/data/connectivity_repository.dart';
import '../../device/data/device_repository.dart';
import '../../permissions/data/permissions_repository.dart';
import '../../tracking/data/tracking_repository.dart';
import '../../tracking/engine/tracking_coordinator.dart';
import '../data/external_link_repository.dart';
import 'shell_state.dart';
import 'url_policy.dart';
import 'web_view_port.dart';

/// Hosts the Angular app: load state, navigation policy, the bridge in and out (§5, §6).
class ShellCubit extends Cubit<ShellState> {
  ShellCubit(
    this._config,
    this._bridge,
    this._connectivity,
    this._permissions,
    this._device,
    this._externalLinks,
    this._tracking,
    this._trackingCoordinator,
    this._logger,
  )   : _policy = UrlPolicy(_config.webOrigin),
        super(const ShellStarting());

  final AppConfig _config;
  final BridgeController _bridge;
  final ConnectivityRepository _connectivity;
  final PermissionsRepository _permissions;
  final DeviceRepository _device;
  final ExternalLinkRepository _externalLinks;
  final TrackingRepository _tracking;
  final TrackingCoordinator _trackingCoordinator;
  final AppLogger _logger;
  final UrlPolicy _policy;

  WebViewPort? _port;
  StreamSubscription<BridgeEvent>? _bridgeEvents;
  StreamSubscription<Object?>? _networkChanges;
  String _bridgeScript = '';
  String _appVersion = 'unknown';

  Uri get initialUrl => _config.webUrl;

  String get webOrigin => _config.webOrigin;

  /// Injected at document start; valid once the state leaves [ShellStarting].
  String get bridgeScript => _bridgeScript;

  /// Appended to the WebView user agent for analytics/diagnostics (§5.2).
  String get userAgentSuffix => 'DynaOpsApp/$_appVersion (Android)';

  Future<void> start() async {
    try {
      _appVersion = (await _device.info()).appVersion;
    } catch (e) {
      _logger.warn('App version unavailable: $e');
    }
    _bridgeScript = buildBridgeScript(appVersion: _appVersion);
    _bridgeEvents = _bridge.events.listen(_sendEvent);
    _networkChanges = _connectivity.changes.listen((status) {
      if (status.online && state is ShellLoadError) retry();
    });
    unawaited(_connectivity.start());
    emit(const ShellLoading(0));
  }

  void attachWebView(WebViewPort port) => _port = port;

  void onPageStarted() {
    if (state is! ShellLoading) emit(ShellLoading(state.webViewGeneration));
  }

  void onProgress(int progress) {
    if (state is ShellLoading) emit(ShellLoading(state.webViewGeneration, progress: progress));
  }

  void onPageFinished() {
    if (state is ShellLoadError) return;
    final firstLoad = state is! ShellReady;
    emit(ShellReady(state.webViewGeneration));
    // The WebView file chooser only offers the camera once CAMERA is granted.
    if (firstLoad) unawaited(_permissions.requestCameraOnce());
  }

  Future<void> onMainFrameError(String description) async {
    _logger.warn('Main frame failed: $description');
    final status = await _connectivity.refresh();
    emit(ShellLoadError(state.webViewGeneration, offline: !status.online));
  }

  void retry() {
    emit(ShellLoading(state.webViewGeneration));
    unawaited(_port?.reload());
  }

  /// Renderer crashed: build a fresh WebView (§5.6).
  void onRenderProcessGone() {
    _logger.warn('WebView renderer gone; recreating');
    _port = null;
    emit(ShellLoading(state.webViewGeneration + 1));
  }

  /// Whether the WebView should load [uri]; external links are handed off here.
  Future<bool> shouldLoad(Uri uri, {required bool isMainFrame}) async {
    switch (_policy.decide(uri, isMainFrame: isMainFrame)) {
      case NavigationDecision.allow:
        return true;
      case NavigationDecision.external:
        await _externalLinks.open(uri);
        return false;
      case NavigationDecision.cancel:
        _logger.info('Cancelled ${uri.scheme}: navigation');
        return false;
    }
  }

  /// `target="_blank"` / `window.open`: same origin stays in this WebView.
  Future<void> onNewWindow(Uri uri) async {
    if (await shouldLoad(uri, isMainFrame: true)) await _port?.load(uri);
  }

  /// `https` downloads go to the browser; `blob:` never reaches here (use `files.*`).
  Future<void> onDownload(Uri uri) async {
    if (uri.scheme == 'https') await _externalLinks.open(uri);
  }

  /// Web geolocation for the app's own origin, once native permission exists (§5.4).
  Future<bool> onGeolocationPrompt(String origin) async {
    final parsed = Uri.tryParse(origin);
    if (!_config.isWebOrigin(parsed)) return false;
    return await _permissions.isLocationGranted() || await _permissions.requestLocation();
  }

  /// A message from `window.DynaOpsNative`; returns the response JSON, or null
  /// when the page is not on the web origin (§16).
  Future<String?> onBridgeMessage(String raw, Uri? pageUrl) async {
    if (!_config.isWebOrigin(pageUrl)) {
      _logger.warn('Bridge message refused from ${pageUrl?.origin}');
      return null;
    }
    return _bridge.handleMessage(raw);
  }

  Future<void> onAppResumed() async {
    final network = await _connectivity.refresh();
    await _permissions.refresh();
    await _trackingCoordinator.onAppResumed();
    final tracking = await _tracking.refreshStatus();
    _sendEvent(BridgeEvent('app.resumed', {
      'online': network.online,
      'trackingState': tracking.state.wire,
      'pendingCount': tracking.pendingUploads,
    }));
  }

  /// Hardware back: true when the WebView went back, false at the Angular root.
  Future<bool> goBack() async {
    final port = _port;
    if (port != null && await port.canGoBack()) {
      await port.goBack();
      return true;
    }
    return false;
  }

  /// Events are dropped while the page is not ready; Angular re-reads `*.status` on ready (§6.2).
  void _sendEvent(BridgeEvent event) {
    final port = _port;
    if (port == null || state is! ShellReady) return;
    unawaited(port.evaluate(deliverEventScript(jsonEncode(event.toJson()))));
  }

  @override
  Future<void> close() async {
    await _bridgeEvents?.cancel();
    await _networkChanges?.cancel();
    return super.close();
  }
}
