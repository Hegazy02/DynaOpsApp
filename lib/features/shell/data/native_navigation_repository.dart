/// `NativeNavigationRepository`: a stream of native screens something outside
/// the widget tree asked to open (`app.openNativeScreen` from Angular).
///
/// Why it exists: bridge handlers may not touch widgets or the router; they
/// publish here, `NativeNavigationCubit` turns it into state, and
/// `ShellScreen`'s `BlocListener` navigates.
/// Status: used — written by `AppHandler`, read by `NativeNavigationCubit`.
library;

import 'dart:async';

enum NativeScreen {
  permissions('permissions', '/permissions'),
  diagnostics('diagnostics', '/diagnostics');

  const NativeScreen(this.wire, this.route);
  final String wire;
  final String route;

  static NativeScreen? fromWire(String value) {
    for (final screen in values) {
      if (screen.wire == value) return screen;
    }
    return null;
  }
}

class NativeNavigationRepository {
  final _requests = StreamController<NativeScreen>.broadcast();

  Stream<NativeScreen> get requests => _requests.stream;

  void open(NativeScreen screen) => _requests.add(screen);

  Future<void> dispose() => _requests.close();
}
