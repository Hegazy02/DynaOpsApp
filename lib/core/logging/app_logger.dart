/// `AppLogger`: structured logger that keeps the last 500 lines in a ring
/// buffer and echoes to the console in debug builds. Never log a token.
///
/// Why it exists: repositories, engines and the bridge need one logger they
/// can inject and mock, and the diagnostics screen (§15) shows and exports the
/// buffer. In the tracking service `onLine` forwards each line to the UI
/// isolate, which records it with `external()`, so one buffer covers both.
/// Status: used — registered in both locators; read by the diagnostics screen.
library;

import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Structured logger with an in-memory ring buffer (exported from diagnostics, §15).
/// Never pass a token to it.
class AppLogger {
  AppLogger({this.capacity = 500, this.onLine});

  final int capacity;

  /// Called with every formatted line (the service forwards them to the UI).
  final void Function(String line)? onLine;
  final _buffer = ListQueue<String>();

  List<String> get entries => List.unmodifiable(_buffer);

  void info(String message) => _add('I', message);

  void warn(String message) => _add('W', message);

  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _add('E', error == null ? message : '$message: $error');

  /// Records a line that was already formatted elsewhere (the service isolate).
  void external(String line) => _push('[service] $line');

  void _add(String level, String message) {
    final line = '${DateTime.now().toUtc().toIso8601String()} $level $message';
    _push(line);
    onLine?.call(line);
  }

  void _push(String line) {
    if (_buffer.length >= capacity) _buffer.removeFirst();
    _buffer.addLast(line);
    if (kDebugMode) debugPrint(line);
  }
}
