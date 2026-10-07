/// `QueuedFixTile`: one not-yet-synced point — state, capture time,
/// coordinates and last error; expands to attempts, batch, retryable and the
/// exact JSON ping it will be uploaded as.
///
/// Why it exists: shows why a point is still queued without adb.
/// Status: used — by `RequestInspectorScreen`'s queue tab.
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../tracking/data/location_fix_model.dart';
import '../../../tracking/data/queued_fix_model.dart';
import 'json_block.dart';
import 'status_badge.dart';

class QueuedFixTile extends StatelessWidget {
  const QueuedFixTile({super.key, required this.item, required this.localTimestamps});

  final QueuedFixModel item;
  final bool localTimestamps;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fix = item.fix;
    final p = fix.position;
    final tone = switch (fix.state) {
      FixState.pending => StatusTone.neutral,
      FixState.uploading => StatusTone.warning,
      FixState.failed => StatusTone.error,
      FixState.synced => StatusTone.success,
    };
    String row(String label, Object? value) => '$label: ${value ?? l10n.diagNone}';
    return ExpansionTile(
      leading: StatusBadge(label: fix.state.wire, tone: tone),
      title: Text(
        p.timestamp.toLocal().toString().split('.').first,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)} ±${p.accuracy.round()} m',
            textDirection: TextDirection.ltr,
          ),
          if (item.lastError != null)
            Text(
              item.lastError!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
        ],
      ),
      childrenPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(
          [
            row(l10n.reqAttempts, fix.attempts),
            row(l10n.reqRetryable, item.retryable ? l10n.diagYes : l10n.diagNo),
            row(l10n.reqBatch, item.batchId),
            row(l10n.reqAccuracy, '${p.accuracy.toStringAsFixed(1)} m'),
            row(l10n.diagLastError, item.lastError),
            row('id', fix.id),
          ].join('\n'),
          style: theme.textTheme.bodySmall,
        ),
        JsonBlock(
          title: l10n.reqWirePayload,
          text: jsonEncode(fix.toWirePing(localTimestamps: localTimestamps)),
        ),
      ],
    );
  }
}
