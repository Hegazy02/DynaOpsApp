/// `WebViewPort`: the small interface `ShellCubit` uses to drive the WebView
/// (evaluate JS, reload, load, back navigation).
///
/// Why it exists: the Cubit must not import `flutter_inappwebview`; the view
/// implements this and tests substitute a mock.
/// Status: used — implemented by `InAppWebViewPort`, mocked in the Cubit
/// tests.
library;

/// What `ShellCubit` may ask of the WebView. Implemented by the view around the
/// plugin's controller, so the Cubit never imports the WebView plugin.
abstract interface class WebViewPort {
  Future<void> evaluate(String script);

  Future<void> reload();

  Future<void> load(Uri uri);

  Future<bool> canGoBack();

  Future<void> goBack();
}
