/// `RequestDetailsSheet`: full detail of one recorded request in a draggable
/// bottom sheet — method, URL, status, time, duration, sender, error, then the
/// request headers, payload and response as copyable JSON.
///
/// Why it exists: the list tile shows a summary; support needs the exact body.
/// Status: used — opened by `RequestLogTile` via [show].
library;

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../diagnostics/view/widgets/diagnostics_section.dart';
import '../../data/request_log_entry_model.dart';
import 'json_block.dart';
import 'status_badge.dart';

class RequestDetailsSheet extends StatelessWidget {
  const RequestDetailsSheet({super.key, required this.entry, required this.scrollController});

  final RequestLogEntryModel entry;
  final ScrollController scrollController;

  static Future<void> show(BuildContext context, RequestLogEntryModel entry) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (_, controller) => RequestDetailsSheet(entry: entry, scrollController: controller),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pings = entry.pingCount;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
      children: [
        Row(
          children: [
            StatusBadge.http(entry.statusCode, noStatusLabel: l10n.reqNoStatus),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${entry.method} ${Uri.parse(entry.url).path}',
                style: theme.textTheme.titleMedium,
                textDirection: TextDirection.ltr,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DiagnosticsSection(title: l10n.reqGeneral, rows: [
          (l10n.reqUrl, entry.url),
          (l10n.reqMethod, entry.method),
          (l10n.reqStatus, entry.statusCode?.toString() ?? l10n.reqNoStatus),
          (l10n.reqTime, entry.startedAt.toLocal().toString().split('.').first),
          (l10n.reqDuration, l10n.reqDurationMs(entry.duration.inMilliseconds)),
          (l10n.reqSource, entry.source == 'service' ? l10n.reqSourceService : l10n.reqSourceUi),
          if (pings != null) (l10n.reqRequestBody, l10n.reqPings(pings)),
          if (entry.error != null) (l10n.diagError, entry.error!),
        ]),
        JsonBlock(title: l10n.reqRequestHeaders, text: entry.requestHeaders),
        JsonBlock(title: l10n.reqRequestBody, text: entry.requestBody),
        JsonBlock(title: l10n.reqResponseBody, text: entry.responseBody),
      ],
    );
  }
}
