/// `DiagnosticsScreen`: the hidden support screen (§15) — tracking, uploads,
/// tracking settings, device, recent log, and the actions upload now / retry
/// failed / share log / clear web cache, with snackbars for their outcome.
///
/// Why it exists: support needs the state of the queue and the service on the
/// rep's own phone, in the field, without a cable.
/// Status: used — mounted on `/diagnostics`; reached from the permission
/// walkthrough or `app.openNativeScreen({screen:'diagnostics'})`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/feedback/loading_overlay.dart';
import '../cubit/diagnostics_cubit.dart';
import '../cubit/diagnostics_state.dart';
import 'widgets/diagnostics_section.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocListener<DiagnosticsCubit, DiagnosticsState>(
      listenWhen: (previous, current) =>
          current is DiagnosticsLoaded &&
          current.notice != null &&
          (previous is! DiagnosticsLoaded || previous.notice != current.notice),
      listener: (context, state) {
        if (state is! DiagnosticsLoaded || state.notice == null) return;
        final notice = state.notice!;
        final text = switch (notice.kind) {
          DiagnosticsNoticeKind.syncStarted => l10n.diagNoticeSyncStarted,
          DiagnosticsNoticeKind.requeued => l10n.diagNoticeRequeued(notice.count),
          DiagnosticsNoticeKind.cacheCleared => l10n.diagNoticeCacheCleared,
          DiagnosticsNoticeKind.actionFailed => l10n.diagNoticeActionFailed,
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.diagnosticsTitle)),
        body: BlocBuilder<DiagnosticsCubit, DiagnosticsState>(
          builder: (context, state) => switch (state) {
            DiagnosticsLoading() => const LoadingOverlay(),
            DiagnosticsLoaded() => _LoadedView(state: state),
          },
        ),
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.state});
  final DiagnosticsLoaded state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DiagnosticsCubit>();
    final tracking = state.tracking;
    final sync = state.sync;
    String yesNo(bool value) => value ? l10n.diagYes : l10n.diagNo;
    String text(Object? value) => value == null ? l10n.diagNone : '$value';
    String time(DateTime? value) => value == null ? l10n.diagNone : value.toLocal().toString().split('.').first;

    return RefreshIndicator(
      onRefresh: cubit.refresh,
      child: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          DiagnosticsSection(title: l10n.diagTracking, rows: [
            (l10n.diagState, tracking.state.wire),
            (l10n.diagReason, text(tracking.reason)),
            (l10n.diagError, text(tracking.errorCode)),
            (l10n.diagService, yesNo(tracking.backgroundService)),
            (l10n.diagLocationPermission, tracking.locationPermission),
            (l10n.diagBackgroundPermission, tracking.backgroundPermission),
            (l10n.diagLastFix, time(tracking.lastLocationAt)),
          ]),
          DiagnosticsSection(title: l10n.diagSync, rows: [
            (l10n.diagPending, '${sync.pending}'),
            (l10n.diagFailed, '${sync.failed}'),
            (l10n.diagLastUpload, time(sync.lastSuccessAt)),
            (l10n.diagLastError, text(sync.lastError)),
          ]),
          DiagnosticsSection(title: l10n.diagPolicy, rows: [
            (l10n.diagEnabled, yesNo(state.policy.enabled)),
            (l10n.diagMode, state.policy.mode),
            (l10n.diagShift, text(state.policy.shiftWindow?.toJson())),
          ]),
          DiagnosticsSection(title: l10n.diagDevice, rows: [
            (l10n.diagAppVersion, text(state.device?.appVersion)),
            (l10n.diagModel, text(state.device == null ? null : '${state.device!.manufacturer} ${state.device!.model}')),
            (l10n.diagAndroid, text(state.device?.androidSdk)),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(onPressed: cubit.syncNow, child: Text(l10n.diagSyncNow)),
              FilledButton.tonal(onPressed: cubit.retryFailed, child: Text(l10n.diagRetryFailed)),
              OutlinedButton(onPressed: cubit.exportLog, child: Text(l10n.diagExportLogs)),
              OutlinedButton(onPressed: cubit.clearWebCache, child: Text(l10n.diagClearCache)),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.diagLogs, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText(
            state.log.join('\n'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
