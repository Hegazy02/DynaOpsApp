/// `ShellLoadErrorView`: the "No connection" / "Couldn't load" state with a
/// Retry button (§5.1), built on the shared `ErrorView` with localised copy.
///
/// Why it exists: feature-specific wording and icon choice stay in the
/// feature; the generic layout stays in `shared/widgets`.
/// Status: used — shown by `ShellScreen` on `ShellLoadError`.
library;

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/feedback/error_view.dart';

/// "No connection" / "Couldn't load" with Retry (§5.1).
class ShellLoadErrorView extends StatelessWidget {
  const ShellLoadErrorView({super.key, required this.offline, required this.onRetry});

  final bool offline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ErrorView(
      icon: offline ? Icons.wifi_off : Icons.cloud_off,
      title: offline ? l10n.shellOfflineTitle : l10n.shellLoadErrorTitle,
      message: offline ? l10n.shellOfflineMessage : l10n.shellLoadErrorMessage,
      action: FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
    );
  }
}
