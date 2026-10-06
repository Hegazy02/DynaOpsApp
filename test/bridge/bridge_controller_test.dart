/// Tests for `BridgeController` (§6.2) using an in-memory echo handler:
/// envelope round-trip and id echo, malformed JSON and wrong envelope types,
/// major/minor version checks, unknown prefix/action, `Failure` and
/// `BridgeError` mapping, crash containment, one-response timeouts, the
/// oversized-message limit and merged handler events.
///
/// Status: active — part of `flutter test`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dynaopsapp/bridge/bridge_controller.dart';
import 'package:dynaopsapp/bridge/bridge_error_model.dart';
import 'package:dynaopsapp/bridge/bridge_handler.dart';
import 'package:dynaopsapp/bridge/bridge_message_model.dart';
import 'package:dynaopsapp/core/logging/app_logger.dart';
import 'package:dynaopsapp/core/network/failure.dart';
import 'package:flutter_test/flutter_test.dart';

class _EchoHandler extends BridgeHandler {
  final events$ = StreamController<BridgeEvent>.broadcast();

  @override
  String get prefix => 'echo';

  @override
  Stream<BridgeEvent> get events => events$.stream;

  @override
  Future<Object?> handle(BridgeRequest request) async {
    return switch (request.action) {
      'echo.ok' => request.payload,
      'echo.failure' => throw const NetworkFailure(),
      'echo.bridgeError' => throw BridgeError.invalidArgument('bad'),
      'echo.crash' => throw StateError('boom'),
      'echo.slow' => Future.delayed(const Duration(seconds: 1), () => 'late'),
      _ => unknownAction(request),
    };
  }
}

String _request(String action, {String id = 'r1', String version = '1.0', Object? payload}) =>
    jsonEncode({'version': version, 'type': 'request', 'id': id, 'action': action, 'payload': payload ?? {}});

Map<String, dynamic> _decode(String json) => jsonDecode(json) as Map<String, dynamic>;

void main() {
  late _EchoHandler handler;
  late BridgeController controller;

  setUp(() {
    handler = _EchoHandler();
    controller = BridgeController(
      [handler],
      AppLogger(),
      defaultTimeout: const Duration(milliseconds: 50),
    );
  });

  test('round-trips a request and echoes its id', () async {
    final response = _decode(await controller.handleMessage(_request('echo.ok', id: 'abc', payload: {'x': 1})));
    expect(response, {
      'version': '1.0',
      'type': 'response',
      'id': 'abc',
      'action': 'echo.ok',
      'success': true,
      'data': {'x': 1},
    });
  });

  test('malformed JSON → INVALID_ARGUMENT', () async {
    final response = _decode(await controller.handleMessage('{not json'));
    expect(response['success'], false);
    expect(response['error']['code'], 'INVALID_ARGUMENT');
  });

  test('wrong envelope type keeps the id when it can', () async {
    final raw = jsonEncode({'version': '1.0', 'type': 'event', 'id': 'keep', 'action': 'echo.ok'});
    final response = _decode(await controller.handleMessage(raw));
    expect(response['id'], 'keep');
    expect(response['error']['code'], 'INVALID_ARGUMENT');
  });

  test('unknown major version → UNSUPPORTED', () async {
    final response = _decode(await controller.handleMessage(_request('echo.ok', version: '2.0')));
    expect(response['error']['code'], 'UNSUPPORTED');
  });

  test('a newer minor version of the same major is accepted', () async {
    final response = _decode(await controller.handleMessage(_request('echo.ok', version: '1.3')));
    expect(response['success'], true);
  });

  test('unknown prefix and unknown action → UNSUPPORTED', () async {
    expect(_decode(await controller.handleMessage(_request('nope.x')))['error']['code'], 'UNSUPPORTED');
    expect(_decode(await controller.handleMessage(_request('echo.nope')))['error']['code'], 'UNSUPPORTED');
  });

  test('Failure maps through toBridgeError', () async {
    final error = _decode(await controller.handleMessage(_request('echo.failure')))['error'];
    expect(error, {'code': 'NETWORK_ERROR', 'message': 'No internet connection.', 'retryable': true});
  });

  test('BridgeError passes through', () async {
    final error = _decode(await controller.handleMessage(_request('echo.bridgeError')))['error'];
    expect(error['code'], 'INVALID_ARGUMENT');
  });

  test('unexpected exception → NATIVE_ERROR without leaking details', () async {
    final error = _decode(await controller.handleMessage(_request('echo.crash')))['error'];
    expect(error['code'], 'NATIVE_ERROR');
    expect(error['message'], isNot(contains('boom')));
  });

  test('times out with one response', () async {
    final response = _decode(await controller.handleMessage(_request('echo.slow', id: 'slow')));
    expect(response['id'], 'slow');
    expect(response['error']['code'], 'NATIVE_ERROR');
    expect(response['error']['retryable'], true);
  });

  test('oversized non-files message is refused', () async {
    final big = 'x' * (1024 * 1024 + 1);
    final response = _decode(await controller.handleMessage(_request('echo.ok', payload: {'big': big})));
    expect(response['error']['code'], 'INVALID_ARGUMENT');
  });

  test('merges handler events', () async {
    final received = <BridgeEvent>[];
    final sub = controller.events.listen(received.add);
    handler.events$.add(const BridgeEvent('echo.happened', {'n': 1}));
    await Future<void>.delayed(Duration.zero);
    expect(received, [const BridgeEvent('echo.happened', {'n': 1})]);
    await sub.cancel();
  });
}
