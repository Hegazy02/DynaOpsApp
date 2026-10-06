/// `BridgeController`: the JS → native dispatcher (§6.2). Parses the request
/// envelope, checks the protocol major version and size limits, routes by
/// action prefix to a `BridgeHandler`, applies per-prefix timeouts and always
/// returns exactly one response echoing the request `id`. Also merges every
/// handler's events into one stream for the shell to push to the page.
///
/// Why it exists: keeps protocol rules (versioning, limits, error mapping) in
/// one pure-Dart class with no WebView dependency, so it is fully unit-tested.
/// Status: used — registered in `service_locator.dart`; `ShellCubit` feeds it
/// every message from `window.DynaOpsNative`.
library;

import 'dart:async';
import 'dart:convert';

import '../core/logging/app_logger.dart';
import '../core/network/failure.dart';
import 'bridge_error_model.dart';
import 'bridge_handler.dart';
import 'bridge_message_model.dart';

/// Parse → check version → dispatch by action prefix → respond (§6.2).
///
/// Exactly one response per request, echoing its `id`, also on exceptions and
/// timeouts. Pure Dart: no WebView, no Flutter widgets.
class BridgeController {
  BridgeController(
    List<BridgeHandler> handlers,
    this._logger, {
    this.defaultTimeout = const Duration(seconds: 30),
    this.timeouts = const {'files': Duration(minutes: 5)},
  }) : _handlers = {for (final h in handlers) h.prefix: h};

  /// Largest message accepted; `files.*` carry whole base64 files (§6.1).
  static const maxMessageLength = 15 * 1024 * 1024;
  static const _smallMessageLength = 1024 * 1024;
  static const supportedMajor = '1';

  final Map<String, BridgeHandler> _handlers;
  final AppLogger _logger;
  final Duration defaultTimeout;

  /// Per-prefix overrides of [defaultTimeout] (print/share dialogs stay open).
  final Map<String, Duration> timeouts;

  /// All handler events, merged into one broadcast stream.
  late final Stream<BridgeEvent> events = mergeEvents([for (final h in _handlers.values) h.events]);

  /// Handles one raw message from JavaScript and returns the response JSON.
  Future<String> handleMessage(String raw) async {
    final response = await _respond(raw);
    if (!response.success) {
      _logger.warn('bridge ${response.action ?? '?'} #${response.id ?? '?'} → ${response.error!.code.wire}');
    }
    return jsonEncode(response.toJson());
  }

  Future<BridgeResponse> _respond(String raw) async {
    if (raw.length > maxMessageLength) {
      return BridgeResponse.failure(
        id: null,
        action: null,
        error: BridgeError.invalidArgument('Message too large.'),
      );
    }

    final BridgeRequest request;
    try {
      request = BridgeRequest.fromJson(jsonDecode(raw));
    } on FormatException catch (e) {
      return BridgeResponse.failure(
        id: _peekId(raw),
        action: null,
        error: BridgeError.invalidArgument('Malformed envelope: ${e.message}'),
      );
    }

    BridgeResponse fail(BridgeError error) =>
        BridgeResponse.failure(id: request.id, action: request.action, error: error);

    if (request.version.split('.').first != supportedMajor) {
      return fail(BridgeError.unsupported(
        'Bridge version ${request.version} not supported; this app speaks $protocolVersion.',
      ));
    }
    if (request.prefix != 'files' && raw.length > _smallMessageLength) {
      return fail(BridgeError.invalidArgument('Message too large.'));
    }
    final handler = _handlers[request.prefix];
    if (handler == null) {
      return fail(BridgeError.unsupported('Unknown action "${request.action}".'));
    }

    try {
      final data = await handler.handle(request).timeout(timeouts[request.prefix] ?? defaultTimeout);
      return BridgeResponse.success(id: request.id, action: request.action, data: data);
    } on BridgeError catch (e) {
      return fail(e);
    } on Failure catch (f) {
      return fail(BridgeError.fromFailure(f));
    } on TimeoutException {
      return fail(const BridgeError(BridgeErrorCode.nativeError, 'Timed out.', retryable: true));
    } catch (e, stackTrace) {
      _logger.error('bridge ${request.action} crashed', e, stackTrace);
      return fail(const BridgeError(BridgeErrorCode.nativeError, 'Unexpected native error.'));
    }
  }

  /// Best effort so even a malformed request gets its id echoed.
  static String? _peekId(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map && decoded['id'] is String ? decoded['id'] as String : null;
    } catch (_) {
      return null;
    }
  }
}
