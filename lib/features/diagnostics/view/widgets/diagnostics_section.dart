/// `DiagnosticsSection`: a titled card of label/value rows on the diagnostics
/// screen; values are selectable so support can copy them.
///
/// Why it exists: keeps `DiagnosticsScreen.build` short; feature-specific, so
/// it lives in this feature's `view/widgets/`.
/// Status: used — by `DiagnosticsScreen`.
library;

import 'package:flutter/material.dart';

class DiagnosticsSection extends StatelessWidget {
  const DiagnosticsSection({super.key, required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: Text(label, style: theme.textTheme.bodyMedium)),
                    Expanded(flex: 3, child: SelectableText(value, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
