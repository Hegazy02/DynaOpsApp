/// `UrlPolicy`: pure navigation rules (§5.3) — same origin stays in the
/// WebView; `tel:`, `mailto:`, maps and WhatsApp links open externally; other
/// sites open externally at top level but are allowed inside frames; unknown
/// custom schemes are cancelled.
///
/// Why it exists: keeps the bridge single-origin and the rules testable
/// without a WebView.
/// Status: used — by `ShellCubit.shouldLoad`; tested in
/// `test/features/shell/cubit/url_policy_test.dart`.
library;

/// What the shell does with a navigation (§5.3).
enum NavigationDecision { allow, external, cancel }

/// Pure Dart navigation rules, used only by `ShellCubit`.
class UrlPolicy {
  const UrlPolicy(this.webOrigin);

  final String webOrigin;

  static const _externalSchemes = {'tel', 'mailto', 'sms', 'geo', 'google.navigation', 'whatsapp'};
  static const _inPageSchemes = {'about', 'data', 'blob', 'javascript'};

  NavigationDecision decide(Uri uri, {required bool isMainFrame}) {
    final scheme = uri.scheme.toLowerCase();
    if (_inPageSchemes.contains(scheme)) return NavigationDecision.allow;
    if (_externalSchemes.contains(scheme)) return NavigationDecision.external;
    if (scheme != 'http' && scheme != 'https') {
      // Any other custom scheme is cancelled; no scheme carries a session (§7).
      return NavigationDecision.cancel;
    }
    if (_isMapsLink(uri)) return NavigationDecision.external;
    if (uri.origin == webOrigin) return NavigationDecision.allow;
    // Embedded third-party frames (maps tiles, viewers) stay; top-level
    // navigation to another site leaves the app so the bridge stays single-origin.
    return isMainFrame ? NavigationDecision.external : NavigationDecision.allow;
  }

  static bool _isMapsLink(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'maps.app.goo.gl' ||
        host == 'maps.google.com' ||
        ((host == 'www.google.com' || host == 'google.com') && uri.path.startsWith('/maps'));
  }
}
