---
name: flutter-use-color-scheme
description: Centralize all color values in a single Material 3 ColorScheme (plus a small ThemeExtension for the rare semantic color it doesn't cover) so widgets never write custom Color(...)/Colors.* literals. Use when defining the app theme, styling any widget, adding a color, or reviewing a PR for hardcoded colors.
---
# Using the Color Scheme Instead of Custom Colors

## Contents
- [Core Rule](#core-rule)
- [One Seed, Light + Dark](#one-seed-light--dark)
- [ColorScheme Roles — What to Use Where](#colorscheme-roles--what-to-use-where)
- [When a Role Truly Doesn't Exist: ThemeExtension](#when-a-role-truly-doesnt-exist-themeextension)
- [Opacity and Elevation Without New Colors](#opacity-and-elevation-without-new-colors)
- [Catching Hardcoded Colors](#catching-hardcoded-colors)
- [Checklist](#checklist)
- [Examples](#examples)

## Core Rule

**A raw `Color(0xFF...)` or `Colors.blue`-style literal may only appear inside the one theme-definition file** (`lib/core/theme/app_theme.dart` below). Everywhere else — features, shared widgets, screens — colors come from `Theme.of(context).colorScheme` (or the app's `ThemeExtension`, for the rare case the 26 `ColorScheme` roles don't cover). This is what makes dark mode, rebrands, and accessibility contrast fixes a one-file change instead of a grep-and-replace across the whole app.

```dart
// BAD — scattered literal, breaks dark mode, invisible to future rebrands
Container(color: const Color(0xFF3366FF))
Text('Error', style: TextStyle(color: Colors.red))
Icon(Icons.check, color: Colors.green)

// GOOD — theme-driven, adapts automatically
Container(color: Theme.of(context).colorScheme.primary)
Text('Error', style: TextStyle(color: Theme.of(context).colorScheme.error))
Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
```

Most `Icon`/`Text` widgets don't need a `color`/`style` override at all — leave it unset and let `IconTheme`/`DefaultTextStyle` (both derived from the ambient `Theme`) supply it.

## One Seed, Light + Dark

This project (see the stock `ColorScheme.fromSeed(seedColor: ...)` already in `lib/main.dart`) generates both themes from a single seed color rather than hand-picking dozens of colors. Move that into its own file so `main.dart` stays about bootstrapping, not styling:

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color _seedColor = Colors.deepPurple;

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
      );
}
```

```dart
// lib/main.dart
MaterialApp(
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  themeMode: ThemeMode.system,
  home: const MyHomePage(title: 'Flutter Demo'),
)
```

If the brand later needs an exact, non-generated palette instead of one seed, replace `ColorScheme.fromSeed(...)` with an explicit `ColorScheme(...)` / `ColorScheme.light(...)`/`.dark(...)` call in this same file — call sites elsewhere never change, because they only ever ask for a *role* (`colorScheme.primary`), never a specific hex value.

## ColorScheme Roles — What to Use Where

| Role | Use for |
|---|---|
| `primary` / `onPrimary` | Main CTAs, filled buttons, active/selected state, the color *on top of* `primary` |
| `primaryContainer` / `onPrimaryContainer` | A softer/tonal surface built around the primary color (e.g. a selected chip's fill) |
| `secondary` / `onSecondary` | Less prominent accents — secondary actions, unselected-but-highlighted controls |
| `tertiary` / `onTertiary` | A contrasting accent when primary/secondary both apply elsewhere on screen |
| `error` / `onError` | Destructive actions, validation/error states — not for warnings (see below) |
| `surface` / `onSurface` | Card, sheet, and scaffold backgrounds, and the text/icons drawn on them |
| `surfaceContainerHighest` (and other `surfaceContainer*` tones) | Layered surfaces (a card sitting on the scaffold background) without inventing a new gray |
| `outline` / `outlineVariant` | Borders, dividers |
| `inversePrimary` / `inverseSurface` | Content shown against an inverted background (e.g. a `SnackBar`, as already used for this app's `AppBar` in `lib/main.dart`) |

Material's `ColorScheme` has **no built-in "warning" or "success" role** — that's the one legitimate gap, covered next.

## When a Role Truly Doesn't Exist: ThemeExtension

For a semantic color the `ColorScheme` genuinely doesn't model (success green, warning amber), don't reach for a literal — define it once as a `ThemeExtension`, with a light and dark variant, so it's still centralized and theme-aware:

```dart
// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

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
```

Register it once alongside the `ColorScheme` in `AppTheme.light()`/`AppTheme.dark()` (`extensions: [AppColors.light]` / `[AppColors.dark]`), then read it the same way everywhere else:

```dart
final colors = Theme.of(context).extension<AppColors>()!;
Icon(Icons.check_circle, color: colors.success)
```

This is still the *only* other place a raw `Color(0xFF...)` literal is allowed — inside `AppColors.light`/`AppColors.dark`.

## Opacity and Elevation Without New Colors

- **Don't invent a lighter/darker one-off color for a hover/disabled/scrim state.** Derive it from an existing role: `Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)`. Prefer `.withValues(alpha:)` over the deprecated `.withOpacity(...)`.
- **Don't fake elevation with a hardcoded darker gray.** Use the `surfaceContainer*` tonal roles (`surfaceContainerLow` → `surfaceContainerHighest`), which are already tuned to represent elevation correctly in both light and dark mode.

## Catching Hardcoded Colors

There's no bundled `flutter_lints` rule that flags a raw `Color(...)`/`Colors.*` literal, so treat this as a review-time grep, not something the analyzer enforces automatically:

```bash
grep -rn "Color(0x\|Colors\." lib --include=*.dart | grep -v "lib/core/theme/"
```

Any hit outside `lib/core/theme/` is a candidate to replace with a `colorScheme`/`AppColors` lookup (a `const Colors.transparent` or a `Colors.black.withValues(alpha: ...)` used purely as a shadow color are the common, acceptable exceptions — use judgment).

## Checklist

- [ ] Every `theme`/`darkTheme` is built from `ColorScheme.fromSeed` (or a fully custom `ColorScheme`) in one file — `lib/core/theme/app_theme.dart`.
- [ ] No `Color(0xFF...)`/`Colors.*` literal appears outside `lib/core/theme/`.
- [ ] A semantic color the `ColorScheme` doesn't model is added to `AppColors` (a `ThemeExtension`), not inlined at the call site.
- [ ] `Icon`/`Text` widgets omit `color`/`style` unless intentionally overriding the ambient theme.
- [ ] Hover/disabled/scrim shades are derived with `.withValues(alpha:)` from an existing role, not a new literal color.
- [ ] `MaterialApp` wires both `theme:` and `darkTheme:` (see [flutter-build-shared-widgets](../flutter-build-shared-widgets/SKILL.md#theming-not-hardcoding) for the same rule applied inside shared widgets).

## Examples

### Before/after on a shared widget

```dart
// BAD
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: Color(0xFFED6C02))),
    );
  }
}

// GOOD
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final warning = Theme.of(context).extension<AppColors>()!.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: warning)),
    );
  }
}
```
