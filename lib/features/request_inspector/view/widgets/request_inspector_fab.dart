/// `RequestInspectorFab`: a small floating button the user can drag anywhere
/// over the WebView; tap opens `/requests`. Place it as a child of a `Stack`.
///
/// Why it exists: the inspector must be reachable from the Angular app without
/// covering the same spot of the web UI all the time.
/// Status: used — by `ShellScreen` when `AppConfig.requestInspector` is on.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/generated/app_localizations.dart';

class RequestInspectorFab extends StatefulWidget {
  const RequestInspectorFab({super.key});

  static const route = '/requests';

  @override
  State<RequestInspectorFab> createState() => _RequestInspectorFabState();
}

class _RequestInspectorFabState extends State<RequestInspectorFab> {
  static const _size = 48.0;
  static const _margin = 12.0;

  /// Top-left offset; null until first layout puts it at the bottom end.
  Offset? _offset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxX = constraints.maxWidth - _size - _margin;
        final maxY = constraints.maxHeight - _size - _margin;
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        final offset = _offset ?? Offset(isRtl ? _margin : maxX, maxY - 72);
        final clamped = Offset(offset.dx.clamp(_margin, maxX), offset.dy.clamp(_margin, maxY));
        return Stack(
          children: [
            Positioned(
              left: clamped.dx,
              top: clamped.dy,
              child: GestureDetector(
                onPanUpdate: (details) => setState(() => _offset = clamped + details.delta),
                child: SizedBox.square(
                  dimension: _size,
                  child: FloatingActionButton.small(
                    heroTag: 'requestInspectorFab',
                    tooltip: AppLocalizations.of(context).reqInspectorOpen,
                    onPressed: () => context.push(RequestInspectorFab.route),
                    child: const Icon(Icons.network_check),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
