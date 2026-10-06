/// `InAppWebViewPort`: `WebViewPort` implemented over the
/// `flutter_inappwebview` controller.
///
/// Why it exists: the only adapter between the Cubit's abstract port and the
/// plugin; swap the WebView package and only this file and
/// `shell_web_view.dart` change.
/// Status: used — created in `ShellWebView.onWebViewCreated`.
library;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../cubit/web_view_port.dart';

/// [WebViewPort] over the `flutter_inappwebview` controller.
class InAppWebViewPort implements WebViewPort {
  InAppWebViewPort(this._controller);
  final InAppWebViewController _controller;

  @override
  Future<void> evaluate(String script) async {
    await _controller.evaluateJavascript(source: script);
  }

  @override
  Future<void> reload() => _controller.reload();

  @override
  Future<void> load(Uri uri) => _controller.loadUrl(urlRequest: URLRequest(url: WebUri.uri(uri)));

  @override
  Future<bool> canGoBack() => _controller.canGoBack();

  @override
  Future<void> goBack() => _controller.goBack();
}
