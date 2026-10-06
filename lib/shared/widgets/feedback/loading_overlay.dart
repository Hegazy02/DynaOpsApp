/// `LoadingOverlay`: full-area progress indicator (determinate when
/// `progress` is given) with an optional caption, theme-coloured.
///
/// Why it exists: flutter-build-shared-widgets — the one loading surface used
/// while the WebView (and later other screens) loads; includes a widget
/// preview.
/// Status: used — by `ShellScreen` during `ShellStarting` and `ShellLoading`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

/// Full-area progress indicator with an optional caption. [progress] in 0..1;
/// null shows an indeterminate spinner.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key, this.label, this.progress});

  final String? label;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: progress),
            if (label != null) ...[
              const SizedBox(height: 16),
              Text(label!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

@Preview(name: 'LoadingOverlay')
Widget loadingOverlayPreview() => const LoadingOverlay(label: 'Loading…', progress: 0.4);
