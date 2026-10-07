/// `PermissionStepCard`: one walkthrough step — icon, title, explanation, a
/// primary action and, for skippable steps only, a "Next" text button — with
/// already-resolved strings.
///
/// Why it exists: keeps `PermissionWalkthroughScreen.build` small; it is
/// specific to this feature, so it stays in `view/widgets/`, not
/// `shared/widgets/` (flutter-build-shared-widgets).
/// Status: used — by `PermissionWalkthroughScreen`.
library;

import 'package:flutter/material.dart';

class PermissionStepCard extends StatelessWidget {
  const PermissionStepCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.nextLabel,
    this.onNext,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? nextLabel;
  /// Null hides the "Next" button (required steps cannot be skipped).
  final VoidCallback? onNext;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(body, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: busy ? null : onPrimary,
          child: busy
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(primaryLabel),
        ),
        if (onNext != null && nextLabel != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: busy ? null : onNext, child: Text(nextLabel!)),
        ],
      ],
    );
  }
}
