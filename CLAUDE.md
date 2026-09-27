# Project Instructions

## Architecture

This project follows a fixed unidirectional data flow: `API Client -> Repository -> Cubit -> UI`, built on `flutter_bloc` (Cubit), `dio`, `get_it`, and `go_router`. Never let a widget call `dio`/`http` directly, never emit mutable/nullable-field state (use sealed classes), and never register a Cubit as a singleton in `get_it`. Full detail lives in these skills — load the relevant one before writing feature code rather than improvising:

- [flutter-cubit-architecture](.claude/skills/flutter-cubit-architecture/SKILL.md) — layer rules, sealed state, BlocBuilder/Listener/Consumer, scoping, naming, PR checklist.
- [flutter-service-locator-setup](.claude/skills/flutter-service-locator-setup/SKILL.md) — `get_it` registration patterns, async init, test overrides.
- [flutter-dio-repository-setup](.claude/skills/flutter-dio-repository-setup/SKILL.md) — Dio interceptors, auth token handling, typed `Failure` mapping.
- [flutter-package-reference](.claude/skills/flutter-package-reference/SKILL.md) — approved packages and when to reach for each.
- [flutter-build-shared-widgets](.claude/skills/flutter-build-shared-widgets/SKILL.md) — generic, reusable widgets live in `shared/widgets/`, kept small (one visual responsibility each); never a large feature-specific widget in there.
- [flutter-use-color-scheme](.claude/skills/flutter-use-color-scheme/SKILL.md) — all colors come from the app's `ColorScheme`/`AppColors` theme extension; no custom `Color(...)`/`Colors.*` literals outside `lib/core/theme/`.
- [flutter-setup-localization](.claude/skills/flutter-setup-localization/SKILL.md) — user-facing strings go through generated `AppLocalizations` (ARB files under `lib/l10n/`), never a hardcoded string literal in a widget.

## Hot reload on Dart edits

Whenever you edit or modify any `.dart` file under `lib/` in this project:

- **When to skip**: only trigger for edits under `lib/` — not `test/`, `integration_test/`, `benchmark/`, `test_driver/`, or `example/`. Don't trigger for changes that only touch comments, docstrings, or whitespace.
- **Discover & connect**: find the running app instance using the Dart MCP server's `dtd` / `list_running_apps` / `vm_service` tools.
- **Hot reload vs. hot restart**:
  - Use `hot_reload` right after editing UI widgets (including `build` methods of stateful widgets) or simple methods.
  - Use `hot_restart` if you changed fundamental logic, state initialization (e.g. `initState`), global/static state, or `main()`.

(Adapted from [flutter-hot-reload](https://github.com/flutter/agent-plugins/blob/main/rules/flutter-hot-reload.md) in flutter/agent-plugins.)
