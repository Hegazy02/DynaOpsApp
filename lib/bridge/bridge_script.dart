/// The JavaScript injected into the page at document start (§6.1):
/// `buildBridgeScript` defines `window.DynaOpsNative` (postMessage,
/// listeners, ready flag, queue) before Angular boots, and
/// `deliverEventScript` wraps an event envelope for delivery to the page.
///
/// Why it exists: Angular's `isNativeShell()` and `NativeBridgeService` rely
/// on this exact object shape; keeping it in Dart lets the app version be
/// baked in.
/// Status: used — `ShellCubit` builds it at start and `ShellWebView` injects
/// it; `test/bridge/bridge_script_test.dart` pins the contract.
library;

import 'dart:convert';

/// Name of the `flutter_inappwebview` JavaScript handler the script posts to.
const bridgeHandlerName = 'dynaops';

/// The script injected at document start on the web origin (§6.1).
///
/// Defines `window.DynaOpsNative` before Angular bootstraps. `ready` turns true
/// — and `dynaops-native-ready` fires — once the plugin's channel is usable;
/// requests posted earlier are queued. Responses come back as the handler's
/// return value; events arrive through `_receive`.
String buildBridgeScript({required String appVersion}) => '''
(function () {
  if (window.DynaOpsNative) return;
  var listeners = [];
  var queue = [];

  function deliver(json) {
    listeners.slice().forEach(function (fn) {
      try { fn(json); } catch (e) { console.error('DynaOpsNative listener failed', e); }
    });
  }

  function send(json) {
    window.flutter_inappwebview.callHandler('$bridgeHandlerName', json).then(function (response) {
      if (typeof response === 'string') deliver(response);
    }, function (e) { console.error('DynaOpsNative post failed', e); });
  }

  var api = {
    version: '1.0',
    platform: 'android',
    appVersion: ${jsonEncode(appVersion)},
    ready: false,
    postMessage: function (json) {
      if (typeof json !== 'string') json = JSON.stringify(json);
      if (api.ready) send(json); else queue.push(json);
    },
    addListener: function (fn) {
      if (typeof fn === 'function' && listeners.indexOf(fn) < 0) listeners.push(fn);
    },
    removeListener: function (fn) {
      var i = listeners.indexOf(fn);
      if (i >= 0) listeners.splice(i, 1);
    },
    _receive: deliver
  };
  Object.defineProperty(window, 'DynaOpsNative', { value: api, writable: false, configurable: false });

  function markReady() {
    if (api.ready) return;
    api.ready = true;
    queue.splice(0).forEach(send);
    window.dispatchEvent(new Event('dynaops-native-ready'));
  }

  if (window.flutter_inappwebview && window.flutter_inappwebview._platformReady) markReady();
  else window.addEventListener('flutterInAppWebViewPlatformReady', markReady);
})();
''';

/// JavaScript that delivers [json] (an event envelope) to the page's listeners.
String deliverEventScript(String json) =>
    'window.DynaOpsNative && window.DynaOpsNative._receive(${jsonEncode(json)});';
