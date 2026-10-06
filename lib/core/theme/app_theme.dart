/// `AppTheme.light()` / `AppTheme.dark()`: Material 3 themes seeded from the
/// DynaOps web `theme-color`, with `AppColors` attached as an extension.
///
/// Why it exists: the single source of colour in the app
/// (flutter-use-color-scheme); native screens match the Angular app's look.
/// Status: used — both themes are passed to `MaterialApp.router` in `app.dart`.
library;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The only place colour literals live (flutter-use-color-scheme).
class AppTheme {
  const AppTheme._();

  /// DynaOps web `theme-color` (DynaOps365/src/index.html).
  static const Color _seedColor = Color(0xFF1976D2);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
        extensions: const [AppColors.light],
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark),
        extensions: const [AppColors.dark],
      );
}
