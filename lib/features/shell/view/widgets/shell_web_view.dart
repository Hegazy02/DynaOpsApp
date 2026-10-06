/// `ShellWebView`: the `InAppWebView` itself — settings (JS, DOM storage, no
/// file access, mixed content blocked, geolocation, user-agent suffix), the
/// bridge user script injected at document start on the web origin only, the
/// `dynaops` JS handler, and every plugin callback forwarded to `ShellCubit`.
///
/// Why it exists: the only widget that knows `flutter_inappwebview`; it holds
/// no logic, so policy changes happen in the Cubit.
/// Status: used — placed by `ShellScreen`, keyed on `webViewGeneration`.
library;

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../bridge/bridge_script.dart';
import '../../cubit/shell_cubit.dart';
import '../in_app_web_view_port.dart';

/// The WebView itself; every callback is forwarded to [ShellCubit] (§5).
class ShellWebView extends StatelessWidget {
  const ShellWebView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShellCubit>();
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri.uri(cubit.initialUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
        allowFileAccess: false,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
        useShouldOverrideUrlLoading: true,
        useOnDownloadStart: true,
        geolocationEnabled: true,
        supportMultipleWindows: true,
        javaScriptCanOpenWindowsAutomatically: true,
        applicationNameForUserAgent: cubit.userAgentSuffix,
        isInspectable: kDebugMode,
      ),
      initialUserScripts: UnmodifiableListView([
        UserScript(
          source: cubit.bridgeScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          allowedOriginRules: {cubit.webOrigin},
        ),
      ]),
      onWebViewCreated: (controller) {
        cubit.attachWebView(InAppWebViewPort(controller));
        controller.addJavaScriptHandler(
          handlerName: bridgeHandlerName,
          callback: (args) async {
            final raw = args.isEmpty ? null : args.first;
            if (raw is! String) return null;
            return cubit.onBridgeMessage(raw, await controller.getUrl());
          },
        );
      },
      onLoadStart: (_, _) => cubit.onPageStarted(),
      onProgressChanged: (_, progress) => cubit.onProgress(progress),
      onLoadStop: (_, _) => cubit.onPageFinished(),
      onReceivedError: (_, request, error) {
        if (request.isForMainFrame ?? true) cubit.onMainFrameError(error.description);
      },
      shouldOverrideUrlLoading: (_, action) async {
        final url = action.request.url;
        if (url == null) return NavigationActionPolicy.ALLOW;
        return await cubit.shouldLoad(url, isMainFrame: action.isForMainFrame)
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL;
      },
      onCreateWindow: (_, action) async {
        final url = action.request.url;
        if (url != null) await cubit.onNewWindow(url);
        return false;
      },
      onDownloadStarting: (_, request) async {
        await cubit.onDownload(request.url);
        return DownloadStartResponse(handled: true, action: DownloadStartResponseAction.CANCEL);
      },
      onGeolocationPermissionsShowPrompt: (_, origin) async => GeolocationPermissionShowPromptResponse(
        origin: origin,
        allow: await cubit.onGeolocationPrompt(origin),
        retain: false,
      ),
      onRenderProcessGone: (_, _) => cubit.onRenderProcessGone(),
      onConsoleMessage: kDebugMode ? (_, message) => debugPrint('[web] ${message.message}') : null,
    );
  }
}
