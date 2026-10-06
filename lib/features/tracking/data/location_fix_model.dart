/// `LocationFixModel`: a stored fix — a `PositionModel` plus its id, owner
/// (`userId`) and upload state — with row, bridge and isolate-message
/// mappings, and `toWirePing()` for `POST LocationPings/batch`.
///
/// Why it exists: the points store is the source of truth for tracking (§9);
/// every row carries `userId` so a user swap never uploads A's fixes as B.
/// Status: used — written by `LocationRepository`, uploaded by
/// `ApiLocationUploader`, sent to Angular as `tracking.location`.
library;

import 'package:equatable/equatable.dart';

import 'position_model.dart';

enum FixState {
  pending('pending'),
  uploading('uploading'),
  synced('synced'),
  failed('failed');

  const FixState(this.wire);
  final String wire;

  static FixState fromWire(String value) =>
      values.firstWhere((s) => s.wire == value, orElse: () => FixState.pending);
}

class LocationFixModel extends Equatable {
  const LocationFixModel({
    required this.id,
    required this.userId,
    required this.position,
    this.state = FixState.pending,
    this.attempts = 0,
  });

  factory LocationFixModel.fromRow(Map<String, Object?> row) => LocationFixModel(
        id: row['id']! as String,
        userId: row['user_id']! as String,
        position: PositionModel(
          latitude: (row['lat']! as num).toDouble(),
          longitude: (row['lng']! as num).toDouble(),
          accuracy: (row['accuracy']! as num).toDouble(),
          speed: (row['speed'] as num?)?.toDouble(),
          heading: (row['heading'] as num?)?.toDouble(),
          isMocked: row['is_mocked'] == 1,
          timestamp: DateTime.fromMillisecondsSinceEpoch(row['captured_at']! as int, isUtc: true),
        ),
        state: FixState.fromWire(row['state']! as String),
        attempts: row['attempts'] as int? ?? 0,
      );

  /// Rebuilds a fix sent across isolates with [toMessage].
  factory LocationFixModel.fromMessage(Map<Object?, Object?> message) => LocationFixModel.fromRow(
        message.map((key, value) => MapEntry(key! as String, value)),
      );

  final String id;
  final String userId;
  final PositionModel position;
  final FixState state;
  final int attempts;

  Map<String, Object?> toRow({required DateTime createdAt}) => {
        'id': id,
        'user_id': userId,
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'is_mocked': position.isMocked ? 1 : 0,
        'captured_at': position.timestamp.toUtc().millisecondsSinceEpoch,
        'state': state.wire,
        'attempts': attempts,
        'created_at': createdAt.toUtc().millisecondsSinceEpoch,
      };

  Map<String, Object?> toMessage() => toRow(createdAt: position.timestamp);

  /// `tracking.location` event data (§6.4).
  Map<String, dynamic> toBridgeJson() => {
        'id': id,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': position.timestamp.toUtc().toIso8601String(),
        'storedLocally': true,
        'synced': state == FixState.synced,
      };

  /// One ping as `POST LocationPings/batch` expects it — the contract the old
  /// tracker (dyn_gis) uses against the same API: naive timestamp, km/h and
  /// whole degrees as integers (the API binds them to ints), source `Gps`.
  Map<String, dynamic> toWirePing({required bool localTimestamps}) => {
        'at': formatWireTimestamp(position.timestamp, local: localTimestamps),
        'lat': position.latitude,
        'lng': position.longitude,
        'speedKmh': ((position.speed ?? 0) * 3.6).round(),
        'headingDeg': (position.heading ?? 0).round(),
        'source': 'Gps',
      };

  /// `yyyy-MM-ddTHH:mm:ss`, no offset, in device-local time or UTC.
  static String formatWireTimestamp(DateTime value, {required bool local}) {
    final t = local ? value.toLocal() : value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
        'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  List<Object?> get props => [id, userId, position, state, attempts];
}
