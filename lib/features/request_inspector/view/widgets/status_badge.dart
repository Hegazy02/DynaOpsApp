/// `StatusBadge`: a small coloured label for an HTTP status (green 2xx, amber
/// 4xx, red 5xx or no answer) or a queued point's state.
///
/// Why it exists: one look for status across the inspector's lists and sheet.
/// Status: used — by `RequestLogTile`, `RequestDetailsSheet`, `QueuedFixTile`.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

enum StatusTone { success, warning, error, neutral }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone});

  /// Tone for an HTTP status; null (no answer) is an error.
  factory StatusBadge.http(int? status, {required String noStatusLabel}) => StatusBadge(
        label: status?.toString() ?? noStatusLabel,
        tone: switch (status) {
          null => StatusTone.error,
          >= 200 && < 300 => StatusTone.success,
          >= 400 && < 500 => StatusTone.warning,
          _ => StatusTone.error,
        },
      );

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final color = switch (tone) {
      StatusTone.success => colors.success,
      StatusTone.warning => colors.warning,
      StatusTone.error => theme.colorScheme.error,
      StatusTone.neutral => theme.colorScheme.outline,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 2),
        child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
