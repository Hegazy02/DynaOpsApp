/// `RequestLogTile`: one recorded request in the inspector list — status,
/// method + path, time, duration, ping count and sender; tap opens
/// `RequestDetailsSheet`.
///
/// Why it exists: keeps `RequestInspectorScreen.build` short.
/// Status: used — by `RequestInspectorScreen`'s requests tab.
library;

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../data/request_log_entry_model.dart';
import 'request_details_sheet.dart';
import 'status_badge.dart';

class RequestLogTile extends StatelessWidget {
  const RequestLogTile({super.key, required this.entry});

  final RequestLogEntryModel entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pings = entry.pingCount;
    final time = entry.startedAt.toLocal().toString().split(' ').last.split('.').first;
    final details = [
      time,
      l10n.reqDurationMs(entry.duration.inMilliseconds),
      if (pings != null) l10n.reqPings(pings),
      entry.source == 'service' ? l10n.reqSourceService : l10n.reqSourceUi,
    ].join(' · ');
    return ListTile(
      onTap: () => RequestDetailsSheet.show(context, entry),
      leading: StatusBadge.http(entry.statusCode, noStatusLabel: '—'),
      title: Text(
        '${entry.method} ${Uri.parse(entry.url).path}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: TextDirection.ltr,
        style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(details),
          if (entry.error != null)
            Text(
              entry.error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
