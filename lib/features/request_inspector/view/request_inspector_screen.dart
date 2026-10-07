/// `RequestInspectorScreen`: debug view of tracking traffic — a sync summary
/// (pending, failed, running, last upload, last error), then two tabs: every
/// recorded API request (status, payload, response; tap for details) and the
/// points still queued for upload. Actions: refresh, upload now, retry
/// failed, clear log; outcomes are shown as snackbars.
///
/// Why it exists: see what was sent, what came back and what is still waiting
/// without adb or a proxy.
/// Status: used — mounted on `/requests`, opened from `RequestInspectorFab`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/feedback/error_view.dart';
import '../../../shared/widgets/feedback/loading_overlay.dart';
import '../../diagnostics/view/widgets/diagnostics_section.dart';
import '../cubit/request_inspector_cubit.dart';
import '../cubit/request_inspector_state.dart';
import 'widgets/queued_fix_tile.dart';
import 'widgets/request_log_tile.dart';

enum _MenuAction { retryFailed, clearLog }

class RequestInspectorScreen extends StatelessWidget {
  const RequestInspectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<RequestInspectorCubit>();
    return BlocListener<RequestInspectorCubit, RequestInspectorState>(
      listenWhen: (previous, current) =>
          current is RequestInspectorLoaded &&
          current.notice != null &&
          (previous is! RequestInspectorLoaded || previous.notice != current.notice),
      listener: (context, state) {
        if (state is! RequestInspectorLoaded || state.notice == null) return;
        final notice = state.notice!;
        final text = switch (notice.kind) {
          RequestInspectorNoticeKind.syncStarted => l10n.diagNoticeSyncStarted,
          RequestInspectorNoticeKind.syncBusy => l10n.reqNoticeSyncBusy,
          RequestInspectorNoticeKind.requeued => l10n.diagNoticeRequeued(notice.count),
          RequestInspectorNoticeKind.cleared => l10n.reqNoticeCleared,
          RequestInspectorNoticeKind.actionFailed => l10n.diagNoticeActionFailed,
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(text)));
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.reqInspectorTitle),
            actions: [
              IconButton(tooltip: l10n.reqRefresh, icon: const Icon(Icons.refresh), onPressed: cubit.refresh),
              IconButton(tooltip: l10n.diagSyncNow, icon: const Icon(Icons.cloud_upload_outlined), onPressed: cubit.syncNow),
              PopupMenuButton<_MenuAction>(
                onSelected: (action) => switch (action) {
                  _MenuAction.retryFailed => cubit.retryFailed(),
                  _MenuAction.clearLog => cubit.clearLog(),
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: _MenuAction.retryFailed, child: Text(l10n.diagRetryFailed)),
                  PopupMenuItem(value: _MenuAction.clearLog, child: Text(l10n.reqClear)),
                ],
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(kTextTabBarHeight),
              child: BlocBuilder<RequestInspectorCubit, RequestInspectorState>(
                builder: (context, state) {
                  final (requests, queued) = switch (state) {
                    RequestInspectorLoaded(:final requests, :final queue) => (requests.length, queue.length),
                    _ => (0, 0),
                  };
                  return TabBar(tabs: [
                    Tab(text: l10n.reqTabRequests(requests)),
                    Tab(text: l10n.reqTabQueue(queued)),
                  ]);
                },
              ),
            ),
          ),
          body: BlocBuilder<RequestInspectorCubit, RequestInspectorState>(
            builder: (context, state) => switch (state) {
              RequestInspectorLoading() => const LoadingOverlay(),
              RequestInspectorError(:final message) => ErrorView(
                  title: l10n.reqLoadFailed,
                  message: message,
                  action: FilledButton(onPressed: cubit.refresh, child: Text(l10n.retry)),
                ),
              RequestInspectorLoaded() => TabBarView(children: [
                  _RequestsTab(state: state),
                  _QueueTab(state: state),
                ]),
            },
          ),
        ),
      ),
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({required this.state});
  final RequestInspectorLoaded state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: context.read<RequestInspectorCubit>().refresh,
      child: state.requests.isEmpty
          ? ListView(children: [
              Padding(
                padding: const EdgeInsetsDirectional.all(32),
                child: Text(l10n.reqEmpty, textAlign: TextAlign.center),
              ),
            ])
          : ListView.separated(
              itemCount: state.requests.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => RequestLogTile(entry: state.requests[i]),
            ),
    );
  }
}

class _QueueTab extends StatelessWidget {
  const _QueueTab({required this.state});
  final RequestInspectorLoaded state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sync = state.sync;
    String time(DateTime? value) => value == null ? l10n.diagNone : value.toLocal().toString().split('.').first;
    return RefreshIndicator(
      onRefresh: context.read<RequestInspectorCubit>().refresh,
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 4),
            child: DiagnosticsSection(title: l10n.diagSync, rows: [
              (l10n.diagPending, '${sync.pending}'),
              (l10n.diagFailed, '${sync.failed}'),
              (l10n.reqUploadRunning, sync.running ? l10n.diagYes : l10n.diagNo),
              (l10n.diagLastUpload, time(sync.lastSuccessAt)),
              (l10n.diagLastError, sync.lastError ?? l10n.diagNone),
            ]),
          ),
          if (state.queue.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.all(32),
              child: Text(l10n.reqQueueEmpty, textAlign: TextAlign.center),
            ),
          for (final item in state.queue)
            QueuedFixTile(key: ValueKey(item.fix.id), item: item, localTimestamps: state.localTimestamps),
        ],
      ),
    );
  }
}
