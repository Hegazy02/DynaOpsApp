---
name: flutter-build-shared-widgets
description: Create small, generic, reusable widgets for the shared component library — parameterized via constructor slots, theme-driven, with no Cubit/feature knowledge. Use when building a button/card/input/loader used across multiple features, or when a widget's build() method is growing too large and needs splitting. Keep shared widgets small-to-mid sized; never build large, feature-specific mega-widgets here.
---
# Building Shared, Reusable Widgets

## Contents
- [What Belongs in `shared/widgets`](#what-belongs-in-sharedwidgets)
- [Size Discipline — Keep It Small](#size-discipline--keep-it-small)
- [Designing a Generic API](#designing-a-generic-api)
- [Theming, Not Hardcoding](#theming-not-hardcoding)
- [Folder Layout & Naming](#folder-layout--naming)
- [Previewing Shared Widgets](#previewing-shared-widgets)
- [Checklist](#checklist)
- [Examples](#examples)

## What Belongs in `shared/widgets`

A widget belongs in the shared library only if it is **feature-agnostic**: it renders based on the data and callbacks it's given, and knows nothing about `AppCubit`s, `Repository`s, routes, or any single feature's domain model.

- Used (or clearly about to be used) by **2+ features**. A one-off widget stays local to its feature's `view/widgets/` folder (see [flutter-cubit-architecture](../flutter-cubit-architecture/SKILL.md#naming-conventions)) until a second feature actually needs it — don't abstract preemptively.
- Takes plain data in (`String`, `int`, enums, other widgets) and hands events out (`VoidCallback`, `ValueChanged<T>`) — never a `BuildContext`-coupled Cubit lookup (`context.read<ProductCubit>()`) inside a shared widget.
- Has no knowledge of a specific screen's layout; it's a building block other screens compose, not a screen itself.

Right size for this folder: `AppButton`, `AppTextField`, `AppCard`, `SectionHeader`, `EmptyStateView`, `LoadingOverlay`, `AppAvatar`, `ConfirmDialog`. Wrong size for this folder: `ProductDetailsSheet`, `CheckoutSummaryScreen`, or anything with "Screen"/"Page" in the name, or a feature name baked into what it renders.

## Size Discipline — Keep It Small

Shared widgets are building blocks, not screens. Keep each one to a single visual responsibility.

- **Split before ~60–80 lines in `build()`.** If a `build()` method needs scrolling to read, extract a private child widget (`class _Header extends StatelessWidget`) rather than a `_buildX(BuildContext context)` helper method — a widget is independently `const`-able and previewable, a helper method is not.
- **One concept per file.** `AppButton` doesn't also define `AppIconButton` and `AppToggleButton` in the same file — split into sibling files even if they share a base class.
- **Composition over a flag explosion.** If a widget's constructor is accumulating `showLeading`, `showTrailing`, `showDivider`, `isCompact`, `isExpanded`... that's a sign it should be decomposed into smaller pieces the *caller* composes (a `Row` of an `AppAvatar` + `AppCard` + `AppBadge`), not configured through an ever-growing parameter list.
- **No business-logic branching.** `if (state is ProductError)` has no place in a shared widget — that decision belongs in the feature's `BlocBuilder`/`switch` (see [flutter-cubit-architecture](../flutter-cubit-architecture/SKILL.md#blocbuilder-vs-bloclistener-vs-blocconsumer)), which then picks *which* small shared widget to render (e.g. `EmptyStateView` vs the real content).
- **Nesting depth.** If a shared widget's tree nests more than ~4 levels deep, extract an inner level into its own small widget instead of inlining it further.

## Designing a Generic API

- **Slots over configuration.** Accept a `child` / `leading` / `trailing` / `Widget Function(BuildContext)` builder instead of hardcoding what goes inside. This is what makes one `AppCard` reusable for a product tile, a settings row, and a notification — not three near-duplicate widgets.
- **Named constructors for common variants**, funneled into one private constructor so styling logic lives in exactly one place: `AppButton.primary(...)`, `AppButton.secondary(...)`, `AppButton.destructive(...)`.
- **Sensible defaults, minimal required parameters.** A caller should be able to write `AppButton.primary(label: 'Save', onPressed: _save)` and get something reasonable; every other parameter is optional with a default pulled from the theme.
- **Use `super.key`**, not a manually threaded `Key? key` + `super(key: key)`.
- **`const` constructors wherever the widget holds no mutable runtime state** — this lets callers write `const AppButton(...)` and skip rebuilds entirely when nothing changed.

## Theming, Not Hardcoding

A shared widget reads colors, spacing, and text styles from `Theme.of(context)` (or an app-level `ThemeExtension`), never a literal `Color(0xFF...)` or a magic `16.0`. This is what makes the same `AppButton` look right in light/dark mode and honor a future rebrand without touching every call site. For the full color-role reference and the `ThemeExtension` pattern for semantic colors, see [flutter-use-color-scheme](../flutter-use-color-scheme/SKILL.md).

```dart
// BAD — hardcoded, ignores theme/dark mode
Container(
  color: const Color(0xFF3366FF),
  child: Text(label, style: const TextStyle(color: Colors.white)),
)

// GOOD — theme-driven
Container(
  color: Theme.of(context).colorScheme.primary,
  child: Text(label, style: Theme.of(context).textTheme.labelLarge),
)
```

For widgets whose layout also needs to adapt across phone/tablet/desktop width, apply [flutter-build-responsive-layout](../flutter-build-responsive-layout/SKILL.md) inside the shared widget itself (e.g. an `AppCard` that switches to wider padding past a breakpoint) so every feature gets that adaptivity for free.

## Folder Layout & Naming

```
lib/shared/widgets/
  buttons/
    app_button.dart        -> AppButton
  inputs/
    app_text_field.dart    -> AppTextField
  cards/
    app_card.dart           -> AppCard
  feedback/
    loading_overlay.dart    -> LoadingOverlay
    empty_state_view.dart   -> EmptyStateView
    error_view.dart         -> ErrorView
  layout/
    section_header.dart     -> SectionHeader
```

- File and class names carry no feature prefix (`AppButton`, not `ProductAppButton`) — that's the signal it's shared, versus the feature-scoped naming in [flutter-cubit-architecture](../flutter-cubit-architecture/SKILL.md#naming-conventions) (`product_card.dart` / `ProductCard`, which stays under `features/product/view/widgets/`).
- Group by widget *kind* (`buttons/`, `inputs/`, `cards/`, `feedback/`, `layout/`), not by the feature that first needed one.
- A widget that starts feature-scoped and turns out to be needed elsewhere **moves** into `shared/widgets/` at that point — don't duplicate it.

## Previewing Shared Widgets

Every shared widget is a natural candidate for an isolated `@Preview` — it has no Cubit/route dependency to fake, so it previews cleanly on its own. Add one alongside each new shared widget rather than only seeing it render by wiring it into a real screen — see [flutter-add-widget-preview](../flutter-add-widget-preview/SKILL.md).

```dart
import 'package:flutter/widget_previews.dart';

@Preview(name: 'AppButton - primary')
Widget appButtonPreview() => AppButton.primary(label: 'Continue', onPressed: () {});
```

## Checklist

- [ ] Used by 2+ features, or clearly about to be — not speculative abstraction.
- [ ] No `context.read<...Cubit>()`, no `Repository`, no feature-specific model type in the constructor.
- [ ] `build()` stays small (~60–80 lines); anything larger is extracted into a private child widget.
- [ ] Configured through slots (`child`/`leading`/builder) and named-constructor variants, not a growing pile of booleans.
- [ ] Colors/spacing/text styles come from `Theme.of(context)`, not literals.
- [ ] Has a `const` constructor if it holds no mutable state.
- [ ] Lives under `shared/widgets/<kind>/`, named without a feature prefix.
- [ ] Has an `@Preview` for at least its default/most common variant.

## Examples

### Slot-based, theme-driven `AppCard`

```dart
// shared/widgets/cards/app_card.dart
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}
```

Used by unrelated features without either one knowing about the other:

```dart
AppCard(onTap: () => context.go('/products/${product.id}'), child: ProductSummary(product));
AppCard(child: NotificationRow(notification));
```

### Named-constructor variants funneling into one implementation

```dart
// shared/widgets/buttons/app_button.dart
enum _ButtonStyle { primary, secondary }

class AppButton extends StatelessWidget {
  const AppButton._({super.key, required this.label, required this.onPressed, required this.style});

  factory AppButton.primary({Key? key, required String label, required VoidCallback? onPressed}) =>
      AppButton._(key: key, label: label, onPressed: onPressed, style: _ButtonStyle.primary);

  factory AppButton.secondary({Key? key, required String label, required VoidCallback? onPressed}) =>
      AppButton._(key: key, label: label, onPressed: onPressed, style: _ButtonStyle.secondary);

  final String label;
  final VoidCallback? onPressed;
  final _ButtonStyle style;

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      _ButtonStyle.primary => FilledButton(onPressed: onPressed, child: Text(label)),
      _ButtonStyle.secondary => OutlinedButton(onPressed: onPressed, child: Text(label)),
    };
  }
}
```
