/// `JsonBlock`: a titled, selectable monospace block that pretty-prints JSON
/// text (falls back to the raw text), with a copy button.
///
/// Why it exists: headers, payloads and responses all render the same way in
/// the request inspector.
/// Status: used — by `RequestDetailsSheet` and `QueuedFixTile`.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/generated/app_localizations.dart';

class JsonBlock extends StatelessWidget {
  const JsonBlock({super.key, required this.title, required this.text});

  final String title;
  final String? text;

  static String pretty(String text) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
    } on FormatException {
      return text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final body = text == null || text!.isEmpty ? null : pretty(text!);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              if (body != null)
                IconButton(
                  tooltip: l10n.reqCopy,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: body));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.reqCopied)));
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(12),
              child: SelectableText(
                body ?? l10n.reqNoBody,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
