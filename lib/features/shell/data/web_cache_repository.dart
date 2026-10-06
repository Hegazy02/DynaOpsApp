/// `WebCacheRepository`: clears the WebView's HTTP cache (not cookies or
/// `localStorage`, so the Angular session survives).
///
/// Why it exists: §5.2 — the cache is cleared only on purpose, from the
/// diagnostics screen, never on logout.
/// Status: used — by `DiagnosticsCubit`.
library;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/network/failure.dart';

class WebCacheRepository {
  Future<void> clear() async {
    try {
      await InAppWebViewController.clearAllCache();
    } catch (e) {
      throw PlatformFailure('Could not clear the web cache: $e');
    }
  }
}
