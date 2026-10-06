/// Tests pinning the `window.DynaOpsNative` contract Angular relies on
/// (members, ready event, handler name) and the JSON escaping of the injected
/// app version and of delivered events.
///
/// Status: active — part of `flutter test`.
library;

import 'package:dynaopsapp/bridge/bridge_script.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('script defines the contract Angular relies on', () {
    final script = buildBridgeScript(appVersion: '1.0.0+1');
    for (final part in [
      "'DynaOpsNative'",
      "version: '1.0'",
      "platform: 'android'",
      'appVersion: "1.0.0+1"',
      'postMessage',
      'addListener',
      'removeListener',
      '_receive',
      "new Event('dynaops-native-ready')",
      "callHandler('$bridgeHandlerName'",
      '_platformReady',
    ]) {
      expect(script, contains(part), reason: part);
    }
  });

  test('app version is JSON-escaped into the script', () {
    expect(buildBridgeScript(appVersion: "1'\";x").contains('"1\'\\";x"'), true);
  });

  test('event delivery quotes the payload as a JS string literal', () {
    expect(
      deliverEventScript('{"type":"event","event":"a"}'),
      r'window.DynaOpsNative && window.DynaOpsNative._receive("{\"type\":\"event\",\"event\":\"a\"}");',
    );
  });
}
