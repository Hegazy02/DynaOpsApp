---
name: flutter-setup-localization
description: Set up app localization with Flutter's built-in flutter_localizations + intl + gen-l10n pipeline (ARB files → generated AppLocalizations) — no code generation package or manual delegate classes required. Use when adding a new language, adding user-facing text, wiring MaterialApp locale support, or fixing a "No MaterialLocalizations found" error.
---
# Localization with flutter_localizations + ARB

## Contents
- [Core Concepts](#core-concepts)
- [Setup Workflow](#setup-workflow)
- [Writing ARB Files](#writing-arb-files)
- [Placeholders, Plurals, and Dates](#placeholders-plurals-and-dates)
- [Using Translated Strings](#using-translated-strings)
- [Runtime Locale Switching](#runtime-locale-switching)
- [RTL Support](#rtl-support)
- [Common Errors](#common-errors)
- [Checklist](#checklist)
- [Examples](#examples)

## Core Concepts

Flutter ships its own localization pipeline — no third-party codegen package needed, matching this project's policy of avoiding `build_runner`-style tooling ([flutter-package-reference](../flutter-package-reference/SKILL.md)):

- **`flutter_localizations`** (an SDK package, not from pub.dev) supplies the built-in translations for Flutter's own widgets (`MaterialLocalizations`, `CupertinoLocalizations`, `WidgetsLocalizations` — back/cancel buttons, date pickers, etc.).
- **`intl`** provides the runtime formatting (`DateFormat`, `NumberFormat`, plural/gender rules) the generated code relies on.
- **ARB files** (`.arb`, Application Resource Bundle — JSON with an ICU-flavored message syntax) hold your app's own translated strings, one file per locale.
- **`flutter gen-l10n`** (run automatically by `flutter run`/`flutter build` once configured, or manually) reads the ARB files and generates a typed `AppLocalizations` class with one method/getter per key — so a typo'd or missing key is a compile error, not a runtime blank string.

There is no manual "delegate" class to write and no `.g.dart` files to commit — the generated localizations live in `.dart_tool/` and are regenerated on every build.

## Setup Workflow

**Task Progress:**
- [ ] Add the SDK dependency and `intl`:
  ```yaml
  # pubspec.yaml
  dependencies:
    flutter_localizations:
      sdk: flutter
    intl: any # let flutter_localizations pin the exact compatible version — don't hand-pick one
  ```
- [ ] Enable generation in the same `pubspec.yaml`, under the existing `flutter:` section:
  ```yaml
  flutter:
    generate: true
  ```
- [ ] Create `l10n.yaml` at the project root (sibling of `pubspec.yaml`):
  ```yaml
  arb-dir: lib/l10n
  template-arb-file: app_en.arb
  output-localization-file: app_localizations.dart
  synthetic-package: false
  output-dir: lib/l10n/generated
  nullable-getter: false
  ```
  `synthetic-package: false` + `output-dir` puts the generated `AppLocalizations` under `lib/`, so it's a normal importable file instead of the hidden `package:flutter_gen/...` synthetic package — easier for both you and an editor's "go to definition" to find.
- [ ] Create `lib/l10n/app_en.arb` (the **template** — every other locale is diffed against this one's keys) and a matching `app_<locale>.arb` per supported language.
- [ ] `flutter pub get` once — this triggers the first `gen-l10n` run and creates `lib/l10n/generated/app_localizations.dart`.
- [ ] Wire `MaterialApp` (see [Using Translated Strings](#using-translated-strings)).

## Writing ARB Files

One template file, one file per additional locale, same keys in every file:

```jsonc
// lib/l10n/app_en.arb — the template; @@locale + a "@key" metadata block per key
{
  "@@locale": "en",
  "appTitle": "DynaOps",
  "@appTitle": {
    "description": "The application title shown in the OS task switcher"
  },
  "welcomeMessage": "Welcome, {userName}!",
  "@welcomeMessage": {
    "description": "Greeting shown on the home screen",
    "placeholders": {
      "userName": { "type": "String" }
    }
  }
}
```

```json
// lib/l10n/app_ar.arb
{
  "@@locale": "ar",
  "appTitle": "دينا أوبس",
  "welcomeMessage": "أهلاً، {userName}!"
}
```

- Every key in `app_en.arb` needs a `"@key"` metadata block with a `description` — it becomes the doc comment on the generated method, so a translator (or another dev) knows the string's context without guessing.
- A locale file only needs the translated value — the `@key` metadata blocks belong solely in the template.
- A key missing from a non-template ARB file falls back to the template's (English) string at runtime rather than failing the build, but treat that as a bug to fix, not a feature to rely on.

## Placeholders, Plurals, and Dates

Typed placeholders, ICU `plural`/`select`, and locale-aware date/number formatting all live in the ARB entry, not in Dart string interpolation:

```jsonc
{
  "itemCount": "{count, plural, =0{No items} =1{One item} other{{count} items}}",
  "@itemCount": {
    "placeholders": { "count": { "type": "num" } }
  },
  "lastUpdated": "Last updated {date}",
  "@lastUpdated": {
    "placeholders": {
      "date": { "type": "DateTime", "format": "yMMMd" }
    }
  }
}
```

Generated usage: `AppLocalizations.of(context)!.itemCount(cart.length)`, `AppLocalizations.of(context)!.lastUpdated(product.updatedAt)` — the caller passes a real `num`/`DateTime`, and the plural rule / date format for the *active* locale is applied automatically. Never hand-roll `if (count == 1) 'item' else 'items'` in Dart — that logic is locale-specific (some languages have more than two plural forms) and belongs in the ARB message.

## Using Translated Strings

Wire all four delegates and the generated `supportedLocales` into `MaterialApp` (`MaterialApp.router` if using [flutter-setup-declarative-routing](../flutter-setup-declarative-routing/SKILL.md)):

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';

MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  // ...
)
```

`AppLocalizations.localizationsDelegates` already bundles `AppLocalizations.delegate` together with the three `Global*Localizations.delegate`s — prefer it over listing all four by hand so a future generated-file change can't silently drop one.

Read strings through the generated accessor, never a hardcoded literal:

```dart
// BAD — not translatable, invisible to the ARB pipeline
const Text('Welcome!')

// GOOD
Text(AppLocalizations.of(context)!.welcomeMessage(user.name))
```

For a shared widget (see [flutter-build-shared-widgets](../flutter-build-shared-widgets/SKILL.md)) that needs a string but shouldn't hardcode *which* string, accept it as a parameter — the caller (a feature screen) resolves it from `AppLocalizations`, keeping the shared widget free of both feature knowledge and locale lookups:

```dart
AppButton.primary(label: AppLocalizations.of(context)!.save, onPressed: _save)
```

## Runtime Locale Switching

To let the user pick a language instead of always following the OS locale, hold the selection in a small global Cubit (see [flutter-cubit-architecture](../flutter-cubit-architecture/SKILL.md#scoping-providers) — this is one of the few Cubits that belongs at the app root, alongside `ThemeCubit`), persisted via `shared_preferences`:

```dart
class LocaleCubit extends Cubit<Locale?> {
  LocaleCubit(this._prefs) : super(_readSaved(_prefs));
  final SharedPreferences _prefs;

  static Locale? _readSaved(SharedPreferences prefs) {
    final code = prefs.getString('locale');
    return code == null ? null : Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    await _prefs.setString('locale', locale.languageCode);
    emit(locale);
  }
}
```

```dart
MaterialApp(
  locale: context.watch<LocaleCubit>().state, // null => falls back to the OS locale
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
)
```

## RTL Support

Adding an RTL language (Arabic, Hebrew, ...) to `supportedLocales` flips text direction for `Text`, `Row`, `Padding.directional`, etc. automatically via the ambient `Directionality` — but only for widgets that are direction-aware:

- Prefer `EdgeInsetsDirectional`/`AlignmentDirectional` (`start`/`end`) over `EdgeInsets`/`Alignment` (`left`/`right`) in shared widgets, so they mirror correctly.
- `Positioned`, `Transform`, and manually-specified `left:`/`right:` offsets do **not** flip automatically — audit these when adding the first RTL locale.
- Icons that imply direction (a "back" chevron, an arrow) should use `Icons.arrow_back`/`AppBar`'s automatic back button rather than a hardcoded `Icons.arrow_back_ios`, since the framework-provided ones already mirror per-locale.

## Common Errors

- **"No MaterialLocalizations found for locale ..."** — `localizationsDelegates`/`supportedLocales` weren't wired on `MaterialApp`, or a locale was added to one but not the other. Fix by wiring both from `AppLocalizations` as shown above.
- **A new key compiles to a missing getter** — `flutter gen-l10n` hasn't re-run yet. It normally runs automatically before `flutter run`/`build`; if using an IDE's hot reload only, run `flutter gen-l10n` manually or do a hot **restart**, not just a hot reload — new generated code needs a restart (see the hot-reload rule in this project's `CLAUDE.md`).
- **A translator's ARB file has a key the template doesn't** — `gen-l10n` warns and ignores it; keys are only ever added/removed via the template file.

## Checklist

- [ ] `flutter_localizations` (SDK) + `intl` in `pubspec.yaml`, `generate: true` under `flutter:`.
- [ ] `l10n.yaml` present at the project root with `synthetic-package: false`.
- [ ] Every ARB key has a `"@key"` description in the template file only.
- [ ] No hardcoded user-facing string literal in a widget — every string goes through `AppLocalizations.of(context)!`.
- [ ] Plurals/dates use ICU `plural`/`format` in the ARB entry, not Dart-side `if`/manual `DateFormat` calls.
- [ ] `MaterialApp.localizationsDelegates`/`supportedLocales` both come from the generated `AppLocalizations`, not a hand-written list.
- [ ] Shared widgets receive already-resolved strings as parameters; they never call `AppLocalizations.of(context)` for feature-specific copy themselves.

## Examples

### Minimal end-to-end wiring

```yaml
# pubspec.yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: any

flutter:
  generate: true
```

```yaml
# l10n.yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-dir: lib/l10n/generated
synthetic-package: false
```

```dart
// main.dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';

MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const MyHomePage(),
)
```
