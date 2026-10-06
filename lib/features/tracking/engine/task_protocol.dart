/// Message protocol between the UI isolate and the tracking-service isolate:
/// command names (UI → service) and message types (service → UI). Payloads
/// are plain maps of primitives so they cross isolates as-is.
///
/// Why it exists: both sides import one list of names, so a typo is a
/// compile error rather than a silently ignored message.
/// Status: used — by `TrackingEngine`, `ForegroundTaskPort`,
/// `TrackingRepository` and `SyncRepository`.
library;

/// UI → service: `{'cmd': <name>, ...}`.
abstract final class TaskCommand {
  static const key = 'cmd';

  /// Re-read the session from secure storage (adopted, swapped, expired).
  static const sessionChanged = 'sessionChanged';
  static const syncNow = 'syncNow';
  static const refreshPolicy = 'refreshPolicy';
  static const permissionsChanged = 'permissionsChanged';
  static const publishStatus = 'publishStatus';

  /// Stop collecting, run one sync cycle, reply with [TaskMessage.flushed]
  /// carrying the same `requestId` (sign-out / user swap, §7).
  static const flush = 'flush';
}

/// Service → UI: `{'type': <name>, ...}`.
abstract final class TaskMessage {
  static const key = 'type';

  /// `status`: `TrackingStatusModel.toJson()`.
  static const status = 'status';

  /// `fix`: `LocationFixModel.toMessage()`.
  static const location = 'location';

  /// `event` + `data`: a `sync.*` event.
  static const sync = 'sync';

  /// `requestId` + `processed`.
  static const flushed = 'flushed';

  /// `line`: a log line for the diagnostics screen.
  static const log = 'log';
}
