/// The bridge protocol v1.0 envelopes (§6): `BridgeRequest` (validated from
/// JSON), `BridgeResponse` (success/failure, serialised back to the page) and
/// `BridgeEvent` (native → page push), plus `protocolVersion`.
///
/// Why it exists: one typed definition of the wire format shared by the
/// controller, the handlers and the shell, mirrored by Angular's contract
/// file.
/// Status: used — everywhere a bridge message is built or parsed.
library;

import 'package:equatable/equatable.dart';

import 'bridge_error_model.dart';

/// Envelopes of bridge protocol v1.0 (§6).
class BridgeRequest extends Equatable {
  const BridgeRequest({
    required this.version,
    required this.id,
    required this.action,
    this.payload = const {},
  });

  /// Throws [FormatException] for anything that is not a request envelope.
  factory BridgeRequest.fromJson(Object? json) {
    return switch (json) {
      {
        'version': final String version,
        'type': 'request',
        'id': final String id,
        'action': final String action,
      }
          when id.isNotEmpty && action.isNotEmpty =>
        BridgeRequest(
          version: version,
          id: id,
          action: action,
          payload: switch (json['payload']) {
            null => const {},
            final Map<String, dynamic> map => map,
            _ => throw const FormatException('payload must be an object'),
          },
        ),
      _ => throw const FormatException('Not a bridge request envelope'),
    };
  }

  final String version;
  final String id;
  final String action;
  final Map<String, dynamic> payload;

  /// `tracking.start` → `tracking`.
  String get prefix => action.split('.').first;

  @override
  List<Object?> get props => [version, id, action, payload];
}

class BridgeResponse extends Equatable {
  const BridgeResponse.success({required this.id, required this.action, this.data})
      : error = null;

  const BridgeResponse.failure({required this.id, required this.action, required BridgeError this.error})
      : data = null;

  final String? id;
  final String? action;
  final Object? data;
  final BridgeError? error;

  bool get success => error == null;

  Map<String, dynamic> toJson() => {
        'version': protocolVersion,
        'type': 'response',
        'id': id,
        'action': action,
        'success': success,
        if (success) 'data': data,
        if (!success) 'error': error!.toJson(),
      };

  @override
  List<Object?> get props => [id, action, data, error];
}

class BridgeEvent extends Equatable {
  const BridgeEvent(this.event, [this.data = const <String, dynamic>{}]);

  final String event;
  final Object? data;

  Map<String, dynamic> toJson() => {
        'version': protocolVersion,
        'type': 'event',
        'event': event,
        'data': data,
      };

  @override
  List<Object?> get props => [event, data];
}

const protocolVersion = '1.0';
