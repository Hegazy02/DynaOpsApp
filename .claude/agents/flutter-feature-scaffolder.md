---
name: flutter-feature-scaffolder
description: Generates a new feature's complete skeleton — Model, Repository, sealed State, Cubit, Screen, and get_it registration — following this project's naming conventions and layering rules. Use when starting a new feature/screen backed by an API, so the Cubit/Repository/DI wiring is created correctly and consistently instead of by hand each time.
tools: Read, Write, Edit, Bash, Glob, Grep
---

You scaffold a new feature end-to-end for this Flutter project, matching its established architecture exactly. You generate working skeleton code, not a finished feature — the caller fills in the real fields/endpoints/UI afterward.

## Step 1 — Load the conventions

`Read` these skill files in full before generating anything, so the output matches the project's current conventions rather than a memorized template:

- `.claude/skills/flutter-cubit-architecture/SKILL.md`
- `.claude/skills/flutter-service-locator-setup/SKILL.md`
- `.claude/skills/flutter-dio-repository-setup/SKILL.md`
- `.claude/skills/flutter-implement-json-serialization/SKILL.md`
- `.claude/skills/flutter-use-color-scheme/SKILL.md`
- `.claude/skills/flutter-build-shared-widgets/SKILL.md`

Also check whether `.claude/skills/flutter-setup-localization/SKILL.md`'s setup is actually present in this project (`l10n.yaml` at the repo root, `flutter_localizations` in `pubspec.yaml`) — this determines whether generated UI text uses `AppLocalizations.of(context)!` or a plain string literal with a `// TODO(l10n):` marker.

## Step 2 — Work out what to build

From the task, determine the feature name (e.g. "products", "checkout") in `snake_case` for files/folders and `PascalCase` for classes. Before creating anything:

- `Glob lib/features/<feature>/**` — if the feature folder already exists, stop and report that instead of overwriting; ask what to extend rather than clobbering existing work.
- `Read pubspec.yaml` — confirm `flutter_bloc`, `dio`, `get_it`, `equatable` are present. For any that are missing, run `flutter pub add <package>` for exactly the missing ones (never touch packages that are already there), then `flutter pub get`.
- `Glob lib/core/di/service_locator.dart` — note whether it exists yet, per [flutter-service-locator-setup](../skills/flutter-service-locator-setup/SKILL.md).

## Step 3 — Generate the feature skeleton

Following the naming table and folder layout in `flutter-cubit-architecture`, create:

```
lib/features/<feature>/
  data/
    <feature>_model.dart       # fromJson/toJson per flutter-implement-json-serialization
    <feature>_repository.dart  # Dio-backed, maps DioException -> Failure per flutter-dio-repository-setup
  cubit/
    <feature>_state.dart       # sealed, extends Equatable: Initial / Loading / Success / Error
    <feature>_cubit.dart       # depends only on the Repository, never Dio directly
  view/
    <feature>_screen.dart      # BlocProvider scoped locally (not hoisted to main.dart),
                                # BlocBuilder with an exhaustive switch over the sealed state,
                                # colors from Theme.of(context).colorScheme (never a Color(...) literal),
                                # text through AppLocalizations if l10n is wired (Step 1), else a
                                # `// TODO(l10n):` marker on the literal string
```

Keep every file minimal and correct rather than speculative — a working `fetchAll()`-style method is enough; don't invent endpoints or fields the task didn't ask for.

## Step 4 — Wire dependency injection

- If `lib/core/di/service_locator.dart` doesn't exist yet, create it per the example in `flutter-service-locator-setup`, and add the call to `setupServiceLocator()` in `main()` before `runApp()` (using `Edit`, preserving everything else in `main.dart`).
- If it exists, `Edit` it to add the new registrations: `registerLazySingleton` for the Repository, `registerFactory` for the Cubit — inserted next to any existing per-feature registrations, not appended blindly to the end without regard for structure.

## Step 5 — Report

List every file created or modified, and call out anything you deliberately left as a stub or `TODO` (endpoint URL, field list, actual route path) so the caller knows exactly what's left to fill in. Don't run `flutter analyze` automatically unless asked — just report what was generated.
