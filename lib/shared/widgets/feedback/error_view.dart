/// `ErrorView`: generic icon + title + message + optional action, centred and
/// theme-coloured. Strings arrive already localised from the caller.
///
/// Why it exists: flutter-build-shared-widgets — one reusable empty/error
/// layout for every feature; includes a widget preview.
/// Status: used — by `ShellLoadErrorView`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

/// Icon, title, message and an optional action. Strings come resolved from the caller.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.error_outline,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(message, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                if (action != null) ...[const SizedBox(height: 24), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@Preview(name: 'ErrorView')
Widget errorViewPreview() => const ErrorView(
      title: 'No connection',
      message: 'Check your internet connection.',
      icon: Icons.wifi_off,
    );
