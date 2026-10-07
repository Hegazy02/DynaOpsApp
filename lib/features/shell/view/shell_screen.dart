/// `ShellScreen`: hosts the WebView full-screen with a loading overlay while
/// the page loads and an error view when the main frame fails, handles
/// hardware back (WebView history, then an exit dialog), tells the Cubit when
/// the app resumes, and opens the native permission walkthrough or
/// diagnostics when Angular asks (`NativeNavigationCubit`). Missing tracking
/// permissions never reach this screen: the router's `PermissionGate` sends
/// the rep to the walkthrough first.
/// With `AppConfig.requestInspector` on, a draggable button opens `/requests`.
///
/// Why it exists: the UI half of the shell feature; every decision is
/// delegated to Cubits; navigation happens only in `BlocListener`s.
/// Status: used — mounted on `/` by `app_router.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/feedback/loading_overlay.dart';
import '../../request_inspector/view/widgets/request_inspector_fab.dart';
import '../cubit/native_navigation_cubit.dart';
import '../cubit/shell_cubit.dart';
import '../cubit/shell_state.dart';
import 'widgets/shell_load_error_view.dart';
import 'widgets/shell_web_view.dart';

/// Hosts the Angular app full-screen with loading/error overlays and back handling.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, this.showRequestInspector = false});

  /// Shows the draggable request-inspector button (`AppConfig.requestInspector`).
  final bool showRequestInspector;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => context.read<ShellCubit>().onAppResumed());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _onBack() async {
    final cubit = context.read<ShellCubit>();
    if (await cubit.goBack() || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.exitTitle),
        content: Text(l10n.exitMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.exitConfirm)),
        ],
      ),
    );
    if (leave ?? false) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A missing tracking permission is handled by the router's PermissionGate.
    return BlocListener<NativeNavigationCubit, NativeNavigationState>(
      listener: (context, state) {
        if (state is NativeNavigationRequested) context.push(state.screen.route);
      },
      child: _buildShell(context, l10n),
    );
  }

  Widget _buildShell(BuildContext context, AppLocalizations l10n) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<ShellCubit, ShellState>(
            builder: (context, state) => switch (state) {
              ShellStarting() => LoadingOverlay(label: l10n.shellLoading),
              ShellLoading() || ShellReady() || ShellLoadError() => Stack(
                  children: [
                    ShellWebView(key: ValueKey(state.webViewGeneration)),
                    ?_overlay(context, state, l10n),
                    if (widget.showRequestInspector) const Positioned.fill(child: RequestInspectorFab()),
                  ],
                ),
            },
          ),
        ),
      ),
    );
  }

  Widget? _overlay(BuildContext context, ShellState state, AppLocalizations l10n) => switch (state) {
        ShellStarting() => LoadingOverlay(label: l10n.shellLoading),
        ShellLoading(:final progress) =>
          LoadingOverlay(label: l10n.shellLoading, progress: progress > 0 ? progress / 100 : null),
        ShellReady() => null,
        ShellLoadError(:final offline) =>
          ShellLoadErrorView(offline: offline, onRetry: context.read<ShellCubit>().retry),
      };
}
