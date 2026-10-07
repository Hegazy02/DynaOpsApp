/// `QueuedFixModel`: a not-yet-synced fix (pending, uploading or failed) with
/// its upload bookkeeping — attempts, last error, batch id, retryable flag.
///
/// Why it exists: `LocationFixModel` carries only what the engine needs; the
/// request inspector also shows why a fix is still in the queue.
/// Status: used — returned by `LocationPointsDao.queued`, shown by the request
/// inspector's queue tab.
library;

import 'package:equatable/equatable.dart';

import 'location_fix_model.dart';

class QueuedFixModel extends Equatable {
  const QueuedFixModel({
    required this.fix,
    this.lastError,
    this.batchId,
    required this.retryable,
    required this.createdAt,
  });

  factory QueuedFixModel.fromRow(Map<String, Object?> row) => QueuedFixModel(
        fix: LocationFixModel.fromRow(row),
        lastError: row['last_error'] as String?,
        batchId: row['batch_id'] as String?,
        retryable: row['retryable'] != 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int, isUtc: true),
      );

  final LocationFixModel fix;
  final String? lastError;
  final String? batchId;
  final bool retryable;
  final DateTime createdAt;

  @override
  List<Object?> get props => [fix, lastError, batchId, retryable, createdAt];
}
