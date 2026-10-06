/// `BridgeHandler`: the base class each action prefix implements (`auth`,
/// `files`, …) — `handle` for requests, `events` for pushes — plus the
/// `BridgePayload` extension that reads payload fields and fails with
/// `INVALID_ARGUMENT` instead of a `TypeError`.
///
/// Why it exists: handlers talk only to repositories (§10.1), so the base
/// class is deliberately small and knows nothing about Cubits, Dio or widgets.
/// Status: used — extended by the seven handlers in `handlers/`; `mergeEvents`
/// is shared by `BridgeController` and `TrackingHandler`.
library;

import 'dart:async';

import 'bridge_error_model.dart';
import 'bridge_message_model.dart';

/// One handler per action prefix (`auth`, `files`, …), §10.1. Handlers call
/// repositories only — never Cubits, Dio or widgets.
abstract class BridgeHandler {
  /// The action prefix this handler owns, e.g. `auth` for `auth.setSession`.
  String get prefix;

  /// Returns the response `data`. Throws [BridgeError] or `Failure`.
  Future<Object?> handle(BridgeRequest request);

  /// Events this handler publishes, built from repository streams.
  Stream<BridgeEvent> get events => const Stream.empty();

  Never unknownAction(BridgeRequest request) =>
      throw BridgeError.unsupported('Unknown action "${request.action}".');
}

/// Merges [streams] into one broadcast stream that subscribes to all of them
/// while it has a listener (for handlers publishing more than one event kind).
Stream<BridgeEvent> mergeEvents(List<Stream<BridgeEvent>> streams) {
  final subscriptions = <StreamSubscription<BridgeEvent>>[];
  late final StreamController<BridgeEvent> controller;
  controller = StreamController<BridgeEvent>.broadcast(
    onListen: () {
      for (final stream in streams) {
        subscriptions.add(stream.listen(controller.add));
      }
    },
    onCancel: () {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
      subscriptions.clear();
    },
  );
  return controller.stream;
}

/// Payload readers that fail with `INVALID_ARGUMENT` instead of a `TypeError`.
extension BridgePayload on Map<String, dynamic> {
  String requireString(String key) {
    final value = this[key];
    if (value is String && value.isNotEmpty) return value;
    throw BridgeError.invalidArgument('"$key" must be a non-empty string.');
  }

  String? optionalString(String key) {
    final value = this[key];
    if (value == null || value is String) return value as String?;
    throw BridgeError.invalidArgument('"$key" must be a string.');
  }

  bool optionalBool(String key, {bool fallback = false}) {
    final value = this[key];
    if (value == null) return fallback;
    if (value is bool) return value;
    throw BridgeError.invalidArgument('"$key" must be a boolean.');
  }

  num optionalNum(String key, {required num fallback}) {
    final value = this[key];
    if (value == null) return fallback;
    if (value is num && value >= 0) return value;
    throw BridgeError.invalidArgument('"$key" must be a non-negative number.');
  }

  List<String> stringList(String key) {
    final value = this[key];
    if (value == null) return const [];
    if (value is List && value.every((e) => e is String)) return value.cast<String>();
    throw BridgeError.invalidArgument('"$key" must be a list of strings.');
  }
}
