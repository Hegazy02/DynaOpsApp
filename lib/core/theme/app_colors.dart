/// `AppColors`: a `ThemeExtension` for the few semantic colours
/// `ColorScheme` has no role for (`success`, `warning`), in light and dark.
///
/// Why it exists: flutter-use-color-scheme — widgets read colours from the
/// theme, never from `Color(...)` literals; this is one of the two files
/// allowed to contain them.
/// Status: registered on both themes by `app_theme.dart`, but no widget reads
/// it yet. The M2 tracking status and permission walkthrough screens will.
library;

import 'package:flutter/material.dart';

/// Semantic colours the `ColorScheme` has no role for (tracking status, permission steps).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({required this.success, required this.warning});

  final Color success;
  final Color warning;

  static const light = AppColors(success: Color(0xFF2E7D32), warning: Color(0xFFED6C02));
  static const dark = AppColors(success: Color(0xFF66BB6A), warning: Color(0xFFFFB74D));

  @override
  AppColors copyWith({Color? success, Color? warning}) =>
      AppColors(success: success ?? this.success, warning: warning ?? this.warning);

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}
