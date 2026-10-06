/// `SyncStatusModel` (`sync.status` data) and `SyncCycleResult` (what one
/// upload cycle did).
///
/// Why it exists: shared shapes for the sync engine, `SyncRepository`, the
/// bridge and the diagnostics screen.
/// Status: used — `SyncStatusModel` by `SyncRepository` / `SyncHandler` /
/// diagnostics; `SyncCycleResult` returned by `SyncManager.runCycle`.
library;

import 'package:equatable/equatable.dart';

class SyncStatusModel extends Equatable {
  const SyncStatusModel({
    required this.running,
    required this.pending,
    required this.failed,
    this.lastSuccessAt,
    this.lastError,
  });

  final bool running;
  final int pending;
  final int failed;
  final DateTime? lastSuccessAt;
  final String? lastError;

  Map<String, dynamic> toJson() => {
        'running': running,
        'pending': pending,
        'failed': failed,
        'lastSuccessAt': lastSuccessAt?.toUtc().toIso8601String(),
        'lastError': lastError,
      };

  @override
  List<Object?> get props => [running, pending, failed, lastSuccessAt, lastError];
}

class SyncCycleResult extends Equatable {
  const SyncCycleResult({required this.ran, this.processed = 0, this.failed = 0, this.skippedBecause});

  const SyncCycleResult.skipped(String this.skippedBecause)
      : ran = false,
        processed = 0,
        failed = 0;

  final bool ran;
  final int processed;
  final int failed;
  final String? skippedBecause;

  @override
  List<Object?> get props => [ran, processed, failed, skippedBecause];
}
