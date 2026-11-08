/// `MultiTapDetector`: calls [onTriggered] after [taps] quick taps in a row
/// anywhere on [child], without taking the taps away from it.
///
/// Why it exists: hidden entry points (e.g. the request inspector) that must
/// work over a WebView, where a normal GestureDetector would steal the taps.
/// Status: used — by `ShellScreen` to open `/requests` on 7 taps.
library;

import 'package:flutter/widgets.dart';

class MultiTapDetector extends StatefulWidget {
  const MultiTapDetector({
    super.key,
    required this.child,
    required this.onTriggered,
    this.taps = 7,
    this.maxGap = const Duration(milliseconds: 500),
  });

  final Widget child;
  final VoidCallback onTriggered;

  /// Taps needed in a row.
  final int taps;

  /// Longest pause between two taps before the count starts over.
  final Duration maxGap;

  @override
  State<MultiTapDetector> createState() => _MultiTapDetectorState();
}

class _MultiTapDetectorState extends State<MultiTapDetector> {
  int _count = 0;
  Duration? _lastTap;

  void _onPointerDown(PointerDownEvent event) {
    final last = _lastTap;
    _lastTap = event.timeStamp;
    _count = last != null && event.timeStamp - last <= widget.maxGap ? _count + 1 : 1;
    if (_count >= widget.taps) {
      _count = 0;
      _lastTap = null;
      widget.onTriggered();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listener only observes pointers; the child (the WebView) still gets every tap.
    return Listener(behavior: HitTestBehavior.translucent, onPointerDown: _onPointerDown, child: widget.child);
  }
}
