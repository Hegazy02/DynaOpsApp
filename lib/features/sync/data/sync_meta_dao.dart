/// `SyncMetaDao`: string key/value rows in `sync_meta` (§9) — last successful
/// upload, last error, policy snapshot, service running flag.
///
/// Why it exists: both isolates need these values, and `shared_preferences`
/// caches per isolate; the shared database does not.
/// Status: used — by `SyncManager`, `SyncRepository`,
/// `TrackingPolicyRepository`, `TrackingEngine`, `TrackingRepository`.
library;

import 'package:sqflite/sqflite.dart';

abstract final class SyncMetaKeys {
  static const lastSuccessAt = 'last_success_at';
  static const lastError = 'last_error';
  static const policy = 'policy_snapshot';
  static const policyFetchedAt = 'policy_fetched_at';

  /// '1' from the service's start to its clean destroy; still '1' with no
  /// service running means it was force-stopped or killed (§8.2).
  static const serviceRunning = 'service_running';
  static const lastPurgeAt = 'last_purge_at';
}

class SyncMetaDao {
  SyncMetaDao(this._db);
  final Database _db;

  Future<String?> get(String key) async {
    final rows = await _db.query('sync_meta', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> set(String key, String? value) => _db.insert(
        'sync_meta',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<DateTime?> getDate(String key) async {
    final value = await get(key);
    return value == null ? null : DateTime.tryParse(value);
  }

  Future<void> setDate(String key, DateTime value) => set(key, value.toUtc().toIso8601String());
}
